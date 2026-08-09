# LaundryKu 🧺

Aplikasi laundry untuk **pelanggan** dan **pemilik usaha** dalam satu aplikasi.
Dibangun dengan Flutter — satu codebase untuk **Android, iOS, dan Web**.

## Fitur

### Mode Pelanggan
- Pilih layanan: Cuci + Setrika, Cuci Kering, Setrika Saja, Express 1 Hari, Bed Cover, Cuci Sepatu
- Buat pesanan dengan perkiraan berat, jadwal penjemputan, dan antar jemput
- Estimasi harga langsung saat memesan
- Lacak status pesanan lewat linimasa (menunggu → dijemput → diproses → siap → selesai)
- Riwayat pesanan dan profil tersimpan

### Mode Pemilik
- Dashboard: pesanan baru, sedang diproses, siap diantar, pendapatan hari ini
- Kelola pesanan: majukan status, timbang ulang berat aktual, tandai lunas, hapus
- Atur harga tiap layanan
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
