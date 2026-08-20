---
name: flow-micro-drama
description: Hasilkan paket produksi micro drama vertikal bersambung untuk Google Flow (Veo) — series 6–10 episode untuk TikTok, Reels, dan Shorts. Cukup berikan premis cerita, brand, atau tokoh utamanya, skill ini menghasilkan semua yang dibutuhkan untuk menjalankan satu season penuh — character sheet dan prompt gambar tokoh yang konsisten, arc season dengan cliffhanger di setiap episode, prompt per klip siap tempel (Metode B / Ingredients-to-Video), briefing Agent mode sebagai cadangan, skrip voiceover ElevenLabs per karakter, instruksi transisi dan musik untuk editor, dan caption TikTok. Gunakan kapanpun user ingin membuat micro drama, drama pendek vertikal, sinetron TikTok, cerita bersambung, atau konten storytelling brand berbentuk series — juga pada frasa seperti "micro drama", "drama pendek", "drama vertikal", "series TikTok", "cerita bersambung", "Flow drama", "BERSAMBUNG", atau ketika user membawa paket produksi drama yang sudah ada dan ingin melanjutkan, menulis ulang, atau melengkapi episodenya.
---

# Google Flow Micro Drama Generator

Menghasilkan paket produksi lengkap untuk micro drama vertikal bersambung di Google Flow. Satu premis cerita menghasilkan semua yang dibutuhkan user untuk menjalankan satu season penuh — character sheet, arc season, prompt per klip, skrip voiceover, dan instruksi finishing.

Skill ini adalah saudara dari `flow-ugc-ads`. Bedanya: UGC ad menjual dalam 40 detik lewat satu kreator yang bicara ke kamera. Micro drama menjual lewat **cerita bersambung** — penonton kembali karena penasaran, bukan karena tertarik produk. CTA hanya muncul sekali, di episode terakhir.

## Apa yang dilakukan skill ini

1. Mengambil premis cerita, brand/tujuan, dan bahasa dari user
2. Opsional membaca `brand/brand-dna.md`, `brand/brand-voice.md`, `brand/icp-cards.md` jika ada — dilewati diam-diam jika tidak ada
3. Merancang arc season 6–10 episode beserta kurva emosinya
4. Menghasilkan prompt gambar karakter untuk tokoh inti yang dipakai ulang sepanjang season
5. Menulis prompt per klip dengan Metode B (1 klip = 1 scene, reference image di setiap klip)
6. Menyediakan briefing Agent mode sebagai jalur cadangan
7. Menulis skrip voiceover ElevenLabs dengan catatan suara per karakter
8. Memberi instruksi transisi, musik, caption, dan distribusi

Skill ini TIDAK memanggil API apapun dan TIDAK menghasilkan video. Skill ini menghasilkan paket produksi. User menjalankan generate aktual di UI browser Flow.

## Sebelum memulai

User membutuhkan:
- Langganan Google AI Pro di labs.google.com/flow
- Tool generate gambar untuk karakter: ChatGPT Images, Nano Banana Pro, atau Gemini
- Editor video untuk merangkai klip — CapCut, atau editor milik user sendiri
- Opsional: akun ElevenLabs kalau mau dub ulang suara

Tidak perlu API key. Tidak perlu kode. Tidak perlu terminal.

## Aturan kredit — WAJIB disampaikan di awal

Satu episode = 3–5 klip × 8 detik. Satu season 8 episode ≈ 32 klip. Itu mahal.

**Jangan pernah generate satu season sekaligus.** Alur yang benar:

1. Generate gambar karakter (sekali saja, dipakai seluruh season)
2. Produksi **Episode 1 saja**
3. User lihat hasilnya, approve gaya + suara + wajah karakter
4. Baru tulis briefing lengkap episode berikutnya

Sampaikan ini di awal, bukan di akhir. Mengubah teks dialogue itu gratis; regenerate klip menghabiskan kredit.

---

## Alur Kerja

### Langkah 1 — Pengumpulan Data

Kumpulkan dari user:

1. **Premis cerita** — satu kalimat: siapa tokohnya, apa yang dia inginkan, apa yang menghalangi (wajib)
2. **Tujuan** — hiburan murni, atau funnel untuk brand/lembaga tertentu? Kalau brand: nama brand, layanan, dan kontak untuk CTA episode terakhir
3. **Bahasa + logat** — bahasa Indonesia, logat daerah, atau bahasa lain. Default: bahasa Indonesia natural
4. **Latar** — kampung, kota, kampus, kantor, pesantren, perantauan, dll. Sespesifik mungkin
5. **Jumlah episode** — default 8. Range sehat 6–10
6. **Genre/arc** — pilih satu preset atau tanya (lihat `references/arcs.md`):
   - `underdog` — orang kecil mengejar mimpi besar yang ditertawakan (default)
   - `pengorbanan-keluarga` — tokoh mengorbankan sesuatu demi keluarga
   - `glow-up` — tokoh diremehkan, kembali sebagai orang yang berbeda
   - `perantauan` — meninggalkan kampung, bertahan di tempat asing
   - `founder-origin` — asal-usul brand/usaha dari titik terendah

Jangan tanya semuanya sekaligus. **Premis + latar sudah cukup untuk mulai.** Tanya sisanya secara natural.

Kalau user datang membawa paket produksi yang sudah ada, jangan tulis ulang dari nol — baca, pertahankan nama karakter, dialogue, dan gaya yang sudah ada, lalu lanjutkan dari episode yang belum lengkap.

### Langkah 2 — Cek Konteks Brand

Cari `brand/brand-dna.md`, `brand/brand-voice.md`, `brand/icp-cards.md`. Jika ada, baca diam-diam dan gunakan untuk menajamkan CTA episode terakhir serta memastikan konflik cerita mencerminkan masalah nyata ICP. Jangan sebut ini ke user. Jika tidak ada, lanjutkan.

### Langkah 3 — Rancang Arc Season dan Kurva Emosinya

Buat tabel arc sebelum menulis satu shot pun:

```
| Ep | Judul | Isi episode | Cliffhanger penutup |
```

**Aturan arc:**
- Setiap episode berakhir dengan **cliffhanger** — pertanyaan terbuka, pintu tertutup, kalimat yang menyakitkan, atau layar gelap sebelum jawaban. Tanpa pengecualian sampai episode terakhir.
- Episode 1 memperkenalkan **mimpi + penolakan** dalam 32 detik. Bukan latar belakang, bukan narasi. Langsung konflik.
- Kemenangan besar hanya di episode terakhir.
- **CTA hanya sekali, di episode terakhir.**

**Lalu gambar kurva emosinya dan periksa.** Ini langkah yang paling sering dilewatkan, dan kesalahannya paling mahal:

```
Ep 1  ▼  ditolak
Ep 2  ▼  kehilangan
Ep 3  ▼  dipermalukan
Ep 4  ▲  kemenangan kecil        ← WAJIB ADA
Ep 5  ▼▼ kegagalan resmi          ← jatuh paling dalam justru setelah menang
Ep 6  ▼▲ nadir, lalu bangkit
Ep 7  ▲  siap — layar gelap
Ep 8  ▲▲ payoff + CTA
```

**Jebakan paling umum: tiga episode berturut-turut sama-sama muram.** Kalau penonton sudah merasa tokohnya di dasar sejak Ep 4, kegagalan di Ep 5 tidak terasa apa-apa, dan penonton lelah sebelum sampai nadir. Selalu sisipkan **satu kemenangan kecil sebelum kegagalan terbesar** — bukan kemenangan yang menyelesaikan masalah, hanya bukti bahwa tokohnya mulai bisa. Kalimat asing pertama yang utuh. Pujian pertama. Satu pelanggan.

Periksa juga: **tidak boleh ada dua episode dengan beat penutup yang sama.** Dua episode yang sama-sama ditutup "tekad menyala kembali" akan terasa mengulang, apalagi kalau baris voiceover-nya juga mirip.

Tunjukkan tabel arc ke user dan **minta approval sebelum lanjut**. Mengubah arc di tahap ini gratis.

### Langkah 4 — Generate Prompt Gambar Karakter

Hasilkan prompt gambar untuk tokoh yang muncul di lebih dari satu episode. Tokoh sekali pakai (pembeli motor, kasir, penumpang) tidak perlu aset.

Ikuti formula ini persis:

```
Foto iPhone candid seorang [gender] Indonesia berusia [usia] tahun, [detail fisik spesifik — warna kulit, tekstur rambut, kerutan, kumis, bekas luka], tanpa makeup, mengenakan [pakaian spesifik dan realistis — sebutkan kondisinya: lusuh, pudar, sering dicuci], [lingkungan spesifik]. Diambil dari [sudut — sedikit rendah dan off-center / sedikit di atas level mata]. [Pencahayaan spesifik]. Eksposur sedikit tidak sempurna. Tekstur kulit nyata, tidak diretuh. Bukan model, wajah orang biasa. Realisme gaya editorial.
```

**Aturan:**
- Jangan pernah gunakan "cantik", "tampan", "memukau", atau deskriptor model
- Selalu sebutkan **kondisi pakaian** — di drama, pakaian menceritakan status ekonomi tokoh
- Selalu sertakan lingkungan spesifik dan minimal satu ketidaksempurnaan
- Selalu sertakan "Foto iPhone candid"
- Beri **penanda wajah yang saling berbeda tajam** antar tokoh supaya Flow tidak menukar wajah

Lihat `references/characters.md` untuk template arketipe tokoh drama.

Beritahu user: simpan dengan nama file deskriptif dan mudah diketik — `bima.png`, `bapak.png`, `recruiter.png` — lalu unggah ke proyek Flow.

### Langkah 5 — Tulis Character Sheet per Episode

Setiap file episode dibuka dengan character sheet — satu baris per tokoh, **disalin ulang ke dalam setiap prompt klip**. Flow tidak mengingat apapun antar klip; pengulangan inilah yang menjaga konsistensi.

```
bima.png = laki-laki Indonesia 18 tahun, kulit sawo matang, rambut hitam pendek berantakan, kaos oblong abu-abu lusuh
```

**Protokol ganti kostum.** Kalau tokoh berganti pakaian di suatu episode (kaos lusuh → kemeja dan dasi → seragam kerja), **jangan generate wajah baru.** Pakai aset yang sama, lalu tulis peringatan eksplisit di character sheet episode itu:

```
bima.png = ... — TAPI di episode ini memakai kemeja putih + dasi hitam, rambut disisir rapi
⚠️ Wajah tetap bima.png, HANYA kostum yang berubah. Sebutkan kostumnya di setiap prompt klip.
```

Ini juga cara menunjukkan perubahan karakter secara visual: kostum dan postur, tidak pernah wajah.

### Langkah 6 — Tulis Prompt Klip (Metode B — jalur utama)

**Metode B: 1 klip = 1 scene, dengan reference image di setiap klip** (Ingredients-to-Video). Ini metode yang paling konsisten dan harus jadi format utama yang kamu tulis.

Untuk setiap klip:

```
**KLIP N — Ingredient: `[aset].png`** — [fungsi klip dalam satu kata]
```
[aset].png [kostum sesuai character sheet] [aksi TUNGGAL] di [lingkungan lengkap + waktu hari]. [Ekspresi]. Berbicara [cara bicara]: "[dialogue]." [Pencahayaan spesifik], handheld, candid, tekstur kulit natural, sinematik [tone]. 9:16, 8 detik.
```
```

**Modifier gaya wajib di setiap klip:**
- `handheld` (atau `gerakan kamera perlahan handheld`)
- `candid`
- `tekstur kulit natural`
- pencahayaan spesifik sesuai waktu hari
- satu penanda tone: `sinematik muram` / `sinematik penuh harapan` / `sinematik canggung` / `mengharukan`

**Aturan klip yang tidak boleh dilanggar:**

1. **Satu aksi per klip.** Delapan detik hanya muat satu aksi. "Ia menutup koper lalu membukanya lagi dan mengeluarkan buku" adalah tiga aksi berlawanan — Flow akan mengacaukannya. Pilih satu.
2. **Maksimal 2 aset bertag per klip.** Tiga atau lebih dan wajah mulai tertukar.
3. **Satu episode, satu arah waktu.** Malam → subuh boleh (maju). Senja → pagi → senja tidak.
4. **Dialogue maksimal ~20 kata per klip** (±3 kata per detik). Di drama, lebih pendek lebih kuat. Satu klip = satu kalimat penting, sisanya diam.
5. **Kalimat paling menyakitkan diucapkan datar dan pelan**, bukan diteriakkan.
6. **Jangan pernah minta efek editing lewat prompt** — layar gelap, split screen, potongan cepat, teks di layar. Semua itu dikerjakan di editor. Lihat daftar di bawah.

**Jumlah klip fleksibel: 3–5 per episode.** Tiga klip untuk episode sederhana yang bergerak cepat, empat untuk standar, lima hanya untuk episode yang benar-benar memikul beban struktural. Kalau menaikkan jumlah klip, katakan biayanya ke user secara eksplisit dan jelaskan kenapa episode itu layak dapat klip tambahan.

**Menyisipkan footage asli.** Kalau user punya footage nyata yang relevan (lokasi asli, tempat usaha, kampus), selipkan satu klip asli di antara klip AI dengan urutan **AI → REAL → AI**. Mata penonton menganggap semuanya nyata karena ada satu yang benar-benar nyata. Ini juga promo halus yang tidak terasa seperti iklan.

### Langkah 7 — Briefing Agent Mode (jalur cadangan)

Sediakan juga satu blok Agent mode per episode — berguna kalau user mau mencoba generate seluruh episode sekaligus. Tapi **Metode B tetap jalur utama**; Agent mode masih eksperimental dan sering tidak menjalankan semua shot.

```
Episode drama pendek vertikal bahasa [bahasa]. Konsisten dengan gambar: [aset1].png ([deskripsi singkat]), [aset2].png ([deskripsi singkat]).

Shot 1: [lingkungan + waktu]. [aset1].png [kostum] [aksi tunggal]. Berbicara [cara]: "[dialogue]." [pencahayaan], handheld, candid, [tone]. 9:16, 8 detik.

Shot 2: ...

Jaga konsistensi wajah dan pakaian [aset].png di semua shot. Semua dialog dalam [bahasa dan logat]. Vertikal 9:16.
```

### Langkah 8 — Skrip Voiceover ElevenLabs

Suara Veo berubah-ubah antar klip — itu masalah terbesar di format bersambung, karena penonton mengenali tokoh dari suaranya.

```
[Shot 1 — [cara bicara]]
"[dialogue]"

[Shot 2 — tanpa dialog, hanya musik]
( ekspresi saja )

[Shot 3 — suara [tokoh]: [karakter suara]]
"[dialogue]"

---
Pengaturan: Stability 0.5, Similarity 0.75, Style 0.35
Suara [Tokoh 1]: [3 kata sifat]
Suara [Tokoh 2]: [3 kata sifat]
```

**Kunci satu voice ID per tokoh untuk seluruh season** dan catat di paket produksi. Ganti voice di tengah season merusak ilusi lebih parah daripada wajah yang sedikit berubah.

Klip tanpa dialogue itu sah dan sering lebih kuat — tulis `( ekspresi saja )`. Beri catatan pengarahan akting kalau ada nuansa yang mudah salah: kalimat kemenangan yang diucapkan terlalu fasih, misalnya, justru membunuh kemenangannya.

### Langkah 9 — Finishing: Transisi, Musik, Caption

Tulis instruksi editor yang konkret, bukan "edit di CapCut". Sebutkan transisi per sambungan:

- **Potong bersih** — untuk ketegangan dan realisme; sambungan dalam satu adegan
- **Dissolve** — untuk montase yang mengalir; loncatan waktu halus; masuk ke footage asli
- **Fade hitam** — untuk loncatan waktu besar dan penutup pilu; panjangkan ~1 detik untuk cliffhanger berat

Musik adalah tempat episode dimenangkan atau hilang:

- Sebutkan **di klip mana musik berbelok**, bukan cuma genre. Belokan musik yang tepat lebih terasa daripada dialogue apapun
- **Hening total** lebih kuat daripada musik sedih di momen paling menyakitkan. Potong musik tepat di kalimat yang menghancurkan
- Untuk cliffhanger: bangun terus, lalu **potong mendadak** bersamaan dengan fade hitam

Penutup setiap episode:
- Tahan frame terakhir 1,5 detik + teks: `"Episode [N+1]: [teaser 3–5 kata]. BERSAMBUNG."` (episode terakhir: `FINAL`)
- Caption TikTok: `Ep [N] — [Judul]. [Satu kalimat menggoda tanpa spoiler] [emoji] #dramapendek #[topik] #[brand]`

**Distribusi:** post berurutan, jarak 1–2 hari; kumpulkan di satu playlist; balas komentar "lanjut dong" dengan tanggal rilis episode berikutnya.

### Langkah 10 — Pengiriman

Sajikan dalam urutan ini:

1. **Tabel arc season + kurva emosi** — minta approval
2. **Prompt gambar karakter**
3. **Character sheet + prompt klip Metode B untuk Episode 1** — minta approval
4. **Briefing Agent mode Episode 1** — cadangan
5. **Skrip voiceover ElevenLabs Episode 1**
6. **Instruksi transisi, musik, caption Episode 1**
7. **Pola untuk episode berikutnya** — lingkungan dan aset tambahan yang akan dibutuhkan

Tutup dengan: "Approve dulu Ep 1, baru aku tuliskan briefing lengkap Ep 2–[N]."

Jangan menulis 8 episode penuh kecuali user secara eksplisit memintanya setelah melihat hasil Episode 1.

## Struktur file yang dihasilkan skill ini

```
[nama-season]/
├── README.md                 # Daftar episode, aset, kurva emosi
├── 00-season-package.md      # Setup + arc + Episode 1
├── ep02-[judul].md           # Character sheet + klip + Agent + VO + finishing
├── ep03-[judul].md
└── ...
```

Satu file per episode, mandiri — user membukanya satu per satu saat produksi, bukan menggulir satu dokumen raksasa.

## Referensi

- `references/arcs.md` — lima preset arc season, pola cliffhanger, brand mapping
- `references/characters.md` — arketipe tokoh drama dan aturan konsistensi antar klip
- `references/example-wca.md` — contoh season 8 episode yang sudah jadi, beserta enam kesalahan yang ditemukan di dalamnya dan cara memperbaikinya

## Yang harus dikerjakan di editor, bukan di prompt

Minta Veo melakukan salah satu dari ini akan membuang kredit:

| Yang diinginkan | Yang terjadi kalau ditulis di prompt | Kerjakan begini |
|---|---|---|
| Layar gelap di detik tertentu | Veo tidak bisa diandalkan memotong di frame yang tepat | Generate penuh 8 detik, potong sendiri |
| Teks di layar HP, surat, papan nama | Huruf dan angka berantakan hampir selalu | Prompt cukup "layar menyala terang", teks ditempel di editor |
| Split screen video call | Frame jadi kacau | Generate dua klip terpisah, gabung di editor — atau potong-balik cepat |
| Tangan menghitung uang tunai | Jari bertambah, lembaran meleleh | Ganti jadi amplop |
| Potongan cepat di dalam satu klip | Veo mencoba, hasilnya blur | Pecah jadi dua klip |
| Keramaian lebih dari 3 orang | Wajah tokoh utama ikut tidak stabil | Close-up tokoh utama, keramaian blur di latar |

## Batasan yang jujur

- Skill ini menghasilkan prompt, bukan video. User yang generate di UI browser Flow.
- Konsistensi suara antar klip tidak mungkin di Flow tanpa fitur Avatar. Rencanakan dub ElevenLabs untuk tokoh yang banyak bicara.
- Wajah bergeser sedikit antar klip walaupun aset di-reference. Yang menyelamatkan adalah pakaian dan lingkungan yang konsisten — penonton mengenali tokoh dari siluet, bukan pori-pori.
- Agent mode masih eksperimental. Metode B selalu jadi jalur utama.
- Format 8 detik per klip adalah batas alat, bukan pilihan kreatif. Tulis setiap adegan supaya utuh dalam 8 detik, jangan menulis adegan panjang lalu berharap Veo memampatkannya.
- Periksa kontinuitas lintas episode sebelum mengirim: usia tokoh, rentang waktu yang disebut di voiceover, kostum, dan nama. Baris seperti "tiga bulan" di Ep 7 dan "tiga tahun lalu" di Ep 8 lolos dengan mudah karena tiap episode ditulis terpisah, dan penonton yang menonton berurutan akan menangkapnya.
