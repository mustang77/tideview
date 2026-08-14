// Backend API H2O Laundry Parakan.
// Penyimpanan: satu file JSON (data.json) dengan tulis atomik —
// sederhana, tanpa database terpisah, cukup untuk satu gerai laundry.
//
// Jalankan:  PORT=8080 node index.js
// Data:      DATA_FILE=/path/data.json (default: ./data.json)

const { execFileSync } = require('child_process');
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

let db = { seq: 1, services: defaultServices, orders: [], admins: [], customers: [], posts: [] };
if (fs.existsSync(DATA_FILE)) {
  try {
    db = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  } catch (e) {
    console.error('data.json tidak bisa dibaca — mulai dari kosong:', e.message);
  }
}
db.posts = db.posts || [];
db.notifs = db.notifs || [];
// Ubin Hiburan (musik, game, dll) yang dikelola admin dari aplikasi.
db.hiburan = db.hiburan || [];
// Chat Layanan Pelanggan: daftar pesan datar {phone, fromAdmin, ...}.
db.chats = db.chats || [];
// No. WA per admin (tujuan notifikasi pesanan baru) — migrasi.
(db.admins || []).forEach((x) => {
  if (x.phone === undefined) x.phone = '';
});
// Info toko (layar "Tentang") — bisa diedit pemilik dari aplikasi.
db.about = Object.assign(
    {
      name: 'H2O Laundry Parakan',
      tagline: 'Laundry bersih, wangi, dan rapi',
      address: 'Parakan, Temanggung, Jawa Tengah',
      wa: '',
      hours: '',
      maps: '',
      instagram: '',
    },
    db.about || {});

// Reaksi pos promo: nomor HP -> emoji. Migrasi dari 'likes' lama
// (array nomor HP) menjadi reaksi hati.
const REACTIONS = ['❤️', '👍', '🔥', '🎉', '😂', '😮'];
// Profil sosial pelanggan: uid buram (agar nomor HP tidak bocor antar
// pelanggan), foto profil, dan daftar mengikuti.
let uidSeq = 0;
(db.customers || []).forEach((c) => {
  if (!c.uid) c.uid = `u_${Date.now().toString(36)}_${uidSeq++}`;
  if (c.photo === undefined) c.photo = '';
  if (!Array.isArray(c.following)) c.following = [];
  if (c.private === undefined) c.private = false;
});
const custByPhone = (ph) => db.customers.find((c) => c.phone === ph);
const custByUid = (uid) => db.customers.find((c) => c.uid === uid);

db.posts.forEach((p) => {
  if (!p.reactions) {
    p.reactions = {};
    (p.likes || []).forEach((ph) => (p.reactions[ph] = '❤️'));
  }
  delete p.likes;
  // Pos lama semuanya buatan admin (fitur komunitas datang belakangan).
  if (p.byAdmin === undefined) p.byAdmin = true;
  if (p.authorPhone === undefined) p.authorPhone = '';
  if (p.authorUid === undefined) {
    const c = custByPhone(p.authorPhone);
    p.authorUid = c ? c.uid : '';
  }
  if (!p.bookmarks) p.bookmarks = {};
});

let saveTimer = null;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const tmp = DATA_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(db, null, 1));
    fs.renameSync(tmp, DATA_FILE);
  }, 100);
}

// Folder foto promo (dilayani statis di /uploads).
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, 'uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// ffmpeg (bila terpasang: apt install -y ffmpeg) dipakai membuat
// thumbnail video reel. Tanpa ffmpeg, ubin reel memakai latar polos.
let HAS_FFMPEG = false;
try {
  execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
  HAS_FFMPEG = true;
} catch (e) {
  console.log('ffmpeg tidak ditemukan — thumbnail reel dinonaktifkan');
}

function makeThumb(videoFile) {
  const t = videoFile.replace(/\.\w+$/, '') + '_thumb.jpg';
  execFileSync('ffmpeg', [
    '-y', '-ss', '0.3', '-i', path.join(UPLOAD_DIR, videoFile),
    '-frames:v', '1', '-vf', 'scale=480:-2',
    path.join(UPLOAD_DIR, t),
  ], { stdio: 'ignore', timeout: 30000 });
  return fs.existsSync(path.join(UPLOAD_DIR, t)) ? t : '';
}

// Isi-ulang: video lama yang belum punya thumbnail dibuatkan saat
// server mulai (berguna setelah ffmpeg baru dipasang).
if (HAS_FFMPEG) {
  let filled = 0;
  db.posts.forEach((p) => {
    if (p.video && !p.videoThumb &&
        fs.existsSync(path.join(UPLOAD_DIR, p.video))) {
      try {
        p.videoThumb = makeThumb(p.video);
        if (p.videoThumb) filled++;
      } catch (e) {
        console.error('Backfill thumbnail gagal:', p.video, e.message);
      }
    }
  });
  if (filled) {
    console.log(`Thumbnail dibuat untuk ${filled} video lama`);
    save();
  }
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

// ---- Notifikasi dalam-aplikasi ----
// Disimpan per penerima (nomor HP pelanggan) dan diantar lewat
// /api/state, jadi ikut siklus polling aplikasi.
let notifSeq = 0;
function notify(phone, type, text, extra = {}) {
  if (!phone) return;
  db.notifs.push({
    id: `n_${Date.now()}_${notifSeq++}`,
    phone,
    type,
    text,
    at: now(),
    read: false,
    ...extra,
  });
  // Jaga ukuran file data: simpan maksimal 800 notifikasi terakhir.
  if (db.notifs.length > 800) db.notifs = db.notifs.slice(-800);
  save();
}

const STATUS_NOTIF = {
  diterima: 'sudah diterima di laundry',
  diproses: 'sedang diproses',
  siap: 'SIAP DIAMBIL! 🎉',
  selesai: 'selesai — terima kasih! 🙏',
};

// ---- Notifikasi WhatsApp otomatis ----
// Dikirim lewat gateway WA yang sama dengan OTP (WA_OTP_TOKEN/URL).
// Antrean berjarak 1,5 dtk antar pesan supaya tidak dianggap spam.
// Hanya pesan transaksional pesanan; broadcast promo ke WA sengaja
// di belakang WA_PROMO_BROADCAST=1 karena berisiko banned.
let waQueue = Promise.resolve();
function queueWa(phone, text) {
  if (!WA_OTP_TOKEN || !phone) return;
  waQueue = waQueue
      .then(() => sendWa(normPhone(phone), text))
      .then(() => new Promise((r) => setTimeout(r, 1500)))
      .catch((e) =>
          console.error('Notif WA gagal ke', phone, '-', e.message));
}

// Rincian item pesanan untuk pesan WA: "- Cuci + Setrika 3 kg".
const waRp = (n) => `Rp ${Number(n).toLocaleString('id-ID')}`;
function waItems(o) {
  return (o.items || [])
      .map((i) => `- ${i.name} ${String(i.qty).replace('.', ',')} ` +
          `${i.unit} = ${waRp(i.price * i.qty)}`)
      .join('\n');
}
const waTotal = (o) =>
    (o.items || []).reduce((s, i) => s + i.price * i.qty, 0);

// Isi cucian yang dideklarasikan pelanggan: "- 5 kaos", "- 2 kemeja".
function waContents(o) {
  const c = (o.contents || []).map((x) => String(x).trim()).filter(Boolean);
  if (!c.length) return '';
  return `\nIsi cucian:\n${c.map((x) => `- ${x}`).join('\n')}`;
}

const WA_STATUS_MSG = {
  diterima: (o) =>
      `Cucian pesanan *${o.id}* sudah kami terima di counter dan segera ` +
      `diproses. 💧\n\n${waItems(o)}${waContents(o)}\n` +
      `Total: *${waRp(waTotal(o))}*\n\n_H2O Laundry Parakan_`,
  siap: (o) =>
      `Kabar gembira! 🎉\nCucian pesanan *${o.id}* sudah *SIAP DIAMBIL* ` +
      `di H2O Laundry Parakan.\n\n${waItems(o)}${waContents(o)}\n` +
      `Total: *${waRp(waTotal(o))}*${o.paid ? ' (LUNAS)' : ''}\n\n` +
      'Sampai jumpa di counter!',
  selesai: (o) =>
      `Pesanan *${o.id}* selesai. Terima kasih sudah laundry di H2O ` +
      'Laundry Parakan! 🙏',
};

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
// 60mb: badan JSON promo bisa memuat video reel base64 (maks 30 MB biner).
app.use(express.json({ limit: '60mb' }));
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
// Setelah middleware CORS supaya foto bisa dimuat kanvas Flutter web.
app.use('/uploads', express.static(UPLOAD_DIR, { maxAge: '7d' }));

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
  let custPhone = null;
  if (a) {
    orders = db.orders;
  } else if (req.get('x-cust-phone')) {
    const c = customer(req);
    if (!c) {
      return res.status(401).json({ error: 'Sesi pelanggan tidak valid' });
    }
    custPhone = c.phone;
    orders = db.orders.filter((o) => normPhone(o.phone) === c.phone);
  }
  const notifs = custPhone
      ? db.notifs.filter((n) => n.phone === custPhone).slice(-50).reverse()
      : [];
  const meC = custPhone ? custByPhone(custPhone) : null;
  res.json({
    me: meC
        ? {
            uid: meC.uid,
            photoUrl: meC.photo ? `/uploads/${meC.photo}` : '',
            isPrivate: !!meC.private,
            following: meC.following,
            followers: db.customers
                .filter((x) => x.following.includes(meC.uid)).length,
          }
        : null,
    services: db.services,
    // No. WA admin hanya dibuka untuk sesama admin (privasi).
    adminNames: db.admins.map((x) => a
        ? { id: x.id, name: x.name, phone: x.phone || '' }
        : { id: x.id, name: x.name }),
    orders,
    posts: db.posts.map((p) => postView(p, custPhone)),
    notifs,
    hiburan: db.hiburan,
    // Chat Layanan Pelanggan: pelanggan menerima utasnya sendiri,
    // admin menerima semua pesan (dikelompokkan per pelanggan di klien).
    chat: custPhone
        ? db.chats.filter((x) => x.phone === custPhone).slice(-100).map(chatView)
        : [],
    chatUnread: custPhone
        ? db.chats.filter(
            (x) => x.phone === custPhone && x.fromAdmin && !x.readByCust).length
        : 0,
    chats: a ? db.chats.slice(-400).map(chatView) : [],
    about: db.about,
    isAdmin: !!a,
  });
});

// Perbarui info toko (layar Tentang) — hanya admin.
app.post('/api/about', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const b = req.body || {};
  for (const k of
      ['name', 'tagline', 'address', 'wa', 'hours', 'maps', 'instagram']) {
    if (b[k] !== undefined) db.about[k] = String(b[k]).trim().slice(0, 300);
  }
  if (!db.about.name) db.about.name = 'H2O Laundry Parakan';
  save();
  res.json(db.about);
});

// ---- Profil sosial pelanggan ----

function userView(u, me) {
  return {
    uid: u.uid,
    name: u.name,
    photoUrl: u.photo ? `/uploads/${u.photo}` : '',
    followers:
        db.customers.filter((x) => x.following.includes(u.uid)).length,
    following: u.following.length,
    followedByMe: !!(me && me.following.includes(u.uid)),
    isPrivate: !!u.private,
  };
}

// Unggah/ganti foto profil (maks 3 MB).
app.post('/api/customer/photo', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Sesi tidak valid' });
  const b = req.body || {};
  let buf;
  try {
    buf = Buffer.from(String(b.imageData || ''), 'base64');
  } catch (e) {
    buf = Buffer.alloc(0);
  }
  if (!buf.length || buf.length > 3 * 1024 * 1024) {
    return res.status(400).json({ error: 'Foto tidak valid atau lebih dari 3 MB' });
  }
  if (c.photo) {
    try {
      fs.unlinkSync(path.join(UPLOAD_DIR, c.photo));
    } catch (e) {}
  }
  const ext = ['png', 'webp'].includes(b.imageExt) ? b.imageExt : 'jpg';
  c.photo = `avatar_${c.uid}_${Date.now()}.${ext}`;
  fs.writeFileSync(path.join(UPLOAD_DIR, c.photo), buf);
  save();
  res.json({ ok: true, photoUrl: `/uploads/${c.photo}` });
});

// Atur privasi profil: privat = postingan & daftar pengikut hanya
// terlihat oleh pemilik profil.
app.post('/api/customer/privacy', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Sesi tidak valid' });
  c.private = !!(req.body || {}).private;
  save();
  res.json({ ok: true, isPrivate: c.private });
});

app.get('/api/users/:uid', (req, res) => {
  const u = custByUid(req.params.uid);
  if (!u) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  res.json(userView(u, customer(req)));
});

// Daftar pengikut / mengikuti. Profil privat hanya bisa dilihat
// pemiliknya sendiri — selain itu balas {private:true} tanpa daftar.
const miniUser = (u) => ({
  uid: u.uid,
  name: u.name,
  photoUrl: u.photo ? `/uploads/${u.photo}` : '',
});
app.get('/api/users/:uid/followers', (req, res) => {
  const u = custByUid(req.params.uid);
  if (!u) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  const me = customer(req);
  if (u.private && (!me || me.uid !== u.uid)) {
    return res.json({ private: true, users: [] });
  }
  res.json({
    private: false,
    users: db.customers
        .filter((x) => x.following.includes(u.uid)).map(miniUser),
  });
});
app.get('/api/users/:uid/following', (req, res) => {
  const u = custByUid(req.params.uid);
  if (!u) return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  const me = customer(req);
  if (u.private && (!me || me.uid !== u.uid)) {
    return res.json({ private: true, users: [] });
  }
  res.json({
    private: false,
    users: u.following.map(custByUid).filter(Boolean).map(miniUser),
  });
});

// Ikuti/berhenti mengikuti pengguna lain.
app.post('/api/users/:uid/follow', (req, res) => {
  const me = customer(req);
  if (!me) return res.status(401).json({ error: 'Silakan masuk dulu' });
  const target = custByUid(req.params.uid);
  if (!target) {
    return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  }
  if (target.uid === me.uid) {
    return res.status(400).json({ error: 'Tidak bisa mengikuti diri sendiri' });
  }
  const i = me.following.indexOf(target.uid);
  if (i >= 0) {
    me.following.splice(i, 1);
  } else {
    me.following.push(target.uid);
    notify(target.phone, 'follow', `${me.name} mulai mengikuti Anda 🎉`);
  }
  save();
  res.json(userView(target, me));
});

// Simpan/hapus simpanan pos (bookmark).
app.post('/api/posts/:id/bookmark', (req, res) => {
  const c = customer(req);
  if (!c) {
    return res.status(401).json({ error: 'Silakan masuk untuk menyimpan' });
  }
  const p = findPost(req, res);
  if (!p) return;
  p.bookmarks = p.bookmarks || {};
  if (p.bookmarks[c.uid]) delete p.bookmarks[c.uid];
  else p.bookmarks[c.uid] = true;
  save();
  res.json(postView(p, c.phone));
});

// ---- Ramalan Zodiak harian (hiburan) ----
// Dibangkitkan deterministik dari (zodiak + tanggal): semua orang
// melihat ramalan yang sama sepanjang hari, besok berganti. Murni
// hiburan — tanpa layanan luar.

const ZODIAC = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
  'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];

const Z_UMUM = [
  'Hari ini energimu sedang bagus untuk memulai hal baru.',
  'Ada kabar kecil yang bisa mengubah suasana hatimu jadi lebih cerah.',
  'Jangan terburu-buru mengambil keputusan; pikirkan sekali lagi.',
  'Orang di sekitarmu lebih memperhatikanmu daripada yang kamu kira.',
  'Waktu yang pas untuk membereskan urusan yang tertunda.',
  'Intuisimu tajam hari ini — dengarkan kata hatimu.',
  'Sedikit istirahat akan membuat harimu jauh lebih produktif.',
  'Kesabaranmu akan diuji, tapi hasilnya sepadan.',
  'Hal sederhana bisa membawa kebahagiaan besar hari ini.',
  'Cobalah keluar dari rutinitas — kejutan menyenangkan menunggu.',
];
const Z_ASMARA = [
  'Komunikasi yang jujur membuat hubungan makin hangat.',
  'Yang masih sendiri: seseorang diam-diam mengagumimu.',
  'Luangkan waktu berkualitas dengan pasangan, sekecil apa pun.',
  'Jangan biarkan gengsi menghalangi permintaan maaf.',
  'Perhatian kecil hari ini berarti besar bagi orang tersayang.',
  'Dengarkan dulu sebelum menanggapi — itu kunci harimu.',
  'Sebuah pesan singkat bisa mencairkan suasana yang kaku.',
  'Cinta tumbuh dari hal-hal kecil yang konsisten.',
];
const Z_KEUANGAN = [
  'Tahan dulu belanja impulsif; simpan untuk kebutuhan mendesak.',
  'Ada peluang penghasilan tambahan dari keahlianmu.',
  'Catat pengeluaranmu hari ini — ada kebocoran kecil.',
  'Rezeki datang dari arah yang tidak terduga.',
  'Waktu yang baik untuk mulai menabung, sekecil apa pun.',
  'Jangan ragu menagih yang menjadi hakmu, dengan sopan.',
  'Investasi terbaik hari ini adalah menambah ilmu.',
  'Berbagi sedikit rezeki akan membuka pintu rezeki berikutnya.',
];
const Z_KARIER = [
  'Fokus pada satu tugas penting; jangan terpecah ke banyak hal.',
  'Ide kecilmu bisa jadi solusi besar untuk tim.',
  'Atasan atau rekan memperhatikan kerja kerasmu — teruskan.',
  'Jangan sungkan bertanya; itu mempercepat pekerjaanmu.',
  'Rapikan daftar tugasmu, prioritas akan terlihat jelas.',
  'Tantangan hari ini adalah latihan untuk naik level.',
  'Kolaborasi membawa hasil lebih baik daripada bekerja sendiri.',
  'Selesaikan yang mudah dulu untuk membangun momentum.',
];
const Z_SEHAT = [
  'Perbanyak minum air putih; tubuhmu butuh cairan lebih.',
  'Tidur cukup malam ini akan memulihkan energimu.',
  'Gerakkan badan 15 menit saja, efeknya terasa seharian.',
  'Kurangi kafein sore ini supaya tidurmu nyenyak.',
  'Jangan tunda makan; perutmu sudah memberi kode.',
  'Pikiran tenang dimulai dari napas yang teratur.',
  'Regangkan punggung dan lehermu di sela kesibukan.',
  'Udara segar pagi hari adalah vitamin gratis untukmu.',
];
const Z_WARNA = ['Biru Laut', 'Hijau Daun', 'Kuning Cerah', 'Merah Marun',
  'Ungu Lembut', 'Putih Bersih', 'Jingga Senja', 'Toska', 'Merah Muda',
  'Abu Perak', 'Emas', 'Cokelat Kayu'];

function zSeed(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
function zRng(seed) {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
// Ambil 2 kalimat berbeda dari bank dan gabungkan.
function zPick2(rng, bank) {
  const i = Math.floor(rng() * bank.length);
  let j = Math.floor(rng() * (bank.length - 1));
  if (j >= i) j++;
  return `${bank[i]} ${bank[j]}`;
}

app.get('/api/zodiac/:sign', (req, res) => {
  const sign = ZODIAC.find(
      (s) => s.toLowerCase() === String(req.params.sign).toLowerCase());
  if (!sign) return res.status(404).json({ error: 'Zodiak tidak dikenal' });
  const date = new Date().toISOString().slice(0, 10);
  const rng = zRng(zSeed(`${sign}|${date}|h2o`));
  const others = ZODIAC.filter((s) => s !== sign);
  res.json({
    sign,
    date,
    umum: zPick2(rng, Z_UMUM),
    asmara: zPick2(rng, Z_ASMARA),
    keuangan: zPick2(rng, Z_KEUANGAN),
    karier: zPick2(rng, Z_KARIER),
    kesehatan: zPick2(rng, Z_SEHAT),
    angka: 1 + Math.floor(rng() * 99),
    warna: Z_WARNA[Math.floor(rng() * Z_WARNA.length)],
    pasangan: others[Math.floor(rng() * others.length)],
    rating: {
      asmara: 2 + Math.floor(rng() * 4),
      keuangan: 2 + Math.floor(rng() * 4),
      karier: 2 + Math.floor(rng() * 4),
      kesehatan: 2 + Math.floor(rng() * 4),
    },
  });
});

// ---- Berita Indonesia (hiburan) ----
// Agregasi RSS media nasional, di-cache 15 menit. Gambar unggulan
// dilewatkan lewat proxy /api/newsimg supaya tampil di Flutter web
// (CDN berita tidak mengirim header CORS).

const NEWS_FEEDS = [
  { source: 'Antara', url: 'https://www.antaranews.com/rss/terkini.xml' },
  { source: 'CNN Indonesia',
    url: 'https://www.cnnindonesia.com/nasional/rss' },
  { source: 'detikNews', url: 'https://rss.detik.com/index.php/detikcom' },
];
let newsCache = { at: 0, items: [], imgs: new Set() };
let newsBusy = null;

function rssText(block, tag) {
  const m = block.match(
      new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
  if (!m) return '';
  return unescapeHtml(
      m[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1'))
      .replace(/<[^>]+>/g, '').trim();
}
function rssImage(block) {
  const m = block.match(/<enclosure[^>]+url=["']([^"']+)["']/i) ||
      block.match(/<media:(?:content|thumbnail)[^>]+url=["']([^"']+)["']/i) ||
      block.match(/<img[^>]+src=["']([^"']+)["']/i);
  return m ? unescapeHtml(m[1]) : '';
}

async function refreshNews() {
  const all = [];
  const imgs = new Set();
  await Promise.all(NEWS_FEEDS.map(async (f) => {
    try {
      const { buffer } = await fetchUrl(f.url,
          { maxBytes: 2 * 1024 * 1024, allowTruncate: true });
      for (const m of buffer.toString('utf8')
          .matchAll(/<item[\s\S]*?<\/item>/gi)) {
        const b = m[0];
        const title = rssText(b, 'title');
        const link = rssText(b, 'link');
        if (!title || !link) continue;
        const img = rssImage(b);
        if (img) imgs.add(img);
        const d = new Date(rssText(b, 'pubDate'));
        all.push({
          title,
          link,
          source: f.source,
          image: img,
          at: isNaN(d.getTime()) ? now() : d.toISOString(),
        });
      }
    } catch (e) {
      console.error('RSS gagal:', f.source, '-', e.message);
    }
  }));
  all.sort((a, b) => b.at.localeCompare(a.at));
  // Feed gagal semua? Pertahankan cache lama daripada mengosongkan.
  if (all.length) newsCache = { at: Date.now(), items: all.slice(0, 40), imgs };
  else newsCache.at = Date.now() - 12 * 60 * 1000; // coba lagi 3 mnt lagi
}

app.get('/api/news', async (req, res) => {
  if (Date.now() - newsCache.at > 15 * 60 * 1000) {
    // Satu penyegaran untuk semua permintaan yang datang bersamaan.
    newsBusy = newsBusy || refreshNews().finally(() => (newsBusy = null));
    await newsBusy;
  }
  res.json({ items: newsCache.items });
});

// Proxy gambar berita (hanya URL yang ada di cache — bukan proxy bebas).
app.get('/api/newsimg', async (req, res) => {
  const u = String(req.query.u || '');
  if (!newsCache.imgs.has(u)) {
    return res.status(404).json({ error: 'Gambar tidak dikenal' });
  }
  try {
    const { buffer, type } = await fetchUrl(u, { maxBytes: 3 * 1024 * 1024 });
    res.set('Content-Type', type || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=3600');
    res.end(buffer);
  } catch (e) {
    res.status(502).json({ error: 'Gagal memuat gambar' });
  }
});

// ---- Video Musik Indonesia (YouTube) ----
// Daftar video diambil dari RSS publik channel musisi/label resmi
// Indonesia (tanpa API key). Pemutaran di klien memakai player embed
// resmi YouTube sehingga lisensi tetap dipegang YouTube/pemilik
// channel. Thumbnail dilewatkan proxy /api/ytimg (i.ytimg.com tidak
// mengirim header CORS). Cache 6 jam.

const YT_MUSIC_CHANNELS = [
  { id: 'UCRggxhdYIz0zSvUgJmCWMGg', name: 'Tulus' },
  { id: 'UC8xcPPVYvUxv1CPoEcqj4fQ', name: 'Raisa' },
  { id: 'UCY1bGdpom5tXC9M8-Ahu8dQ', name: 'Bernadya' },
  { id: 'UCbctSuCowVV5nyQqlHSY9ZA', name: 'Juicy Luicy' },
  { id: 'UCgVRSxTc-ZCJkf49xKfRzZA', name: 'NOAH' },
  { id: 'UC9mnKuwm9QVCOaFZpkqS_DQ', name: 'Dewa 19' },
  { id: 'UCmgVKwwObSDquaJD7aaTUTQ', name: 'Fourtwnty' },
  { id: 'UCVbDyLu0MatwYdm2Bh8E79w', name: 'Lyodra' },
  { id: 'UC6B6N7-2yNGDZtLhAeTj6mA', name: 'Tiara Andini' },
  { id: 'UCrmQersjl9ooC0JZfp9CrtQ', name: 'Andmesh' },
  { id: 'UCaIbbu5Xg3DpHsn_3Zw2m9w', name: 'JKT48' },
  { id: 'UCpJRmMTfdv0iPbnjo6qBw_g', name: 'Aquarius Musikindo' },
  { id: 'UCebb7o98FEA73WjNsCja5Xg', name: 'Trinity Optima' },
];
let ytMusicCache = { at: 0, items: [] };
let ytMusicBusy = null;

async function refreshYtMusic() {
  const perChannel = [];
  await Promise.all(YT_MUSIC_CHANNELS.map(async (c) => {
    try {
      const { buffer } = await fetchUrl(
          `https://www.youtube.com/feeds/videos.xml?channel_id=${c.id}`,
          { maxBytes: 1024 * 1024, allowTruncate: true });
      const vids = [];
      for (const m of buffer.toString('utf8')
          .matchAll(/<entry>[\s\S]*?<\/entry>/gi)) {
        const b = m[0];
        const id =
            (b.match(/<yt:videoId>([\w-]{6,20})<\/yt:videoId>/) || [])[1];
        const title = rssText(b, 'title');
        if (!id || !title) continue;
        const d = new Date(rssText(b, 'published'));
        vids.push({
          id,
          title,
          channel: c.name,
          at: isNaN(d.getTime()) ? now() : d.toISOString(),
        });
        if (vids.length >= 6) break;
      }
      if (vids.length) perChannel.push(vids);
    } catch (e) {
      console.error('YT musik gagal:', c.name, '-', e.message);
    }
  }));
  // Selang-seling antar-channel supaya channel yang rajin mengunggah
  // (mis. JKT48) tidak mendominasi seluruh halaman.
  perChannel.sort((a, b) => b[0].at.localeCompare(a[0].at));
  const items = [];
  for (let i = 0; i < 6; i++) {
    for (const vids of perChannel) if (vids[i]) items.push(vids[i]);
  }
  // Feed gagal semua? Pertahankan cache lama, coba lagi 30 menit lagi.
  if (items.length) ytMusicCache = { at: Date.now(), items };
  else ytMusicCache.at = Date.now() - 5.5 * 60 * 60 * 1000;
}

app.get('/api/musikvideo', async (req, res) => {
  if (Date.now() - ytMusicCache.at > 6 * 60 * 60 * 1000) {
    // Satu penyegaran untuk semua permintaan yang datang bersamaan.
    ytMusicBusy = ytMusicBusy ||
        refreshYtMusic().finally(() => (ytMusicBusy = null));
    await ytMusicBusy;
  }
  res.json({ items: ytMusicCache.items });
});

// Proxy thumbnail YouTube (hanya ID video yang valid — bukan proxy bebas).
app.get('/api/ytimg', async (req, res) => {
  const v = String(req.query.v || '');
  if (!/^[\w-]{6,20}$/.test(v)) {
    return res.status(400).json({ error: 'ID video tidak valid' });
  }
  try {
    const { buffer, type } = await fetchUrl(
        `https://i.ytimg.com/vi/${v}/hqdefault.jpg`,
        { maxBytes: 1024 * 1024 });
    res.set('Content-Type', type || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=86400');
    res.end(buffer);
  } catch (e) {
    res.status(502).json({ error: 'Gagal memuat gambar' });
  }
});

// ---- Musik Indonesia (netlabel Creative Commons di archive.org) ----
// Yes No Wave (Yogyakarta), Mindblasting, dan Hujan! Rekords merilis
// musik Indonesia legal-gratis; arsipnya publik di archive.org.
// Bentuk balasan meniru kunci Jamendo supaya model Track klien tidak
// berubah. Cache 6 jam.

const MUSIK_ID_COLLECTIONS = ['yesnowave', 'mindblasting', 'hujanrekords'];
let musikIdCache = { at: 0, tracks: [] };
let musikIdBusy = null;

function iaSeconds(len) {
  const s = String(len || '');
  if (s.includes(':')) {
    const parts = s.split(':').map(Number);
    return parts.reduce((a, b) => a * 60 + b, 0) | 0;
  }
  return Math.round(Number(s)) || 0;
}

async function refreshMusikId() {
  const albums = [];
  await Promise.all(MUSIK_ID_COLLECTIONS.map(async (col) => {
    try {
      const q = `collection%3A${col}+AND+mediatype%3Aaudio`;
      const url = `https://archive.org/advancedsearch.php?q=${q}` +
          '&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=creator' +
          '&rows=8&output=json&sort%5B%5D=downloads+desc';
      const { buffer } = await fetchUrl(url, { maxBytes: 1024 * 1024 });
      const docs = JSON.parse(buffer.toString('utf8')).response.docs || [];
      for (const d of docs) albums.push(d);
    } catch (e) {
      console.error('Musik ID: pencarian gagal utk', col, '-', e.message);
    }
  }));
  const tracks = [];
  await Promise.all(albums.map(async (al) => {
    try {
      const { buffer } = await fetchUrl(
          `https://archive.org/metadata/${al.identifier}`,
          { maxBytes: 4 * 1024 * 1024 });
      const meta = JSON.parse(buffer.toString('utf8'));
      const artist = String(
          (Array.isArray(al.creator) ? al.creator[0] : al.creator) ||
          meta.metadata && meta.metadata.creator || 'Netlabel Indonesia');
      const mp3s = (meta.files || [])
          .filter((f) => String(f.format || '').endsWith('MP3'))
          .slice(0, 4); // maks 4 lagu per album supaya beragam
      for (const f of mp3s) {
        // Rapikan judul: garis bawah, nomor trek, dan nama artis yang
        // terulang di depan judul.
        let nm = String(f.title || f.name)
            .replace(/\.mp3$/i, '').replace(/_/g, ' ')
            .replace(/^[\s\-–—.]*\d*[\s.\-–—]*/, '').trim();
        const ai = nm.toLowerCase().indexOf(artist.toLowerCase());
        if (ai >= 0 && ai <= 2 && artist.length > 2) {
          nm = nm.slice(ai + artist.length).replace(/^[\s\-–—:()]+/, '');
        }
        nm = nm.replace(/\s+/g, ' ').trim();
        // Jalur relatif lewat proxy /api/iastream: archive.org
        // diblokir sebagian ISP Indonesia (klien memakai mediaUrl).
        const dl = `https://archive.org/download/${al.identifier}/` +
            encodeURIComponent(f.name);
        const img = `https://archive.org/services/img/${al.identifier}`;
        tracks.push({
          id: `${al.identifier}/${f.name}`,
          name: nm || f.name.replace(/\.mp3$/i, ''),
          artist_name: artist,
          audio: `/api/iastream?u=${encodeURIComponent(dl)}`,
          image: `/api/iastream?u=${encodeURIComponent(img)}`,
          duration: iaSeconds(f.length),
        });
      }
    } catch (e) {
      console.error('Musik ID: metadata gagal utk', al.identifier,
          '-', e.message);
    }
  }));
  if (tracks.length) {
    musikIdCache = { at: Date.now(), tracks };
  } else {
    musikIdCache.at = Date.now() - 5.5 * 60 * 60 * 1000; // coba lagi nanti
  }
}

// Proxy streaming archive.org — diblokir sebagian ISP Indonesia, jadi
// audio & sampul dialirkan lewat VPS ini. Mendukung header Range
// (seek) dan hanya menerima host archive.org.
const IA_HOST = /(^|\.)archive\.org$/i;
function pipeIa(u, req, res, redirects) {
  const headers = { 'user-agent': 'H2OLaundry/1.0' };
  if (req.headers.range) headers.range = req.headers.range;
  const r2 = https.get(u, { headers }, (ir) => {
    if (ir.statusCode >= 300 && ir.statusCode < 400 &&
        ir.headers.location && redirects > 0) {
      ir.resume();
      const next = new URL(ir.headers.location, u);
      if (!IA_HOST.test(next.hostname)) return res.status(502).end();
      return pipeIa(next, req, res, redirects - 1);
    }
    // archive.org sesekali 5xx di permintaan pertama — coba sekali lagi.
    if (ir.statusCode >= 500 && redirects > 0) {
      ir.resume();
      return setTimeout(() => pipeIa(u, req, res, 0), 400);
    }
    res.status(ir.statusCode);
    for (const h of ['content-type', 'content-length', 'content-range',
      'accept-ranges', 'cache-control', 'etag', 'last-modified']) {
      if (ir.headers[h]) res.set(h, ir.headers[h]);
    }
    ir.pipe(res);
  });
  r2.setTimeout(30000, () => r2.destroy(new Error('timeout')));
  r2.on('error', () => {
    if (!res.headersSent) res.status(502);
    res.end();
  });
  req.on('close', () => r2.destroy());
}
app.get('/api/iastream', (req, res) => {
  let u;
  try {
    u = new URL(String(req.query.u || ''));
  } catch (e) {
    return res.status(400).json({ error: 'URL tidak valid' });
  }
  if (u.protocol !== 'https:' || !IA_HOST.test(u.hostname)) {
    return res.status(400).json({ error: 'Hanya archive.org' });
  }
  pipeIa(u, req, res, 5);
});

app.get('/api/musik-id', async (req, res) => {
  if (Date.now() - musikIdCache.at > 6 * 60 * 60 * 1000) {
    musikIdBusy =
        musikIdBusy || refreshMusikId().finally(() => (musikIdBusy = null));
    await musikIdBusy;
  }
  res.json({ results: musikIdCache.tracks });
});

// ---- Hiburan (ubin tautan yang dikelola admin) ----

app.post('/api/hiburan', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const b = req.body || {};
  const title = String(b.title || '').trim();
  let url = String(b.url || '').trim();
  if (!title || !url) {
    return res.status(400).json({ error: 'Judul dan URL wajib diisi' });
  }
  if (!/^https?:\/\//i.test(url)) url = 'https://' + url;
  const tile = {
    id: `h_${Date.now()}`,
    title,
    emoji: String(b.emoji || '🎮').slice(0, 8),
    url,
  };
  db.hiburan.push(tile);
  save();
  res.json(tile);
});

app.delete('/api/hiburan/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const before = db.hiburan.length;
  db.hiburan = db.hiburan.filter((t) => t.id !== req.params.id);
  if (db.hiburan.length === before) {
    return res.status(404).json({ error: 'Ubin tidak ditemukan' });
  }
  save();
  res.json({ ok: true });
});

// ---- Layanan Pelanggan (chat pelanggan <-> admin) ----

function chatView(m) {
  return {
    id: m.id,
    phone: m.phone,
    name: m.name,
    fromAdmin: !!m.fromAdmin,
    adminName: m.adminName || '',
    text: m.text,
    at: m.at,
    readByCust: !!m.readByCust,
    readByAdmin: !!m.readByAdmin,
  };
}

let chatSeq = 0;
function pushChat(msg) {
  db.chats.push(msg);
  // Jaga ukuran file data: simpan maksimal 2000 pesan terakhir.
  if (db.chats.length > 2000) db.chats = db.chats.slice(-2000);
  save();
}

// Pelanggan mengirim pesan ke Layanan Pelanggan.
app.post('/api/chat', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Silakan masuk dulu' });
  const text = String((req.body || {}).text || '').trim().slice(0, 1000);
  if (!text) return res.status(400).json({ error: 'Pesan kosong' });
  const m = {
    id: `c_${Date.now()}_${chatSeq++}`,
    phone: c.phone,
    name: c.name,
    fromAdmin: false,
    adminName: '',
    text,
    at: now(),
    readByCust: true,
    readByAdmin: false,
  };
  pushChat(m);
  res.json(chatView(m));
});

// Pelanggan menandai balasan admin sudah dibaca.
// Catatan: rute ini HARUS terdaftar sebelum /api/chat/:phone.
app.post('/api/chat/read', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Sesi tidak valid' });
  db.chats.forEach((m) => {
    if (m.phone === c.phone && m.fromAdmin) m.readByCust = true;
  });
  save();
  res.json({ ok: true });
});

// Admin membalas pesan pelanggan tertentu.
app.post('/api/chat/:phone', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const phone = normPhone(req.params.phone);
  const target = custByPhone(phone);
  const text = String((req.body || {}).text || '').trim().slice(0, 1000);
  if (!text) return res.status(400).json({ error: 'Pesan kosong' });
  const m = {
    id: `c_${Date.now()}_${chatSeq++}`,
    phone,
    name: target ? target.name : phone,
    fromAdmin: true,
    adminName: a.name || 'Admin',
    text,
    at: now(),
    readByCust: false,
    readByAdmin: true,
  };
  pushChat(m);
  notify(
      phone,
      'chat',
      `Layanan Pelanggan: ${text.length > 90 ? `${text.slice(0, 90)}…` : text}`);
  res.json(chatView(m));
});

// Admin menandai pesan satu pelanggan sudah dibaca.
app.post('/api/chat/:phone/read', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const phone = normPhone(req.params.phone);
  db.chats.forEach((m) => {
    if (m.phone === phone && !m.fromAdmin) m.readByAdmin = true;
  });
  save();
  res.json({ ok: true });
});

// Hapus satu notifikasi milik pelanggan.
app.delete('/api/notifs/:id', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Sesi tidak valid' });
  const before = db.notifs.length;
  db.notifs = db.notifs.filter(
      (n) => !(n.phone === c.phone && n.id === req.params.id));
  if (db.notifs.length === before) {
    return res.status(404).json({ error: 'Notifikasi tidak ditemukan' });
  }
  save();
  res.json({ ok: true });
});

// Bersihkan semua notifikasi pelanggan.
app.delete('/api/notifs', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Sesi tidak valid' });
  db.notifs = db.notifs.filter((n) => n.phone !== c.phone);
  save();
  res.json({ ok: true });
});

// Tandai semua notifikasi pelanggan sudah dibaca.
app.post('/api/notifs/read', (req, res) => {
  const c = customer(req);
  if (!c) return res.status(401).json({ error: 'Sesi tidak valid' });
  db.notifs.forEach((n) => {
    if (n.phone === c.phone) n.read = true;
  });
  save();
  res.json({ ok: true });
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
  queueWa(order.phone,
      `Halo ${order.customerName}! Pesanan *${order.id}* berhasil ` +
      `dibuat.\n\n${waItems(order)}${waContents(order)}\n` +
      `Perkiraan total: *${waRp(waTotal(order))}*\n\n` +
      'Silakan antar cucian ke counter H2O Laundry Parakan. Lacak ' +
      'statusnya lewat aplikasi ya 💧');
  // Kabari para admin — admin tidak selalu membuka aplikasi. Tujuan:
  // No. WA tiap admin (Kelola Admin) + No. WhatsApp Info Toko, tanpa
  // duplikat.
  const alertTo = new Set();
  for (const adm of db.admins) {
    const p = String(adm.phone || '').trim();
    if (p && normPhone(p).length >= 10) alertTo.add(normPhone(p));
  }
  const tokoWa = String(db.about.wa || '').trim();
  if (tokoWa && normPhone(tokoWa).length >= 10) {
    alertTo.add(normPhone(tokoWa));
  }
  for (const to of alertTo) {
    queueWa(to,
        `🔔 *PESANAN BARU* ${order.id}\n` +
        `Dari: ${order.customerName} (+${order.phone})\n\n` +
        `${waItems(order)}${waContents(order)}\n` +
        `Perkiraan total: *${waRp(waTotal(order))}*\n\n` +
        'Buka aplikasi untuk memproses ya.');
  }
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
    if (STATUS_NOTIF[o.status]) {
      notify(normPhone(o.phone), 'order',
          `Pesanan ${o.id} ${STATUS_NOTIF[o.status]}`, { orderId: o.id });
    }
    if (WA_STATUS_MSG[o.status]) {
      queueWa(o.phone, WA_STATUS_MSG[o.status](o));
    }
    save();
  }
  res.json(o);
});

app.post('/api/orders/:id/paid', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const o = findOrder(req, res);
  if (!o) return;
  const was = o.paid;
  o.paid = !!(req.body || {}).paid;
  if (o.paid && !was) {
    notify(normPhone(o.phone), 'order',
        `Pembayaran pesanan ${o.id} tercatat. Terima kasih! 💧`,
        { orderId: o.id });
  }
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

// ---- OTP WhatsApp ----
// Kode verifikasi dikirim lewat gateway WA (Fonnte atau yang se-API).
// Tanpa WA_OTP_TOKEN, endpoint menjawab sent:false dan pendaftaran
// berjalan tanpa OTP (perilaku lama) — aman dideploy sebelum gateway siap.
const WA_OTP_TOKEN = process.env.WA_OTP_TOKEN || '';
const WA_OTP_URL = process.env.WA_OTP_URL || 'https://api.fonnte.com/send';
const otps = new Map(); // phone -> { code, exp, lastSent, tries }

function sendWa(target, message) {
  return new Promise((resolve, reject) => {
    const u = new URL(WA_OTP_URL);
    const body = JSON.stringify({ target, message });
    // http hanya untuk pengujian lokal; gateway produksi selalu https.
    const mod = u.protocol === 'http:' ? require('http') : https;
    const r = mod.request(
        {
          hostname: u.hostname,
          port: u.port || undefined,
          path: u.pathname + u.search,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body),
            Authorization: WA_OTP_TOKEN,
          },
        },
        (resp) => {
          let out = '';
          resp.on('data', (d) => (out += d));
          resp.on('end', () => {
            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              resolve(out);
            } else {
              reject(new Error(
                  `gateway ${resp.statusCode}: ${out.slice(0, 200)}`));
            }
          });
        });
    r.on('error', reject);
    r.setTimeout(15000, () => r.destroy(new Error('gateway timeout')));
    r.end(body);
  });
}

app.post('/api/otp/request', async (req, res) => {
  const np = normPhone((req.body || {}).phone);
  if (np.length < 10) {
    return res.status(400).json({ error: 'Nomor HP tidak valid' });
  }
  if (!WA_OTP_TOKEN) return res.json({ ok: true, sent: false });
  const prev = otps.get(np);
  if (prev && Date.now() - prev.lastSent < 60 * 1000) {
    return res
        .status(429)
        .json({ error: 'Tunggu 1 menit sebelum meminta kode lagi.' });
  }
  const code = String(Math.floor(100000 + Math.random() * 900000));
  otps.set(np, {
    code,
    exp: Date.now() + 5 * 60 * 1000,
    lastSent: Date.now(),
    tries: 0,
  });
  try {
    await sendWa(
        np,
        `Kode verifikasi H2O Laundry Parakan: *${code}*\n` +
            'Berlaku 5 menit. Jangan bagikan kode ini ke siapa pun.');
  } catch (e) {
    console.error('Kirim OTP WA gagal:', e.message);
    otps.delete(np);
    return res
        .status(502)
        .json({ error: 'Gagal mengirim kode WhatsApp. Coba lagi.' });
  }
  res.json({ ok: true, sent: true });
});

// Cocokkan lalu hanguskan kode (sekali pakai, maks 5 percobaan).
function consumeOtp(phone, code) {
  const o = otps.get(phone);
  if (!o) return false;
  if (Date.now() > o.exp || o.tries >= 5) {
    otps.delete(phone);
    return false;
  }
  o.tries++;
  if (o.code !== String(code)) return false;
  otps.delete(phone);
  return true;
}

// ---- Akun pelanggan ----

app.post('/api/customer/register', async (req, res) => {
  const { name, phone, pin, idToken, otp } = req.body || {};
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
  // Bukti kepemilikan nomor: kode OTP WhatsApp (utama) atau idToken
  // Firebase hasil OTP SMS (jalur lama).
  let verified = false;
  if (otp) {
    if (!consumeOtp(np, otp)) {
      return res
          .status(401)
          .json({ error: 'Kode verifikasi salah atau kedaluwarsa.' });
    }
    verified = true;
  } else if (idToken) {
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
    uid: `u_${Date.now().toString(36)}_${uidSeq++}`,
    photo: '',
    following: [],
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

// ---- Info & Promo (feed gaya Mingle: pemilik memposting, pelanggan
// menyukai dan berkomentar) ----

// Bentuk pos yang dikirim ke aplikasi: tanpa daftar nomor HP penyuka
// (privasi), plus penanda likedByMe/mine untuk pelanggan yang masuk.
function postView(p, custPhone) {
  const me = custPhone ? custByPhone(custPhone) : null;
  const author = p.authorUid ? custByUid(p.authorUid) : null;
  const counts = {};
  Object.values(p.reactions).forEach((e) => (counts[e] = (counts[e] || 0) + 1));
  const reactions = Object.entries(counts)
    .map(([emoji, count]) => ({ emoji, count }))
    .sort((a, b) => b.count - a.count);
  const total = Object.keys(p.reactions).length;
  const mine = custPhone ? (p.reactions[custPhone] || '') : '';
  return {
    id: p.id,
    authorName: p.authorName,
    caption: p.caption,
    bgStyle: p.bgStyle || '',
    byAdmin: !!p.byAdmin,
    mine: !!(custPhone && p.authorPhone === custPhone),
    authorUid: p.authorUid || '',
    authorPhoto:
        author && author.photo ? `/uploads/${author.photo}` : '',
    bookmarkedByMe: !!(me && p.bookmarks && p.bookmarks[me.uid]),
    imageUrl: p.image ? `/uploads/${p.image}` : '',
    videoUrl: p.video ? `/uploads/${p.video}` : '',
    videoThumbUrl: p.videoThumb ? `/uploads/${p.videoThumb}` : '',
    createdAt: p.createdAt,
    linkUrl: p.link ? p.link.url : '',
    linkTitle: p.link ? p.link.title : '',
    linkHost: p.link ? p.link.host : '',
    linkImage: p.link && p.link.image ? `/uploads/${p.link.image}` : '',
    reactions,
    reactionCount: total,
    myReaction: mine,
    // Kompatibilitas klien lama (masih memakai suka hati saja).
    likeCount: total,
    likedByMe: !!mine,
    comments: p.comments.map((c) => ({
      id: c.id,
      name: c.name,
      text: c.text,
      at: c.at,
      byAdmin: !!c.byAdmin,
      mine: !!(custPhone && c.phone === custPhone),
      replyTo: c.replyTo || '',
      replyToName: c.replyToName || '',
    })),
  };
}

// ---- Pratinjau tautan (og:title / og:image) ----

// Ambil isi URL http(s) dengan batas ukuran, timeout, dan maksimal 3
// pengalihan. Alamat privat ditolak (kecuali ALLOW_LOCAL_LINKS=1,
// untuk pengujian).
function fetchUrl(url, { maxBytes = 512 * 1024, redirects = 3, allowTruncate = false } = {}) {
  return new Promise((resolve, reject) => {
    let u;
    try {
      u = new URL(url);
    } catch (e) {
      return reject(new Error('URL tidak valid'));
    }
    if (!/^https?:$/.test(u.protocol)) {
      return reject(new Error('Hanya http/https'));
    }
    const h = u.hostname;
    const privat =
      /^(localhost|127\.|10\.|0\.|169\.254\.|192\.168\.)/.test(h) ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(h);
    if (privat && process.env.ALLOW_LOCAL_LINKS !== '1') {
      return reject(new Error('Alamat privat ditolak'));
    }
    const mod = u.protocol === 'https:' ? https : require('http');
    const req = mod.get(
      u,
      {
        headers: { 'user-agent': 'Mozilla/5.0 (compatible; H2OLaundry/1.0)' },
        timeout: 8000,
      },
      (r) => {
        if (r.statusCode >= 300 && r.statusCode < 400 && r.headers.location && redirects > 0) {
          r.resume();
          return resolve(fetchUrl(new URL(r.headers.location, u).href, {
            maxBytes,
            redirects: redirects - 1,
            allowTruncate,
          }));
        }
        if (r.statusCode !== 200) {
          r.resume();
          return reject(new Error('HTTP ' + r.statusCode));
        }
        const chunks = [];
        let size = 0;
        let settled = false;
        r.on('data', (d) => {
          size += d.length;
          chunks.push(d);
          if (size > maxBytes && !settled) {
            settled = true;
            req.destroy();
            // Halaman HTML raksasa (mis. Instagram): pakai bagian awal
            // saja — tag og:* ada di <head>.
            if (allowTruncate) {
              return resolve({
                buffer: Buffer.concat(chunks),
                type: r.headers['content-type'] || '',
              });
            }
            return reject(new Error('Terlalu besar'));
          }
        });
        r.on('end', () => {
          if (settled) return;
          settled = true;
          resolve({ buffer: Buffer.concat(chunks), type: r.headers['content-type'] || '' });
        });
      }
    );
    req.on('timeout', () => req.destroy(new Error('Timeout')));
    req.on('error', reject);
  });
}

function metaContent(html, patterns) {
  for (const p of patterns) {
    const m = html.match(p);
    if (m) return m[1].trim();
  }
  return '';
}

// Termasuk entitas numerik (&#1084; / &#x43c;) — judul og:title situs
// seperti Facebook sering memakainya.
const unescapeHtml = (s) =>
  s.replace(/&#x([0-9a-f]{1,6});/gi,
        (_, h) => safeCodePoint(parseInt(h, 16)))
    .replace(/&#(\d{1,7});/g, (_, d) => safeCodePoint(Number(d)))
    .replace(/&(amp|quot|apos|lt|gt|nbsp);/g, (x) =>
      ({ '&amp;': '&', '&quot;': '"', '&apos;': "'", '&lt;': '<',
        '&gt;': '>', '&nbsp;': ' ' })[x] || x);
function safeCodePoint(n) {
  try {
    return n >= 32 || n === 10 ? String.fromCodePoint(n) : ' ';
  } catch (e) {
    return ' ';
  }
}

// Ambil judul + gambar unggulan sebuah tautan. Gambar diunduh dan
// disimpan di /uploads agar tampil cepat dan bebas masalah CORS.
async function fetchLinkMeta(url) {
  const meta = { url, host: '', title: '', image: '' };
  try {
    meta.host = new URL(url).hostname.replace(/^www\./, '');
  } catch (e) {}
  try {
    const { buffer } = await fetchUrl(url, { allowTruncate: true });
    const html = buffer.toString('utf8');
    meta.title = unescapeHtml(metaContent(html, [
      /<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:title["']/i,
      /<title[^>]*>([^<]+)<\/title>/i,
    ])).slice(0, 160);
    const img = metaContent(html, [
      /<meta[^>]+property=["']og:image(?::secure_url)?["'][^>]+content=["']([^"']+)["']/i,
      /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
      /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
    ]);
    if (img) {
      const { buffer: ib, type } = await fetchUrl(
        new URL(unescapeHtml(img), url).href,
        { maxBytes: 3 * 1024 * 1024 });
      if (type.startsWith('image/')) {
        const ext = type.includes('png') ? 'png' : type.includes('webp') ? 'webp' : 'jpg';
        meta.image = `link_${Date.now()}.${ext}`;
        fs.writeFileSync(path.join(UPLOAD_DIR, meta.image), ib);
      }
    }
  } catch (e) {
    console.error('Pratinjau tautan gagal:', url, '-', e.message);
  }
  return meta;
}

function findPost(req, res) {
  const p = db.posts.find((p) => p.id === req.params.id);
  if (!p) res.status(404).json({ error: 'Promo tidak ditemukan' });
  return p;
}

app.get('/api/posts', (req, res) => {
  const c = customer(req);
  res.json({ posts: db.posts.map((p) => postView(p, c ? c.phone : null)) });
});

app.post('/api/posts', async (req, res) => {
  // Komunitas: pelanggan juga boleh memposting (foto/video/teks).
  const c = customer(req);
  const a = c ? null : admin(req);
  if (!c && !a) {
    return res.status(401).json({ error: 'Silakan masuk untuk memposting' });
  }
  const b = req.body || {};
  const caption = String(b.caption || '').trim();
  // Tautan: dari kolom khusus, atau URL pertama di teks. Tanpa
  // skema (mis. "wca.com") dianggap https.
  let linkUrl = String(b.link || '').trim() ||
      (caption.match(/https?:\/\/\S+/) || [''])[0];
  if (linkUrl && !/^https?:\/\//i.test(linkUrl)) {
    linkUrl = 'https://' + linkUrl;
  }
  if (!caption && !b.imageData && !b.videoData && !linkUrl) {
    return res.status(400).json({ error: 'Tulis sesuatu, pilih foto/video, atau isi tautan' });
  }
  let video = '';
  if (b.videoData) {
    let vb;
    try {
      vb = Buffer.from(String(b.videoData), 'base64');
    } catch (e) {
      vb = Buffer.alloc(0);
    }
    if (!vb.length || vb.length > 30 * 1024 * 1024) {
      return res.status(400).json({ error: 'Video tidak valid atau lebih dari 30 MB' });
    }
    const vext = ['webm', 'mov', 'm4v'].includes(b.videoExt) ? b.videoExt : 'mp4';
    video = `reel_${Date.now()}.${vext}`;
    fs.writeFileSync(path.join(UPLOAD_DIR, video), vb);
  }
  let videoThumb = '';
  if (video && HAS_FFMPEG) {
    try {
      videoThumb = makeThumb(video);
    } catch (e) {
      console.error('Thumbnail reel gagal:', e.message);
    }
  }
  let image = '';
  if (b.imageData) {
    let buf;
    try {
      buf = Buffer.from(String(b.imageData), 'base64');
    } catch (e) {
      buf = Buffer.alloc(0);
    }
    if (!buf.length || buf.length > 5 * 1024 * 1024) {
      return res.status(400).json({ error: 'Foto tidak valid atau lebih dari 5 MB' });
    }
    const ext = ['png', 'webp'].includes(b.imageExt) ? b.imageExt : 'jpg';
    image = `promo_${Date.now()}.${ext}`;
    fs.writeFileSync(path.join(UPLOAD_DIR, image), buf);
  }
  const post = {
    id: `post_${Date.now()}`,
    authorName: c ? c.name : (a.name || 'H2O Laundry'),
    authorPhone: c ? c.phone : '',
    authorUid: c ? c.uid : '',
    byAdmin: !c,
    caption,
    bgStyle: linkUrl ? '' : String(b.bgStyle || ''),
    image,
    video,
    videoThumb,
    link: linkUrl ? await fetchLinkMeta(linkUrl) : null,
    createdAt: now(),
    reactions: {},
    bookmarks: {},
    comments: [],
  };
  db.posts.unshift(post);
  if (post.byAdmin) {
    // Kabari semua pelanggan ada promo/info baru.
    const brief = caption ? `"${caption.slice(0, 60)}"` : 'lihat sekarang!';
    db.customers.forEach((cu) =>
        notify(cu.phone, 'promo',
            `Promo baru dari H2O Laundry: ${brief}`, { postId: post.id }));
    // Broadcast WA massal berisiko nomor kena banned — hanya bila
    // pemilik menyalakannya secara sadar lewat WA_PROMO_BROADCAST=1.
    if (process.env.WA_PROMO_BROADCAST === '1') {
      db.customers.forEach((cu) => queueWa(cu.phone,
          `📣 *Info & Promo H2O Laundry Parakan*\n\n${caption.slice(0, 500)}` +
          '\n\nSelengkapnya di aplikasi atau app.h2olaundry.com'));
    }
  }
  save();
  res.json(postView(post, c ? c.phone : null));
});

app.delete('/api/posts/:id', (req, res) => {
  const p = findPost(req, res);
  if (!p) return;
  const c = customer(req);
  const own = c && p.authorPhone === c.phone;
  if (!own && !admin(req)) {
    return res.status(401).json({ error: 'Tidak berhak menghapus pos ini' });
  }
  if (p.image) {
    try {
      fs.unlinkSync(path.join(UPLOAD_DIR, p.image));
    } catch (e) {}
  }
  if (p.video) {
    try {
      fs.unlinkSync(path.join(UPLOAD_DIR, p.video));
    } catch (e) {}
  }
  if (p.videoThumb) {
    try {
      fs.unlinkSync(path.join(UPLOAD_DIR, p.videoThumb));
    } catch (e) {}
  }
  if (p.link && p.link.image) {
    try {
      fs.unlinkSync(path.join(UPLOAD_DIR, p.link.image));
    } catch (e) {}
  }
  db.posts = db.posts.filter((x) => x.id !== p.id);
  save();
  res.json({ ok: true });
});

// Beri/ubah/hapus reaksi emoji. emoji kosong = hapus reaksi.
app.post('/api/posts/:id/react', (req, res) => {
  const c = customer(req);
  if (!c) {
    return res.status(401).json({ error: 'Silakan masuk untuk memberi reaksi' });
  }
  const p = findPost(req, res);
  if (!p) return;
  const emoji = String((req.body || {}).emoji || '');
  if (emoji && !REACTIONS.includes(emoji)) {
    return res.status(400).json({ error: 'Reaksi tidak dikenal' });
  }
  if (!emoji || p.reactions[c.phone] === emoji) {
    delete p.reactions[c.phone];
  } else {
    const first = !p.reactions[c.phone];
    p.reactions[c.phone] = emoji;
    if (first && p.authorPhone && p.authorPhone !== c.phone) {
      notify(p.authorPhone, 'react',
          `${c.name} memberi reaksi ${emoji} pada postingan Anda`,
          { postId: p.id });
    }
  }
  save();
  res.json(postView(p, c.phone));
});

// Rute lama (klien versi sebelumnya): suka = reaksi hati.
app.post('/api/posts/:id/like', (req, res) => {
  const c = customer(req);
  if (!c) {
    return res.status(401).json({ error: 'Silakan masuk untuk menyukai' });
  }
  const p = findPost(req, res);
  if (!p) return;
  if (p.reactions[c.phone]) delete p.reactions[c.phone];
  else p.reactions[c.phone] = '❤️';
  save();
  res.json(postView(p, c.phone));
});

app.post('/api/posts/:id/comments', (req, res) => {
  const text = String((req.body || {}).text || '').trim();
  if (!text || text.length > 500) {
    return res.status(400).json({ error: 'Komentar kosong atau terlalu panjang' });
  }
  const p = findPost(req, res);
  if (!p) return;
  const c = customer(req);
  const a = c ? null : admin(req);
  if (!c && !a) {
    return res.status(401).json({ error: 'Silakan masuk untuk berkomentar' });
  }
  // Balasan: replyTo menunjuk komentar induk; nama induk disimpan
  // sebagai snapshot agar tetap tampil walau induk dihapus.
  const replyTo = String((req.body || {}).replyTo || '');
  let replyToName = '';
  if (replyTo) {
    const parent = p.comments.find((x) => x.id === replyTo);
    if (!parent) {
      return res.status(400).json({ error: 'Komentar induk tidak ditemukan' });
    }
    replyToName = parent.name;
  }
  const actorPhone = c ? c.phone : '';
  const actorName = c ? c.name : (a.name || 'Admin H2O');
  p.comments.push({
    id: `c_${Date.now()}`,
    phone: actorPhone,
    name: actorName,
    text,
    at: now(),
    byAdmin: !c,
    replyTo,
    replyToName,
  });
  // Kabari yang berkepentingan (tanpa menotifikasi diri sendiri,
  // tanpa dobel bila balasan dan pos milik orang yang sama).
  const brief = text.slice(0, 60);
  const notified = new Set([actorPhone]);
  if (replyTo) {
    const parent = p.comments.find((x) => x.id === replyTo);
    if (parent && parent.phone && !notified.has(parent.phone)) {
      notified.add(parent.phone);
      notify(parent.phone, 'reply',
          `${actorName} membalas komentar Anda: "${brief}"`,
          { postId: p.id });
    }
  }
  if (p.authorPhone && !notified.has(p.authorPhone)) {
    notify(p.authorPhone, 'comment',
        `${actorName} mengomentari postingan Anda: "${brief}"`,
        { postId: p.id });
  }
  save();
  res.json(postView(p, c ? c.phone : null));
});

app.delete('/api/posts/:id/comments/:cid', (req, res) => {
  const p = findPost(req, res);
  if (!p) return;
  const idx = p.comments.findIndex((c) => c.id === req.params.cid);
  if (idx < 0) {
    return res.status(404).json({ error: 'Komentar tidak ditemukan' });
  }
  const c = customer(req);
  const own = c && p.comments[idx].phone === c.phone;
  if (!own && !admin(req)) {
    return res.status(401).json({ error: 'Tidak berhak menghapus komentar ini' });
  }
  p.comments.splice(idx, 1);
  save();
  res.json(postView(p, c ? c.phone : null));
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
  const { name, pin, phone } = req.body || {};
  if (!name || !/^[0-9]{4,6}$/.test(String(pin))) {
    return res.status(400).json({ error: 'Nama wajib; PIN 4-6 angka' });
  }
  const adminUser = {
    id: `admin_${Date.now()}`,
    name: String(name),
    pin: String(pin),
    phone: String(phone || '').trim() ? normPhone(phone) : '',
  };
  db.admins.push(adminUser);
  save();
  res.json({ id: adminUser.id, name: adminUser.name, phone: adminUser.phone });
});

app.put('/api/admins/:id', (req, res) => {
  const a = requireAdmin(req, res);
  if (!a) return;
  const target = db.admins.find((x) => x.id === req.params.id);
  if (!target) return res.status(404).json({ error: 'Admin tidak ditemukan' });
  const { name, pin, phone } = req.body || {};
  if (name) target.name = String(name);
  if (pin) {
    if (!/^[0-9]{4,6}$/.test(String(pin))) {
      return res.status(400).json({ error: 'PIN 4-6 angka' });
    }
    target.pin = String(pin);
  }
  if (phone !== undefined) {
    target.phone = String(phone).trim() ? normPhone(phone) : '';
  }
  save();
  res.json({ id: target.id, name: target.name, phone: target.phone || '' });
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
