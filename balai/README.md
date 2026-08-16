# Balai

Aplikasi warga desa — beranda, agenda acara, dan buku warga. Dibuat untuk
dipakai **satu desa**, sekitar 100 orang.

Flutter + Firebase. Sasaran utamanya aplikasi Android; versi web ikut jalan
dari kode yang sama.

---

## Apa yang sudah bisa

| Bagian | Isi |
|---|---|
| **Beranda** | Kiriman teks + foto, suka, komentar. Kategori: Dijual, Butuh bantuan, Kehilangan, Acara, Kabar baik, Sekadar cerita. |
| **Pengumuman** | Kepala desa bisa menyematkan kiriman di puncak beranda, tampil beda supaya tidak tenggelam. |
| **Acara** | Agenda desa dengan tanggal, jam, tempat, dan tombol "Saya ikut" beserta daftar nama yang ikut. |
| **Buku warga** | Cari warga menurut nama, gang, atau keahlian. Inilah gunanya: saat pompa air mati, cari "Pompa air". |
| **Akun** | Daftar sendiri, lalu **kepala desa menyetujui** sebelum warga bisa menulis. Sebelum disetujui tetap bisa membaca. |
| **Tampilan** | Terang, gelap, atau ikut setelan HP. |

Semua tulisan di aplikasi berbahasa Indonesia.

---

## Menyiapkan Firebase

Aplikasi tidak akan jalan sebelum langkah ini selesai — Firebase yang
menyimpan warga, kiriman, dan foto.

### 1. Buat proyek

Buka [console.firebase.google.com](https://console.firebase.google.com) →
**Add project**. Beri nama, misalnya `balai-karangsari`.

> Pakai proyek Firebase **tersendiri**, jangan digabung dengan proyek
> aplikasi lain. Warga desa tidak perlu berada di database yang sama dengan
> pengguna aplikasi lain.

### 2. Nyalakan tiga layanan

Di menu kiri Firebase Console:

1. **Authentication** → Get started → **Email/Password** → aktifkan.
2. **Firestore Database** → Create database → pilih lokasi
   `asia-southeast2 (Jakarta)` → mulai dengan mode produksi.
3. **Storage** → Get started → lokasi yang sama.

### 3. Daftarkan aplikasi Android

Project settings (gerigi di kiri atas) → **Add app** → Android.

- Android package name: `id.desa.balai`
- Unduh `google-services.json`
- Taruh di `balai/android/app/google-services.json`

Berkas itu **tidak ikut** masuk git — setiap orang yang membangun aplikasi
mengunduhnya sendiri dari Console.

### 4. Pasang aturan keamanan

Ini langkah yang paling sering terlewat, dan paling penting.

- **Firestore Database → Rules** → hapus semua isinya → salin seluruh isi
  [`firestore.rules`](firestore.rules) → **Publish**
- **Storage → Rules** → sama, dari [`storage.rules`](storage.rules)

Tanpa ini, siapa pun yang punya alamat proyek Anda bisa membaca dan menghapus
seluruh isi database desa.

### 5. Angkat kepala desa

Warga pertama yang mendaftar tetap butuh persetujuan — padahal belum ada yang
bisa menyetujui. Jadi kepala desa pertama diangkat lewat tangan, sekali saja:

1. Daftar lewat aplikasi seperti warga biasa.
2. Buka **Firestore Database → users →** dokumen dengan nama Anda.
3. Ubah dua bidang ini:
   - `kepalaDesa` → `true`
   - `disetujui` → `true`
4. Tutup dan buka lagi aplikasinya.

Menu **Khusus kepala desa** akan muncul di tab Saya. Selanjutnya semua warga
baru bisa disetujui dari dalam aplikasi.

---

## Menjalankan

```bash
cd balai
flutter pub get

# Jalankan di HP yang tercolok atau emulator
flutter run

# Bangun APK untuk dibagikan lewat WhatsApp
flutter build apk --release
# hasilnya: build/app/outputs/flutter-apk/app-release.apk

# Versi web
flutter build web --release
```

APK hasil `build apk --release` bisa langsung dikirim lewat WhatsApp. Warga
perlu mengizinkan "Instal dari sumber tidak dikenal" satu kali saat memasang.

---

## Mengubah untuk desa Anda

Semua yang khas satu desa dikumpulkan di
[`lib/core/config.dart`](lib/core/config.dart) — tidak ada nama desa yang
ditulis tersebar di dalam layar:

```dart
static const String namaDesa = 'Karang Sari';
static const List<String> daftarGang = ['Gang 1', 'Gang 2', ...];
static const List<String> daftarKeahlian = ['Bidan', 'Listrik', ...];
```

Ganti isinya, bangun ulang, selesai.

---

## Susunan berkas

```
lib/
  core/       config desa, warna, pengubah waktu
  models/     Warga, Kiriman, Komentar, Acara, Kategori
  data/       penghubung ke Firebase (akun, kiriman, acara, warga, foto)
  screens/    layar: masuk, beranda, acara, buku warga, saya, admin
  widgets/    kartu kiriman, lembar komentar, foto warga, pil pilihan
firestore.rules   aturan keamanan database
storage.rules     aturan keamanan penyimpanan foto
```

---

## Biaya

Untuk desa 100 orang, paket gratis Firebase (Spark) masih longgar:
50.000 pembacaan dan 20.000 penulisan per hari, 5 GB penyimpanan foto.
Beranda yang dibuka 100 orang sepuluh kali sehari memakai sekitar 20.000
pembacaan — masih di bawah batas, dan tidak ada kartu kredit yang perlu
dipasang.

---

## Yang belum dikerjakan

Jujur, ini belum ada:

- **Notifikasi** — warga baru tahu ada pengumuman kalau membuka aplikasi.
  Perlu Firebase Cloud Messaging.
- **Pesan pribadi** antarwarga.
- **Mode luring** — kiriman tidak tersimpan kalau ditulis saat sinyal hilang.
- **Ganti nomor HP / hapus akun sendiri** dari dalam aplikasi.
