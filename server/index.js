// Backend API H2O Laundry Parakan.
// Penyimpanan: satu file JSON (data.json) dengan tulis atomik —
// sederhana, tanpa database terpisah, cukup untuk satu gerai laundry.
//
// Jalankan:  PORT=8080 node index.js
// Data:      DATA_FILE=/path/data.json (default: ./data.json)

const express = require('express');
const fs = require('fs');
const https = require('https');
const path = require('path');

const PORT = process.env.PORT || 8080;
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data.json');

const STATUS = ['menunggu', 'diterima', 'diproses', 'siap', 'selesai'];

const defaultServices = [
  { id: 'cuci_setrika', name: 'Cuci + Setrika', unit: 'kg', price: 7000, description: 'Cuci bersih, wangi, dan disetrika rapi', estimasiHari: 2 },
  { id: 'cuci_kering', name: 'Cuci Kering', unit: 'kg', price: 5000, description: 'Cuci dan keringkan, lipat tanpa setrika', estimasiHari: 2 },
  { id: 'setrika', name: 'Setrika Saja', unit: 'kg', price: 4000, description: 'Pakaian bersih Anda disetrika rapi', estimasiHari: 1 },
  { id: 'express', name: 'Express 1 Hari', unit: 'kg', price: 12000, description: 'Cuci + setrika kilat, selesai 24 jam', estimasiHari: 1 },
];

let db = { seq: 1, services: defaultServices, orders: [], admins: [] };
if (fs.existsSync(DATA_FILE)) {
  try {
    db = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  } catch (e) {
    console.error('data.json tidak bisa dibaca — mulai dari kosong:', e.message);
  }
}

let saveTimer = null;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const tmp = DATA_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(db, null, 1));
    fs.renameSync(tmp, DATA_FILE);
  }, 100);
}

const digits = (p) => String(p || '').replace(/[^0-9]/g, '');
const now = () => new Date().toISOString();

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  res.set({
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,x-admin-id,x-admin-pin',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  });
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// Selama belum ada admin terdaftar, akses admin terbuka (bootstrap) —
// sama seperti perilaku aplikasi. Setelah ada admin, wajib header
// x-admin-id + x-admin-pin yang cocok.
function admin(req) {
  if (db.admins.length === 0) return { id: null, name: null, bootstrap: true };
  const a = db.admins.find(
    (a) => a.id === req.get('x-admin-id') && a.pin === req.get('x-admin-pin'));
  return a || null;
}
function requireAdmin(req, res) {
  const a = admin(req);
  if (!a) res.status(401).json({ error: 'Autentikasi admin tidak valid' });
  return a;
}
function findOrder(req, res) {
  const o = db.orders.find((o) => o.id === req.params.id);
  if (!o) res.status(404).json({ error: 'Pesanan tidak ditemukan' });
  return o;
}

app.get('/api/health', (req, res) =>
  res.json({ ok: true, name: 'H2O Laundry Parakan', time: now() }));

// Status aplikasi: katalog + nama admin (untuk dialog login) + pesanan.
// Admin melihat semua pesanan; pelanggan hanya pesanannya (per no. HP).
app.get('/api/state', (req, res) => {
  const a = admin(req);
  let orders = [];
  if (a) {
    orders = db.orders;
  } else {
    const p = digits(req.query.phone);
    if (p) orders = db.orders.filter((o) => digits(o.phone) === p);
  }
  res.json({
    services: db.services,
    adminNames: db.admins.map(({ id, name }) => ({ id, name })),
    orders,
    isAdmin: !!a,
  });
});

// ---- Pesanan ----

app.post('/api/orders', (req, res) => {
  const b = req.body || {};
  if (!b.customerName || !b.phone ||
      !Array.isArray(b.items) || b.items.length === 0) {
    return res.status(400).json({ error: 'Data pesanan tidak lengkap' });
  }
  const t = now();
  const order = {
    id: `H2O-${String(db.seq++).padStart(4, '0')}`,
    customerName: String(b.customerName),
    phone: String(b.phone),
    items: b.items.map((i) => ({
      serviceId: String(i.serviceId || ''),
      name: String(i.name || ''),
      unit: String(i.unit || 'pcs'),
      price: Number(i.price) || 0,
      qty: Number(i.qty) || 1,
    })),
    contents: (Array.isArray(b.contents) ? b.contents : []).map(String),
    scheduledAt: b.scheduledAt || t,
    notes: String(b.notes || ''),
    status: 'menunggu',
    history: [{ status: 'menunggu', at: t }],
    paid: false,
    createdAt: t,
  };
  db.orders.unshift(order);
  save();
  res.json(order);
});

app.post('/api/orders/:id/advance', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const o = findOrder(req, res);
  if (!o) return;
  const i = STATUS.indexOf(o.status);
  if (i >= 0 && i < STATUS.length - 1) {
    o.status = STATUS[i + 1];
    const entry = { status: o.status, at: now() };
    if (a.name) entry.by = a.name;
    o.history.push(entry);
    save();
  }
  res.json(o);
});

app.post('/api/orders/:id/paid', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const o = findOrder(req, res);
  if (!o) return;
  o.paid = !!(req.body || {}).paid;
  save();
  res.json(o);
});

app.post('/api/orders/:id/item-qty', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const o = findOrder(req, res);
  if (!o) return;
  const { index, qty } = req.body || {};
  if (!Number.isInteger(index) || index < 0 || index >= o.items.length ||
      !(Number(qty) > 0)) {
    return res.status(400).json({ error: 'Index/qty tidak valid' });
  }
  o.items[index].qty = Number(qty);
  save();
  res.json(o);
});

app.delete('/api/orders/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const before = db.orders.length;
  db.orders = db.orders.filter((o) => o.id !== req.params.id);
  if (db.orders.length === before) {
    return res.status(404).json({ error: 'Pesanan tidak ditemukan' });
  }
  save();
  res.json({ ok: true });
});

// ---- Katalog item ----

app.post('/api/services', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const b = req.body || {};
  if (!b.name || !(Number(b.price) > 0)) {
    return res.status(400).json({ error: 'Nama/harga tidak valid' });
  }
  const s = {
    id: `custom_${Date.now()}`,
    name: String(b.name),
    unit: ['kg', 'pcs', 'pasang'].includes(b.unit) ? b.unit : 'pcs',
    price: Number(b.price),
    description: String(b.description || ''),
    estimasiHari: Number(b.estimasiHari) > 0 ? Number(b.estimasiHari) : 2,
  };
  db.services.push(s);
  save();
  res.json(s);
});

app.put('/api/services/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const s = db.services.find((s) => s.id === req.params.id);
  if (!s) return res.status(404).json({ error: 'Item tidak ditemukan' });
  const b = req.body || {};
  if (b.name) s.name = String(b.name);
  if (['kg', 'pcs', 'pasang'].includes(b.unit)) s.unit = b.unit;
  if (Number(b.price) > 0) s.price = Number(b.price);
  if (Number(b.estimasiHari) > 0) s.estimasiHari = Number(b.estimasiHari);
  if (b.description !== undefined) s.description = String(b.description);
  save();
  res.json(s);
});

app.delete('/api/services/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const before = db.services.length;
  db.services = db.services.filter((s) => s.id !== req.params.id);
  if (db.services.length === before) {
    return res.status(404).json({ error: 'Item tidak ditemukan' });
  }
  save();
  res.json({ ok: true });
});

// ---- Admin ----

app.post('/api/admin/login', (req, res) => {
  const { id, pin } = req.body || {};
  const a = db.admins.find((a) => a.id === id && a.pin === String(pin));
  if (!a) return res.status(401).json({ error: 'PIN salah' });
  res.json({ ok: true, admin: { id: a.id, name: a.name } });
});

app.get('/api/admins', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  res.json(db.admins.map(({ id, name }) => ({ id, name })));
});

app.post('/api/admins', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const { name, pin } = req.body || {};
  if (!name || !/^[0-9]{4,6}$/.test(String(pin))) {
    return res.status(400).json({ error: 'Nama wajib; PIN 4-6 angka' });
  }
  const adminUser = {
    id: `admin_${Date.now()}`,
    name: String(name),
    pin: String(pin),
  };
  db.admins.push(adminUser);
  save();
  res.json({ id: adminUser.id, name: adminUser.name });
});

app.put('/api/admins/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const target = db.admins.find((x) => x.id === req.params.id);
  if (!target) return res.status(404).json({ error: 'Admin tidak ditemukan' });
  const { name, pin } = req.body || {};
  if (name) target.name = String(name);
  if (pin) {
    if (!/^[0-9]{4,6}$/.test(String(pin))) {
      return res.status(400).json({ error: 'PIN 4-6 angka' });
    }
    target.pin = String(pin);
  }
  save();
  res.json({ id: target.id, name: target.name });
});

app.delete('/api/admins/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const before = db.admins.length;
  db.admins = db.admins.filter((x) => x.id !== req.params.id);
  if (db.admins.length === before) {
    return res.status(404).json({ error: 'Admin tidak ditemukan' });
  }
  save();
  res.json({ ok: true });
});

// Dengan SSL_CERT + SSL_KEY (path file sertifikat, mis. Let's Encrypt),
// server melayani HTTPS langsung — berguna bila reverse proxy web server
// (LiteSpeed/Apache) sulit dikonfigurasi. Tanpa keduanya: HTTP biasa
// (di belakang reverse proxy).
if (process.env.SSL_CERT && process.env.SSL_KEY) {
  https
    .createServer(
      {
        cert: fs.readFileSync(process.env.SSL_CERT),
        key: fs.readFileSync(process.env.SSL_KEY),
      },
      app,
    )
    .listen(PORT, () => {
      console.log(`H2O Laundry API (HTTPS) berjalan di port ${PORT}`);
      console.log(`Data tersimpan di ${DATA_FILE}`);
    });
} else {
  app.listen(PORT, () => {
    console.log(`H2O Laundry API berjalan di port ${PORT}`);
    console.log(`Data tersimpan di ${DATA_FILE}`);
  });
}
