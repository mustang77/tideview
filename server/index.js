// Backend API H2O Laundry Parakan.
// Penyimpanan: satu file JSON (data.json) dengan tulis atomik —
// sederhana, tanpa database terpisah, cukup untuk satu gerai laundry.
//
// Jalankan:  PORT=8080 node index.js
// Data:      DATA_FILE=/path/data.json (default: ./data.json)

const crypto = require('crypto');
const express = require('express');
const fs = require('fs');
const https = require('https');
const path = require('path');

const PORT = process.env.PORT || 8080;
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data.json');
// Proyek Firebase untuk verifikasi OTP nomor HP saat registrasi.
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'wca-mobile-10a8d';
// REQUIRE_OTP=1 → registrasi wajib membawa idToken Firebase yang sah
// (aktifkan setelah semua platform, termasuk web, punya alur OTP).
const REQUIRE_OTP = process.env.REQUIRE_OTP === '1';

const STATUS = ['menunggu', 'diterima', 'diproses', 'siap', 'selesai'];

const defaultServices = [
  { id: 'cuci_setrika', name: 'Cuci + Setrika', unit: 'kg', price: 7000, description: 'Cuci bersih, wangi, dan disetrika rapi', estimasiHari: 2 },
  { id: 'cuci_kering', name: 'Cuci Kering', unit: 'kg', price: 5000, description: 'Cuci dan keringkan, lipat tanpa setrika', estimasiHari: 2 },
  { id: 'setrika', name: 'Setrika Saja', unit: 'kg', price: 4000, description: 'Pakaian bersih Anda disetrika rapi', estimasiHari: 1 },
  { id: 'express', name: 'Express 1 Hari', unit: 'kg', price: 12000, description: 'Cuci + setrika kilat, selesai 24 jam', estimasiHari: 1 },
];

let db = { seq: 1, services: defaultServices, orders: [], admins: [], customers: [] };
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
// Normalisasi nomor HP ke format 62xxx supaya 0812/62812/812 dianggap sama.
const normPhone = (p) => {
  let d = digits(p);
  if (d.startsWith('0')) d = '62' + d.slice(1);
  else if (!d.startsWith('62')) d = '62' + d;
  return d;
};
const now = () => new Date().toISOString();

// ---- Verifikasi ID token Firebase (bukti OTP nomor HP) ----
// Token ditandatangani Google (RS256); sertifikat publiknya diambil dari
// endpoint securetoken dan di-cache sesuai header Cache-Control.

let fbCerts = { keys: {}, expires: 0 };
function firebaseCerts() {
  return new Promise((resolve, reject) => {
    if (Date.now() < fbCerts.expires) return resolve(fbCerts.keys);
    https
      .get(
        'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
        (r) => {
          let body = '';
          r.on('data', (d) => (body += d));
          r.on('end', () => {
            try {
              const keys = JSON.parse(body);
              const m = String(r.headers['cache-control'] || '').match(/max-age=(\d+)/);
              fbCerts = { keys, expires: Date.now() + (m ? Number(m[1]) : 3600) * 1000 };
              resolve(keys);
            } catch (e) {
              reject(e);
            }
          });
        }
      )
      .on('error', reject);
  });
}

const b64uJson = (s) =>
  JSON.parse(Buffer.from(String(s).replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));

// Kembalikan { phone } (format 62xxx) bila token sah, selain itu null.
async function verifyFirebaseToken(idToken) {
  const parts = String(idToken || '').split('.');
  if (parts.length !== 3) return null;
  let header, payload;
  try {
    header = b64uJson(parts[0]);
    payload = b64uJson(parts[1]);
  } catch (e) {
    return null;
  }
  if (header.alg !== 'RS256' || !header.kid) return null;
  const certs = await firebaseCerts();
  const pem = certs[header.kid];
  if (!pem) return null;
  const ok = crypto
    .createVerify('RSA-SHA256')
    .update(parts[0] + '.' + parts[1])
    .verify(
      crypto.createPublicKey(pem),
      Buffer.from(parts[2].replace(/-/g, '+').replace(/_/g, '/'), 'base64')
    );
  if (!ok) return null;
  const nowSec = Math.floor(Date.now() / 1000);
  if (payload.aud !== FIREBASE_PROJECT_ID) return null;
  if (payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`) return null;
  if (!(Number(payload.exp) > nowSec)) return null;
  if (!payload.phone_number) return null;
  return { phone: normPhone(payload.phone_number) };
}

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use((req, res, next) => {
  res.set({
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers':
        'Content-Type,x-admin-id,x-admin-pin,x-cust-phone,x-cust-pin',
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
// Akun pelanggan: satu nomor HP = satu akun, dilindungi PIN.
function customer(req) {
  const phone = normPhone(req.get('x-cust-phone') || '');
  const pin = String(req.get('x-cust-pin') || '');
  if (!phone || !pin) return null;
  return db.customers.find((c) => c.phone === phone && c.pin === pin) || null;
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
  } else if (req.get('x-cust-phone')) {
    const c = customer(req);
    if (!c) {
      return res.status(401).json({ error: 'Sesi pelanggan tidak valid' });
    }
    orders = db.orders.filter((o) => normPhone(o.phone) === c.phone);
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
  const c = customer(req);
  if (!c) {
    return res
        .status(401)
        .json({ error: 'Silakan masuk dengan nomor HP dan PIN Anda' });
  }
  const b = req.body || {};
  if (!Array.isArray(b.items) || b.items.length === 0) {
    return res.status(400).json({ error: 'Data pesanan tidak lengkap' });
  }
  const t = now();
  const order = {
    id: `H2O-${String(db.seq++).padStart(4, '0')}`,
    customerName: c.name,
    phone: c.phone,
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

// ---- Akun pelanggan ----

app.post('/api/customer/register', async (req, res) => {
  const { name, phone, pin, idToken } = req.body || {};
  if (!name || !/^[0-9]{4,6}$/.test(String(pin))) {
    return res.status(400).json({ error: 'Nama wajib diisi; PIN 4-6 angka' });
  }
  const np = normPhone(phone);
  if (np.length < 10) {
    return res.status(400).json({ error: 'Nomor HP tidak valid' });
  }
  if (db.customers.find((c) => c.phone === np)) {
    return res.status(409).json({
      error: 'Nomor ini sudah terdaftar. Silakan masuk dengan PIN Anda.',
    });
  }
  // Bukti kepemilikan nomor: idToken Firebase hasil OTP SMS. Nomor di
  // dalam token harus sama dengan nomor yang didaftarkan.
  let verified = false;
  if (idToken) {
    let v = null;
    try {
      v = await verifyFirebaseToken(idToken);
    } catch (e) {
      console.error('Verifikasi token Firebase gagal:', e.message);
    }
    if (!v || v.phone !== np) {
      return res
        .status(401)
        .json({ error: 'Verifikasi OTP gagal. Silakan coba lagi.' });
    }
    verified = true;
  } else if (REQUIRE_OTP) {
    return res
      .status(401)
      .json({ error: 'Pendaftaran membutuhkan verifikasi OTP.' });
  }
  db.customers.push({
    phone: np,
    name: String(name),
    pin: String(pin),
    verified,
    createdAt: now(),
  });
  save();
  res.json({ ok: true, name: String(name), phone: np });
});

app.post('/api/customer/login', (req, res) => {
  const np = normPhone((req.body || {}).phone);
  const pin = String((req.body || {}).pin || '');
  const c = db.customers.find((c) => c.phone === np && c.pin === pin);
  if (!c) return res.status(401).json({ error: 'Nomor atau PIN salah' });
  res.json({ ok: true, name: c.name, phone: c.phone });
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
