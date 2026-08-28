# H2O Mail

Webmail ala Gmail untuk **mail.h2olaundry.com** (Stalwart), dibangun dengan
Flutter Web + JMAP API. Login pakai akun email Stalwart biasa (mis.
`yogi@h2olaundry.com`).

Fitur v0.1: daftar folder (badge unread), inbox dengan pagination, baca email
(HTML dirender di iframe sandbox / plain text), lampiran (download), tandai
belum dibaca, hapus (pindah ke Trash), tulis & balas email (plain text, dikirim
via EmailSubmission dan tersimpan di Sent). Layout responsif: 3 panel di layar
lebar, drawer + halaman penuh di HP.

## WAJIB sekali saja: izinkan CORS di Stalwart

Flutter web berjalan di origin berbeda dari server mail, jadi Stalwart harus
mengizinkan CORS. Di admin UI (`https://mail.h2olaundry.com/admin`):

1. Tekan `Ctrl+K` (kotak pencarian settings), cari **CORS**.
2. Aktifkan **Permissive CORS** (atau isi allowed origins dengan URL tempat app
   ini di-host, plus `http://localhost:*` untuk development).
3. Restart Stalwart: `systemctl restart stalwart`.

Tanpa ini, login akan gagal dengan error koneksi/CORS.

## Development (di laptop)

```powershell
cd h2omail
flutter pub get
flutter run -d chrome
```

## Build & deploy (host di server Webuzo / subdomain sendiri)

```powershell
flutter build web --release
```

Upload isi `build/web/` ke subdomain mana pun (mis. `webmail.h2olaundry.com`
di server Webuzo, atau Cloudflare Pages). App ini murni file statis — tidak
butuh backend sendiri; semua data langsung dari JMAP `mail.h2olaundry.com`.

## Build APLIKASI ANDROID (untuk HP sendiri)

Login tersimpan di perangkat ("Ingat saya", default aktif) — buka app langsung
masuk inbox, seperti app Gmail.

Satu kali saja, generate folder android/ (tidak menyentuh lib/):

```powershell
cd h2omail
flutter create --platforms=android .
flutter pub get
```

Lalu tambahkan izin internet untuk build release: buka
`android/app/src/main/AndroidManifest.xml` dan tambahkan baris ini tepat di
atas `<application`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Jalankan ke HP (USB debugging aktif):

```powershell
flutter run -d <deviceId>
```

APK permanen untuk dipasang di HP:

```powershell
flutter build apk --release
```

Hasil: `build\app\outputs\flutter-apk\app-release.apk` — kirim ke HP dan
install. Catatan: kredensial disimpan polos di SharedPreferences perangkat —
wajar untuk perangkat pribadi, jangan dipakai di HP orang lain.

## Arsitektur

- `lib/jmap/jmap_client.dart` — klien JMAP (session, Mailbox/get, Email/query,
  Email/get, Email/set, EmailSubmission/set, Identity/get). Basic auth via
  HTTPS; kredensial hanya disimpan di memori (tidak ada localStorage).
- `lib/screens/` — login, home (3-panel responsif), pembaca pesan, compose.
- `lib/widgets/html_view.dart` — render HTML email dalam iframe `sandbox`
  (script diblokir) via `dart:ui_web` platform view. **Web-only**; untuk build
  Android/iOS nanti perlu pengganti berbasis WebView.

## Roadmap

- Push/refresh otomatis (JMAP EventSource / polling `Email/changes`).
- Kirim lampiran (blob upload) & HTML compose.
- Multi-akun + "remember me" (simpan kredensial terenkripsi).
- Versi Android/iOS (ganti html_view dengan webview_flutter).
