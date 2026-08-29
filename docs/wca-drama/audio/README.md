# Musik latar — dibuat sendiri, bebas klaim

Tiga cue yang disintesis khusus untuk serial ini. **Bukan rekaman piano asli** — dibangun dari sintesis dawai-pukul (partial inharmonik dengan peluruhan berbeda per harmonik, plus reverb multi-tap). Di bawah dialog dan pada volume rendah, terdengar meyakinkan. Untuk momen solo yang benar-benar telanjang, rekaman piano sungguhan tetap lebih baik.

Karena dibangun dari nol, **tidak ada hak cipta pihak ketiga**: aman dari Content ID, aman dipakai di akun lembaga, aman dipakai ulang di season berikutnya.

| File | Durasi | Isi | Dipakai di |
|------|--------|-----|-----------|
| `satu-nada.mp3` | 9 dtk | Satu nada A minor dipukul, peluruhan panjang, ruang besar | Ep 8 Klip 4 · Ep 13 Klip 4 · Ep 20 Klip 6 — semua momen "satu nada masuk setelah hening" |
| `piano-sedih.mp3` | 62 dtk | Progresi A minor lambat, 52 BPM, arpeggio jarang | Bed umum untuk episode berat. Ep 15, Ep 17, Ep 18 |
| `harapan.mp3` | 40 dtk | C–G–Am–F naik, piano + pad string yang membesar | Ep 10 Klip 5 · Ep 16 Klip 6 · Ep 11 Klip 6 — satu-satunya nada harapan |

## Cara pakai

**Volume musik maksimal 25% dari volume dialog.** Serial ini bekerja lewat keheningan; musik di sini fungsinya menandai belokan emosi, bukan mengisi ruang. Kalau musiknya terdengar jelas, sudah terlalu keras.

`satu-nada.mp3` dipakai **utuh, satu kali, tanpa loop.** Tempel tepat di frame yang dituju dan biarkan ekornya meluruh sendiri ke klip berikutnya.

`piano-sedih.mp3` dan `harapan.mp3` bisa di-loop. Titik sambung paling halus ada di ketukan bar, dan kedua file sudah punya fade-out — kalau mau loop mulus, potong 4 detik terakhirnya dulu.

Untuk memotong bagian tertentu, misalnya 12 detik dari detik ke-20:
```
ffmpeg -i piano-sedih.mp3 -ss 20 -t 12 -c copy potongan.mp3
```

## Kalau butuh yang lebih kaya

Sumber gratis dan legal untuk dipakai komersial — unduh sendiri, periksa lisensinya per lagu:

- **TikTok Commercial Music Library** — paling aman untuk akun bisnis, sudah dilisensikan khusus untuk itu, dan tidak akan kena mute
- **YouTube Audio Library** — filter "Attribution not required"
- **Pixabay Music** dan **Uppbeat** — banyak piano sedih instrumental, Uppbeat butuh kredit di caption untuk paket gratisnya
- **Free Music Archive** — perhatikan lisensi per lagu, sebagian butuh atribusi

Kata kunci yang paling cocok untuk serial ini: `sad solo piano`, `emotional piano underscore`, `sparse piano`, `melancholic ambient`.

**Jangan** ambil audio dari YouTube lewat downloader untuk dipakai di akun WCA. Pencocokan audio TikTok akan menandainya, dan kalau videonya dibisukan, episode yang mengandalkan suara akan hilang seluruhnya.
