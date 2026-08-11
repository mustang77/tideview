// Gateway WhatsApp mandiri H2O Laundry — pengganti Fonnte, jalan di
// VPS sendiri. Berbasis Baileys (protokol WhatsApp Web, tidak resmi;
// pakai nomor cadangan bila khawatir, bukan nomor utama usaha).
//
// API kompatibel Fonnte sehingga server utama tidak berubah:
//   POST /send  {target, message}  + header Authorization: <token>
//   GET  /status                   -> {connected, user}
//
// Menjalankan pertama kali (pairing, cukup sekali):
//   cd wagateway && npm install
//   WA_GW_TOKEN=tokenrahasia WA_PAIR_NUMBER=62812xxxxxxx node index.js
//   -> muncul "KODE PAIRING: XXXX-XXXX"; di HP nomor pengirim buka
//      WhatsApp > Perangkat Tertaut > Tautkan dengan nomor telepon,
//      masukkan kode itu. Sesi tersimpan di folder session/.
//   (Tanpa WA_PAIR_NUMBER, kode QR digambar di terminal untuk discan.)
//
// Produksi: jalankan sebagai service systemd (lihat h2o-wa.service.example)
// lalu di service utama set:
//   WA_OTP_TOKEN=tokenrahasia
//   WA_OTP_URL=http://127.0.0.1:8477/send

const http = require('http');
const path = require('path');
const pino = require('pino');
const {
  default: makeWASocket,
  useMultiFileAuthState,
  fetchLatestBaileysVersion,
  DisconnectReason,
} = require('@whiskeysockets/baileys');

const PORT = Number(process.env.PORT || 8477);
const TOKEN = process.env.WA_GW_TOKEN || '';
const PAIR_NUMBER = String(process.env.WA_PAIR_NUMBER || '')
    .replace(/[^0-9]/g, '');
const SESSION_DIR = path.join(__dirname, 'session');

if (!TOKEN) {
  console.error('WA_GW_TOKEN wajib diisi (token rahasia buatan sendiri).');
  process.exit(1);
}

const log = pino({ level: 'warn' });
let sock = null;
let connected = false;
let meId = '';
let pairingShown = false;
let starting = false;

async function start() {
  if (starting) return;
  starting = true;
  try {
    const { state, saveCreds } = await useMultiFileAuthState(SESSION_DIR);
    let version;
    try {
      ({ version } = await fetchLatestBaileysVersion());
    } catch (e) {
      version = undefined; // pakai versi bawaan library
    }
    sock = makeWASocket({
      version,
      auth: state,
      logger: log,
      printQRInTerminal: false,
      markOnlineOnConnect: false,
      syncFullHistory: false,
    });
    sock.ev.on('creds.update', saveCreds);
    sock.ev.on('connection.update', async (u) => {
      if (u.qr && !state.creds.registered) {
        if (PAIR_NUMBER) {
          // Kode pairing cukup diminta sekali per koneksi.
          if (!pairingShown) {
            pairingShown = true;
            try {
              const code = await sock.requestPairingCode(PAIR_NUMBER);
              console.log('==========================================');
              console.log('KODE PAIRING WHATSAPP:', code);
              console.log('HP nomor pengirim: WhatsApp > Perangkat');
              console.log('Tertaut > Tautkan dengan nomor telepon.');
              console.log('==========================================');
            } catch (e) {
              console.error('Gagal minta kode pairing:', e.message);
            }
          }
        } else {
          // QR kedaluwarsa ±30 dtk; gambar ulang setiap QR baru.
          try {
            require('qrcode-terminal').generate(u.qr, { small: true });
            console.log('Scan QR di atas: WhatsApp > Perangkat Tertaut >'
                + ' Tautkan Perangkat. (QR diperbarui otomatis)');
          } catch (e) {
            console.log('QR string:', u.qr);
          }
        }
      }
      if (u.connection === 'open') {
        connected = true;
        meId = sock.user && sock.user.id ? sock.user.id : '';
        console.log('WhatsApp terhubung sebagai', meId);
      }
      if (u.connection === 'close') {
        connected = false;
        const code = u.lastDisconnect && u.lastDisconnect.error &&
                u.lastDisconnect.error.output
            ? u.lastDisconnect.error.output.statusCode
            : 0;
        if (code === DisconnectReason.loggedOut) {
          console.error('Sesi WhatsApp logout. Hapus folder session/ '
              + 'lalu jalankan ulang untuk pairing baru.');
        } else {
          console.log('Koneksi WA terputus (kode ' + code
              + '), sambung ulang 5 detik lagi...');
          pairingShown = false;
          setTimeout(() => {
            starting = false;
            start();
          }, 5000);
          return;
        }
      }
    });
  } catch (e) {
    console.error('Gagal memulai koneksi WA:', e.message);
    setTimeout(() => {
      starting = false;
      start();
    }, 10000);
  }
}

start();

// ---- HTTP API (kompatibel Fonnte) ----

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.method === 'GET' && req.url === '/status') {
    return res.end(JSON.stringify({ connected, user: meId }));
  }
  if (req.method !== 'POST' || !req.url.startsWith('/send')) {
    res.statusCode = 404;
    return res.end('{"error":"tidak ditemukan"}');
  }
  const auth = req.headers.authorization || '';
  if (auth !== TOKEN && auth !== `Bearer ${TOKEN}`) {
    res.statusCode = 401;
    return res.end('{"error":"token salah"}');
  }
  let body = '';
  req.on('data', (d) => {
    body += d;
    if (body.length > 64 * 1024) req.destroy();
  });
  req.on('end', async () => {
    let b = {};
    try {
      b = JSON.parse(body || '{}');
    } catch (e) {}
    const target = String(b.target || '').replace(/[^0-9]/g, '');
    const message = String(b.message || '').slice(0, 4000);
    if (!target || !message) {
      res.statusCode = 400;
      return res.end('{"error":"target dan message wajib diisi"}');
    }
    if (!connected || !sock) {
      res.statusCode = 503;
      return res.end(
          '{"error":"WhatsApp belum terhubung (cek /status atau pairing)"}');
    }
    try {
      await sock.sendMessage(`${target}@s.whatsapp.net`, { text: message });
      res.end('{"status":true}');
    } catch (e) {
      console.error('Gagal kirim ke', target, '-', e.message);
      res.statusCode = 502;
      res.end('{"error":"gagal mengirim pesan"}');
    }
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Gateway WA siap di http://127.0.0.1:${PORT}`
      + ' (hanya lokal, tidak terbuka ke internet).');
});
