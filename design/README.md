# design/

Standalone front-end assets. Nothing here is part of the Flutter app —
these files are not compiled, imported, or shipped by `flutter build`.

## wca-globe-hero.html

Hero section for **worldcruiseacademy.co.id** (WordPress + Elementor):
an interactive globe with great-circle routes from Yogyakarta to the
cruise ports where graduates are placed.

Self-contained: no libraries, no CDN, no build step. Canvas 2D only.
The world map is a 1-degree land bitmask (10.8 KB base64) rasterised from
Natural Earth 110m, so continents render as dots without shipping GeoJSON.

### Memasang di Elementor

1. Edit halaman depan, hapus/sembunyikan section hero yang lama.
2. Tambah **Section** baru paling atas.
   Layout → Content Width: **Full Width**, Columns Gap: **No Gap**,
   Padding: **0** (atas, bawah, kiri, kanan).
3. Ke dalam section itu, tarik widget **HTML**.
4. Salin **seluruh isi** `wca-globe-hero.html` ke widget tersebut, lalu Update.

### Yang perlu diedit

Cari komentar `EDIT` di dalam file:

| Bagian | Isi sekarang |
|---|---|
| `<h1>` | "Dari Jogja, kariermu berlayar ke seluruh dunia" |
| `.wca-sub` | deskripsi program |
| tombol | `/daftar-online/` dan `/syarat-dan-biaya-pendidikan/` |
| `.wca-stats` | **500+ / 40+ / 6 — angka placeholder, ganti dengan data resmi WCA** |
| `.wca-partners` | nama cruise line mitra |

Pelabuhan dan rute ada di array `PORTS`, `TRUNK`, dan `FEEDER` di dalam
`<script>`. Format `PORTS`: `['Nama', lintang, bujur, tampilkanLabel]`.

### Catatan teknis

- Semua CSS di-scope ke `#wca-hero`, jadi tidak bentrok dengan tema.
- Animasi berhenti saat section keluar layar (IntersectionObserver).
- `prefers-reduced-motion` mematikan rotasi dan pulsa.
- Canvas menyesuaikan devicePixelRatio (dibatasi 2x).
- Bisa diputar dengan drag; scroll vertikal di HP tetap normal.
