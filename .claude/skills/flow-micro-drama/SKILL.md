---
name: flow-micro-drama
description: Hasilkan paket produksi micro drama vertikal bersambung untuk Google Flow (Veo) — series 6–10 episode untuk TikTok, Reels, dan Shorts. Cukup berikan premis cerita, brand, atau tokoh utamanya, skill ini menghasilkan semua yang dibutuhkan untuk menjalankan satu season penuh di Agent mode Flow — prompt gambar karakter yang konsisten, arc season dengan cliffhanger di setiap episode, shot list 4 shot per episode, briefing Agent mode siap tempel, skrip voiceover ElevenLabs per karakter, instruksi finishing CapCut, dan caption TikTok. Gunakan kapanpun user ingin membuat micro drama, drama pendek vertikal, sinetron TikTok, cerita bersambung, atau konten storytelling brand berbentuk series — juga pada frasa seperti "micro drama", "drama pendek", "drama vertikal", "series TikTok", "cerita bersambung", "Flow drama", "BERSAMBUNG", atau ketika user membawa paket produksi drama yang sudah ada dan ingin melanjutkan, menulis ulang, atau melengkapi episodenya.
---

# Google Flow Micro Drama Generator

Menghasilkan paket produksi lengkap untuk micro drama vertikal bersambung di Google Flow. Satu premis cerita menghasilkan semua yang dibutuhkan user untuk menjalankan satu season penuh — prompt karakter, arc season, shot list per episode, briefing Agent mode, skrip voiceover, dan instruksi finishing.

Skill ini adalah saudara dari `flow-ugc-ads`. Bedanya: UGC ad menjual dalam 40 detik lewat satu kreator yang bicara ke kamera. Micro drama menjual lewat **cerita bersambung** — penonton kembali karena penasaran, bukan karena tertarik produk. CTA hanya muncul sekali, di episode terakhir.

## Apa yang dilakukan skill ini

1. Mengambil premis cerita, brand/tujuan, dan bahasa dari user
2. Opsional membaca `brand/brand-dna.md`, `brand/brand-voice.md`, `brand/icp-cards.md` jika ada — dilewati diam-diam jika tidak ada
3. Merancang arc season 6–10 episode, setiap episode berakhir dengan cliffhanger
4. Menghasilkan prompt gambar karakter realistis untuk 2–3 tokoh inti yang dipakai ulang sepanjang season
5. Menulis shot list 4 shot per episode dengan dialogue lengkap
6. Menghasilkan briefing Agent mode Flow per episode — satu blok siap tempel
7. Menulis skrip voiceover ElevenLabs dengan catatan suara per karakter
8. Memberi instruksi finishing CapCut + caption TikTok per episode

Skill ini TIDAK memanggil API apapun dan TIDAK menghasilkan video. Skill ini menghasilkan paket produksi. User menjalankan generate aktual di UI browser Flow.

## Sebelum memulai

User membutuhkan:
- Langganan Google AI Pro di labs.google.com/flow
- Tool generate gambar untuk karakter: ChatGPT Images, Nano Banana Pro, atau Gemini
- CapCut (atau editor lain) untuk merangkai klip
- Opsional: akun ElevenLabs kalau mau dub ulang suara

Tidak perlu API key. Tidak perlu kode. Tidak perlu terminal.

## Aturan kredit — WAJIB disampaikan ke user

Satu episode = 4 klip × 8 detik. Satu season 8 episode = 32 klip. Itu mahal.

**Jangan pernah generate satu season sekaligus.** Alur yang benar:

1. Generate 2–3 gambar karakter (sekali saja, dipakai seluruh season)
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

Kalau user datang membawa paket produksi yang sudah ada (arc, karakter, atau episode yang sudah ditulis), jangan tulis ulang dari nol — baca, pertahankan nama karakter, dialogue, dan gaya yang sudah ada, lalu lanjutkan dari episode yang belum lengkap.

### Langkah 2 — Cek Konteks Brand

Cari:
- `brand/brand-dna.md`
- `brand/brand-voice.md`
- `brand/icp-cards.md`

Jika ada, baca diam-diam. Gunakan untuk menajamkan CTA episode terakhir dan memastikan konflik cerita mencerminkan masalah nyata ICP. Jangan sebut ini ke user. Jika tidak ada, lanjutkan — skill ini bekerja hanya dengan premis.

### Langkah 3 — Rancang Arc Season

Buat tabel arc sebelum menulis satu shot pun. Setiap baris = satu episode.

```
| Ep | Judul | Isi episode | Cliffhanger penutup |
```

**Aturan arc:**
- Setiap episode berakhir dengan **cliffhanger** — pertanyaan terbuka, pintu tertutup, kalimat yang menyakitkan, atau layar gelap sebelum jawaban. Tanpa pengecualian sampai episode terakhir.
- Episode 1 memperkenalkan **mimpi + penolakan** di 32 detik. Bukan latar belakang, bukan narasi. Langsung konflik.
- Titik terendah tokoh ada di sekitar 70% season (Ep 6 dari 8). Di situ penonton paling terikat.
- Kemenangan hanya di episode terakhir. Kemenangan lebih awal membunuh alasan penonton kembali.
- **CTA hanya sekali, di episode terakhir.** CTA di tengah season membuat penonton sadar sedang ditawari sesuatu dan mereka berhenti menonton.

Lihat `references/arcs.md` untuk lima preset arc lengkap beserta pola cliffhanger yang terbukti bekerja.

Tunjukkan tabel arc ke user dan **minta approval sebelum lanjut**. Mengubah arc di tahap ini gratis.

### Langkah 4 — Generate Prompt Gambar Karakter

Hasilkan prompt gambar untuk 2–3 tokoh inti — tokoh yang muncul di lebih dari satu episode. Tokoh sekali pakai (pembeli motor, kasir, penumpang) tidak perlu aset; deskripsikan langsung di prompt shot.

Ikuti formula ini persis:

```
Foto iPhone candid seorang [gender] Indonesia berusia [usia] tahun, [detail fisik spesifik — warna kulit, tekstur rambut, kerutan, kumis, bekas luka], tanpa makeup, mengenakan [pakaian spesifik dan realistis — sebutkan kondisinya: lusuh, pudar, sering dicuci], [lingkungan spesifik — berdiri di halaman rumah kampung dengan dinding bata ekspos dan jemuran di latar belakang]. Diambil dari [sudut — sedikit rendah dan off-center / sedikit di atas level mata]. [Pencahayaan spesifik — cahaya sore keemasan tidak merata / cahaya pagi mendung lembut]. Eksposur sedikit tidak sempurna. Tekstur kulit nyata, tidak diretuh. Bukan model, wajah orang biasa. Realisme gaya editorial.
```

**Aturan:**
- Jangan pernah gunakan "cantik", "tampan", "memukau", atau deskriptor model
- Selalu sebutkan **kondisi pakaian** — di drama, pakaian menceritakan status ekonomi tokoh, dan konsistensi pakaian adalah kunci kontinuitas
- Selalu sertakan lingkungan spesifik, bahkan di shot referensi karakter
- Selalu sertakan minimal satu ketidaksempurnaan yang disengaja
- Selalu sertakan "Foto iPhone candid" — sinyal realisme terkuat
- Beri **rentang usia dan penanda wajah yang tajam** untuk tiap tokoh supaya Flow tidak menukar wajah antar karakter

Lihat `references/characters.md` untuk template arketipe tokoh drama.

Beritahu user: simpan hasilnya dengan nama file yang deskriptif dan mudah diketik — `bima.png`, `bapak.png`, `recruiter.png` — lalu unggah semuanya ke proyek Flow. Nama file inilah yang jadi tag di setiap prompt shot.

### Langkah 5 — Tulis Shot List Episode

Setiap episode = **4 shot × 8 detik = ±32 detik**. Setiap shot mendapat:

```
Shot N/4 — [Fungsi shot]
Lingkungan: [di mana — sespesifik mungkin, termasuk waktu hari]
Aksi: [satu aksi saja per shot]
Karakter dalam frame: [nama file aset]
Dialogue [nama tokoh]: "[apa yang diucapkan]"
```

**Struktur 4 shot (pola default):**

| Shot | Fungsi | Isi |
|------|--------|-----|
| 1 — Hook | Tarik penonton dalam 2 detik | Tokoh sendirian, momen paling rentan. Satu kalimat yang membuat penonton bertanya "kenapa?" |
| 2 — Niat | Tokoh mengambil langkah | Tokoh menyatakan keinginannya ke tokoh lain. Suara gugup, taruhan jelas |
| 3 — Tekanan | Dunia menolak | Close-up lawan bicara. Kalimat yang menyakitkan, diucapkan datar — bukan berteriak |
| 4 — Cliffhanger | Kunci episode berikutnya | Tokoh ditinggal sendirian. Kalimat terakhir dijatuhkan tanpa menoleh. Musik berhenti |

**Aturan dialogue:**
- ±3 kata per detik. Klip 8 detik = **maksimal 20 kata**, dan di drama lebih pendek justru lebih kuat
- Satu shot = satu kalimat penting. Sisanya diam. Diam adalah aktingnya
- Kalimat yang paling menyakitkan diucapkan **datar dan pelan**, bukan diteriakkan
- Shot 1 harus berfungsi tanpa suara — caption yang membawanya saat autoplay
- Jangan menulis narasi atau voiceover penjelas. Kalau penonton butuh dijelaskan, shot-nya yang salah
- Nama brand tidak pernah disebut sampai episode terakhir

Tunjukkan shot list ke user dan minta approval **sebelum** menulis briefing Flow.

### Langkah 6 — Tulis Briefing Agent Mode Flow

Hasilkan satu blok siap tempel per episode. Ini format yang paling hemat waktu user — satu paste, empat klip.

```
Aku sedang membuat episode drama pendek vertikal 4 shot berbahasa [bahasa]. Karakter harus konsisten memakai gambar yang kuupload.

Aset:
- [file1].png — [deskripsi satu baris]
- [file2].png — [deskripsi satu baris]

Shot 1: [lingkungan lengkap + waktu hari]. [file1].png [aksi spesifik]. Berbicara [cara bicara]: "[dialogue]." [pencahayaan], nuansa handheld, sedikit goyangan kamera, candid, tekstur kulit natural, framing tidak sempurna, sinematik muram. Vertikal 9:16, 8 detik.

Shot 2: [lingkungan]. [file1].png [aksi] ke [file2].png yang [aksi]. [Tokoh] berbicara [cara bicara]: "[dialogue]." [pencahayaan], handheld, candid, tekstur kulit natural, framing tidak sempurna. Vertikal 9:16, 8 detik.

Shot 3: [lingkungan yang sama], close-up [file2].png [aksi mikro]. Berbicara [cara bicara]: "[dialogue]." [pencahayaan], handheld, candid, tekstur kulit natural. Vertikal 9:16, 8 detik.

Shot 4: [lingkungan]. [aksi penutup — biasanya satu tokoh pergi, satu tokoh ditinggal]. [Tokoh] berbicara tanpa menoleh: "[dialogue]." Musik hening, [pencahayaan hampir gelap], handheld, candid, framing tidak sempurna, sinematik muram. Vertikal 9:16, 8 detik.

Jaga konsistensi wajah dan pakaian [file1].png dan [file2].png di semua shot. Semua dialog dalam [bahasa dan logat]. Vertikal 9:16.
```

**Modifier gaya wajib di setiap shot:**
- `nuansa handheld, sedikit goyangan kamera`
- `candid`
- `tekstur kulit natural`
- `framing tidak sempurna`
- pencahayaan spesifik sesuai waktu hari
- `sinematik muram` untuk shot berat; hilangkan untuk shot yang ringan atau penuh harapan

**Aturan tag aset:**
- Tag nama file di **setiap** shot yang menampilkan tokoh itu. Satu tag yang terlewat = wajah tokoh berubah
- Sebutkan pakaian tokoh di setiap shot dalam satu episode. Flow tidak mengingat wardrobe antar klip
- Maksimal 2 tokoh bertag per shot. Tiga atau lebih membuat wajah mulai tertukar

Selalu beri catatan: kalau Agent mode tidak menjalankan semua shot otomatis, tempel prompt per shot satu per satu. Agent mode masih eksperimental.

### Langkah 7 — Tulis Skrip Voiceover ElevenLabs

Suara Veo bisa berubah-ubah antar klip — itu masalah terbesar di format bersambung, karena penonton mengenali tokoh dari suaranya. Selalu sediakan skrip dub.

```
SKRIP VOICEOVER — Ep [N] "[Judul]"
Total durasi: ~32 detik

[Shot 1 — 0–8 dtk]  ([cara bicara])
"[dialogue]"

[Shot 2 — 8–16 dtk]  ([cara bicara])
"[dialogue]"

[Shot 3 — 16–24 dtk]  (suara [tokoh]: [karakter suara])
"[dialogue]"

[Shot 4 — 24–32 dtk]  (suara [tokoh]: [karakter suara])
"[dialogue]"

---
Pengaturan ElevenLabs: Stability 0.5, Similarity 0.75, Style 0.35
Suara [Tokoh 1]: [3 kata sifat — mis. muda, hangat, rapuh]
Suara [Tokoh 2]: [3 kata sifat — mis. berat, kering, tua]
```

Beritahu user: **kunci satu voice ID per tokoh untuk seluruh season**, catat di paket produksi. Ganti voice di tengah season merusak ilusi lebih parah daripada wajah yang sedikit berubah.

Kalau perbedaan suara Veo tidak terlalu mengganggu, biarkan saja — penonton drama pendek toleran. Dub hanya kalau benar-benar mengganggu.

### Langkah 8 — Instruksi Finishing dan Distribusi

Sertakan per episode:

**CapCut:**
- Caption otomatis, font tebal putih dengan outline hitam
- Musik sesuai tone episode — piano sedih pelan untuk episode berat, string naik untuk episode harapan
- Frame terakhir ditahan 1,5 detik + teks: `"Episode [N+1]: [teaser 3–5 kata]. BERSAMBUNG."`
- Potong tepat di kalimat terakhir. Jangan biarkan klip menggantung setelah dialogue selesai

**Caption TikTok:**
```
Ep [N] — [Judul]. [Satu kalimat yang menggoda tanpa spoiler] [emoji] #dramapendek #[hashtag topik] #[hashtag brand/kota]
```

**Distribusi:**
- Post berurutan, jarak 1–2 hari. Season yang di-dump sekaligus kehilangan efek penasaran
- Kumpulkan di satu playlist agar penonton baru bisa menonton dari Ep 1
- Balas komentar "lanjut dong" dengan tanggal rilis episode berikutnya — itu mesin retensi gratis

**Menyisipkan footage asli:** kalau user punya footage nyata yang relevan (lokasi asli, tempat usaha, kampus), selipkan satu klip asli di antara klip AI. Campuran AI + footage asli terasa jauh lebih dipercaya daripada AI murni.

### Langkah 9 — Pengiriman

Sajikan paket produksi dalam urutan ini:

1. **Tabel arc season** — minta approval
2. **Prompt gambar karakter** — tempel ke ChatGPT Images / Nano Banana Pro / Gemini
3. **Shot list Episode 1** dengan dialogue — minta approval
4. **Briefing Agent mode Episode 1** — satu blok siap tempel
5. **Skrip voiceover ElevenLabs Episode 1**
6. **Instruksi finishing CapCut + caption TikTok Episode 1**
7. **Pola untuk episode berikutnya** — lingkungan dan aset tambahan yang akan dibutuhkan

Tutup dengan: "Approve dulu Ep 1, baru aku tuliskan briefing lengkap Ep 2–[N]."

Jangan menulis 8 episode penuh kecuali user secara eksplisit memintanya setelah melihat hasil Episode 1.

## Struktur file yang dihasilkan skill ini

```
[nama-season]-production-package/
├── season-arc.md             # Tabel arc + cliffhanger tiap episode
├── character-prompts.md      # Prompt gambar untuk tokoh inti
├── ep01-shot-list.md         # Shot list 4 shot + dialogue
├── ep01-agent-briefing.md    # Briefing Agent mode siap tempel
├── ep01-voiceover.md         # Skrip ElevenLabs + catatan suara
└── ep01-finishing.md         # CapCut + caption TikTok
```

Tambahkan `epNN-*.md` per episode setelah user approve episode sebelumnya.

## Referensi

- `references/arcs.md` — lima preset arc season lengkap dengan pola cliffhanger dan struktur emosional
- `references/characters.md` — template prompt gambar untuk arketipe tokoh drama Indonesia
- `references/example-wca.md` — contoh paket produksi lengkap (season 8 episode, Episode 1 penuh) untuk ditiru strukturnya

## Batasan yang jujur

- Skill ini menghasilkan prompt, bukan video. User yang generate di UI browser Flow.
- Konsistensi suara antar klip tidak mungkin di Flow tanpa fitur Avatar. Rencanakan dub ElevenLabs untuk tokoh yang banyak bicara.
- Wajah bergeser sedikit antar klip walaupun aset di-tag. Yang menyelamatkan adalah pakaian dan lingkungan yang konsisten — penonton mengenali tokoh dari siluet, bukan pori-pori.
- Adegan dengan tangan melakukan sesuatu yang rumit (menghitung uang, menandatangani, menyerahkan barang) sering berhalusinasi. Potong di pergelangan tangan atau pakai reaksi wajah sebagai gantinya.
- Teks dalam frame (layar HP, surat, papan nama) hampir selalu berantakan. Tambahkan teksnya di CapCut, bukan di prompt.
- Adegan ramai lebih dari 3 orang membuat wajah tokoh utama tidak stabil. Gunakan close-up tokoh utama dengan keramaian yang blur di latar.
- Agent mode Flow masih eksperimental. Sediakan selalu prompt per shot sebagai cadangan.
- Format 4 × 8 detik adalah kompromi kredit, bukan pilihan kreatif. Kalau user punya kredit lebih, 5–6 shot per episode memberi ruang napas yang jauh lebih baik.
