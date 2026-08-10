# H2O Laundry Parakan 🧺

Aplikasi laundry untuk **pelanggan** dan **pemilik usaha** dalam satu aplikasi.
Dibangun dengan Flutter — satu codebase untuk **Android, iOS, dan Web**.

## Fitur

### Mode Pelanggan
- Pesan multi-item: layanan kiloan (Cuci + Setrika, Cuci Kering, Setrika Saja,
  Express) dan item satuan (Baju Atasan, Baju Bawahan, Selimut, Bed Cover,
  Cuci Sepatu, dll.)
- Pelanggan mengantar cucian langsung ke counter sesuai jadwal yang dipilih
- Estimasi harga langsung saat memesan
- Lacak status lewat linimasa (menunggu diantar → diterima → diproses →
  siap diambil → selesai)
- Riwayat pesanan dan profil tersimpan

### Mode Pemilik (tersembunyi: ketuk logo 7x di layar pembuka)
- Multi-admin: daftarkan Admin 1, Admin 2, dst. dengan PIN masing-masing;
  setelah ada admin, masuk Mode Pemilik wajib memilih admin + PIN, dan
  setiap perubahan status pesanan dicatat atas nama admin yang masuk
- Dashboard: pesanan baru, sedang diproses, siap diambil, pendapatan hari ini
- Kelola pesanan: majukan status, timbang ulang per item, tandai lunas, hapus
- Kelola katalog item (Layanan Kami): tambah, ubah nama/harga/satuan/
  deskripsi/estimasi, hapus item
- Laporan pendapatan 7 hari terakhir dan bulan berjalan

## Mode Server (multi-perangkat)

Folder `server/` berisi backend Node.js (lihat `server/README.md` untuk cara
pasang di VPS). Saat aplikasi dihubungkan ke server (build dengan
`--dart-define=API_URL=https://domain-anda.com`, atau dari Mode Pemilik →
Kelola Admin → Server), pesanan pelanggan dari HP mana pun langsung tampil
di counter, status tersinkron balik ke pelanggan, dan PIN admin diverifikasi
server. Tanpa server, aplikasi tetap berfungsi penuh dalam mode lokal.

## Menjalankan

```bash
flutter pub get

# Android (emulator/perangkat terhubung)
flutter run

# Web (Chrome)
flutter run -d chrome
```

## Build rilis

```bash
# APK Android
flutter build apk

# Web (hasil di build/web, siap dihosting statis:
# Firebase Hosting, Netlify, Vercel, GitHub Pages, dll.)
flutter build web
```

## Pengembangan selanjutnya

- Backend (mis. Firebase/Supabase) supaya pesanan pelanggan benar-benar sampai
  ke pemilik di perangkat berbeda
- Login/OTP pelanggan
- Notifikasi status (push/WhatsApp)
- Pembayaran online (QRIS, transfer)
