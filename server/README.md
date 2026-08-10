# Server H2O Laundry Parakan

API backend untuk aplikasi H2O Laundry. Data tersimpan di satu file
`data.json` (tanpa database terpisah) — cukup untuk satu gerai laundry.

## Kebutuhan

- VPS Ubuntu/Linux dengan **Node.js 18+**
- Domain dengan HTTPS (nginx + certbot, atau setara)

## Pasang di VPS

```bash
# 1. Node.js 20 (kalau belum ada)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Salin folder server/ ke VPS, lalu:
cd /opt/h2o-laundry-server     # atau lokasi pilihan Anda
npm install
PORT=8080 node index.js        # uji jalan dulu
curl http://localhost:8080/api/health
```

## Jalankan otomatis (systemd)

Buat `/etc/systemd/system/h2o-laundry.service`:

```ini
[Unit]
Description=H2O Laundry API
After=network.target

[Service]
WorkingDirectory=/opt/h2o-laundry-server
ExecStart=/usr/bin/node index.js
Environment=PORT=8080
Environment=DATA_FILE=/opt/h2o-laundry-server/data.json
Restart=always
User=www-data

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now h2o-laundry
sudo systemctl status h2o-laundry
```

## Verifikasi OTP nomor HP (Firebase)

Pendaftaran dari aplikasi Android menyertakan `idToken` Firebase hasil
OTP SMS; server memverifikasi tanda tangan token dan mencocokkan nomor
HP-nya. Variabel lingkungan terkait:

- `FIREBASE_PROJECT_ID` — ID proyek Firebase (default `wca-mobile-10a8d`).
- `REQUIRE_OTP=1` — tolak pendaftaran tanpa OTP. Biarkan mati selama
  versi web belum punya alur OTP (web mendaftar tanpa token).

## Sambungkan ke domain HTTPS (nginx)

Tambahkan di blok `server { ... }` domain Anda (yang sudah ber-SSL):

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
curl https://domain-anda.com/api/health
```

## Hubungkan aplikasi

Dua cara (bisa dua-duanya):

1. **Tanam saat build** (semua pemasangan baru langsung terhubung):
   ```bash
   flutter build apk --dart-define=API_URL=https://domain-anda.com
   ```
2. **Atur dari aplikasi**: Mode Pemilik → Kelola Admin → kartu
   **Server** → isi `https://domain-anda.com` → Uji & Simpan.

Setelah terhubung, buat admin pertama lewat Kelola Admin — begitu ada
admin, semua operasi pemilik di server terkunci PIN.

## Backup

Semua data ada di satu file `data.json`. Backup cukup:

```bash
cp /opt/h2o-laundry-server/data.json ~/backup-$(date +%F).json
```
