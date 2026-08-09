# LaundryKu 🧺

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
- Dashboard: pesanan baru, sedang diproses, siap diambil, pendapatan hari ini
- Kelola pesanan: majukan status, timbang ulang per item, tandai lunas, hapus
- Kelola katalog item: tambah, ubah harga/satuan, hapus item
- Laporan pendapatan 7 hari terakhir dan bulan berjalan

Data disimpan lokal di perangkat (`shared_preferences`), jadi aplikasi berfungsi
penuh tanpa backend — cocok sebagai MVP/demo. Mode pelanggan dan pemilik membaca
data yang sama, sehingga alurnya bisa dicoba end-to-end di satu perangkat.

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
