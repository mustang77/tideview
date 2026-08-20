# Season 1 — "Dari Kampung ke Kapal"

Arsip paket produksi micro drama WCA. Delapan episode, vertikal 9:16, ±32 detik per episode (Ep 4 ±40 detik).

| File | Episode | Klip | Aset yang dipakai |
|------|---------|------|-------------------|
| `00-season-package.md` | Setup + arc season + **Ep 1 "Ditertawakan"** | 4 | `bima.png`, `bapak.png` |
| `ep02-jual-motor.md` | Ep 2 "Jual Motor" | 3 | `bima.png` |
| `ep03-hari-pertama.md` | Ep 3 "Hari Pertama" | 3 AI + 1 REAL | `bima.png`, `instruktur.png` |
| `ep04-tidak-bisa-inggris.md` | Ep 4 "Tidak Bisa Bahasa Inggris" | 5 | `bima.png`, `rendi.png` |
| `ep05-interview-gagal.md` | Ep 5 "Interview Gagal" | 4 | `bima.png`, `recruiter.png` |
| `ep06-mau-menyerah.md` | Ep 6 "Mau Menyerah" | 4 | `bima.png` (+ suara ibu) |
| `ep07-kesempatan-kedua.md` | Ep 7 "Kesempatan Kedua" | 4 | `bima.png`, `recruiter.png` |
| `ep08-final-genoa.md` | Ep 8 FINAL "Telepon dari Genoa" | 4 + CTA | `bima.png`, `bapak.png` |

Total: 32 klip AI + 1 klip footage asli + 1 kartu CTA.

## Aset karakter

Lima gambar, generate sekali, pakai seluruh season. Prompt `bima.png` dan `bapak.png` ada di `00-season-package.md`; `instruktur.png`, `rendi.png`, dan `recruiter.png` ada di character sheet episode masing-masing.

`bima.png` dipakai di kedelapan episode dengan tiga kostum berbeda — kaos lusuh (Ep 1, 2, 4, 6), kemeja putih + dasi (Ep 5, 7), seragam kru (Ep 8). **Wajah tetap satu aset, yang berubah hanya kostum**, dan kostumnya disebut ulang di setiap prompt.

## Kurva emosi season

```
Ep 1  ▼  ditolak
Ep 2  ▼  kehilangan
Ep 3  ▼  dipermalukan
Ep 4  ▲  kemenangan kecil — satu kalimat Inggris utuh
Ep 5  ▼▼ "Not yet."          ← jatuh paling dalam justru setelah menang
Ep 6  ▼▲ nadir, lalu bangkit
Ep 7  ▲  siap, jabat tangan  ← layar gelap
Ep 8  ▲▲ payoff + CTA
```

## Revisi yang sudah diterapkan pada arsip ini

Enam perbaikan, semuanya perubahan teks (gratis — tidak ada klip yang perlu diregenerate kecuali sudah terlanjur dibuat):

1. **Ep 4 berakhir naik.** Sebelumnya Ep 4, 5, dan 6 sama-sama diberi label titik terendah, jadi kurva season datar di tengah dan "Not yet" di Ep 5 kehilangan daya hancurnya. Ditambahkan Klip 5: Bima di depan cermin mengucapkan kalimat Inggris utuh pertamanya. Baris arc di `00-season-package.md` ikut disesuaikan.
2. **Ep 4 — teks "04:00" dikeluarkan dari prompt.** Teks dalam frame hampir selalu berantakan di Veo. Prompt sekarang cuma "layar HP menyala terang di kegelapan"; angkanya ditempel di editor.
3. **Ep 2 — "segepok uang" diganti amplop coklat.** Tangan yang memegang uang tunai adalah salah satu adegan paling sering rusak di Veo (jari bertambah, lembaran meleleh). Amplop menyampaikan hal yang sama tanpa risiko itu.
4. **Ep 6 — aksi ganda di Klip 4 disederhanakan.** "Menutup koper... lalu MEMBUKANYA lagi" adalah dua aksi berlawanan dalam 8 detik; Veo akan mengacaukannya. Sekarang satu aksi: mengeluarkan buku dari koper dan mendekapnya.
5. **Ep 7 — layar gelap dipindah ke editor.** Veo tidak bisa diandalkan memotong ke hitam di frame yang tepat. Klip digenerate penuh 8 detik, pemotongan dilakukan manual.
6. **Ep 8 — timeline diperbaiki.** VO Ep 8 berbunyi "Tiga tahun lalu" sementara Ep 7 menyebut "Tiga bulan tidak sia-sia", dan Bima tetap 18 tahun di character sheet. Diganti jadi "Dulu" — bentrokannya hilang tanpa mengubah apapun yang lain.

## Distribusi

Post satu episode per hari. Kumpulkan di playlist TikTok "Dari Kampung ke Kapal". CTA hanya ada di Ep 8 — jangan menambahkan CTA di episode lain.
