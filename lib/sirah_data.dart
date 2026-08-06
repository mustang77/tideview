/// Ringkasan Sirah Nabawiyah — garis waktu kehidupan Rasulullah ﷺ,
/// disusun per periode dengan tahun Masehi (M) dan Hijriah (H).
library;

class SirahEvent {
  final String year;
  final String title;
  final String body;
  const SirahEvent(this.year, this.title, this.body);
}

class SirahPeriod {
  final String title;
  final String range;
  final List<SirahEvent> events;
  const SirahPeriod(this.title, this.range, this.events);
}

const List<SirahPeriod> sirahPeriods = [
  SirahPeriod("Sebelum Kenabian", "571–610 M", [
    SirahEvent(
      "571 M",
      "Kelahiran di Tahun Gajah",
      "Rasulullah ﷺ lahir di Makkah pada Tahun Gajah, tahun ketika pasukan "
          "bergajah Abrahah gagal menyerang Ka'bah. Ayah beliau, Abdullah, "
          "wafat sebelum beliau lahir. Beliau kemudian disusui oleh Halimah "
          "as-Sa'diyah di perkampungan Bani Sa'd.",
    ),
    SirahEvent(
      "577 M",
      "Wafatnya Ibunda Aminah",
      "Dalam usia sekitar enam tahun, Rasulullah ﷺ kehilangan ibunda "
          "tercinta, Aminah binti Wahb, dalam perjalanan pulang dari "
          "Madinah. Beliau lalu diasuh oleh kakeknya, Abdul Muthalib.",
    ),
    SirahEvent(
      "579 M",
      "Dalam Asuhan Abu Thalib",
      "Setelah kakeknya wafat, Rasulullah ﷺ yang berusia delapan tahun "
          "diasuh oleh pamannya, Abu Thalib, yang melindunginya dengan "
          "penuh kasih sayang hingga akhir hayatnya.",
    ),
    SirahEvent(
      "±583 M",
      "Perjalanan Dagang ke Syam",
      "Dalam usia remaja beliau ikut kafilah dagang Abu Thalib ke Syam. "
          "Sejak muda beliau dikenal jujur dan terpercaya hingga digelari "
          "Al-Amin (yang tepercaya) oleh penduduk Makkah.",
    ),
    SirahEvent(
      "±595 M",
      "Menikah dengan Khadijah",
      "Setelah sukses menjalankan dagangan Khadijah binti Khuwailid ke "
          "Syam, Rasulullah ﷺ (25 tahun) menikah dengan Khadijah. Beliau "
          "adalah istri pertama, pendukung terbesar di masa-masa awal "
          "kenabian, dan ibu dari sebagian besar putra-putri beliau.",
    ),
    SirahEvent(
      "±605 M",
      "Peletakan Hajar Aswad",
      "Ketika Quraisy memperbarui bangunan Ka'bah, mereka berselisih "
          "tentang siapa yang berhak meletakkan Hajar Aswad. Rasulullah ﷺ "
          "menengahi dengan meletakkan batu itu di atas selembar kain agar "
          "semua kabilah dapat mengangkatnya bersama — perselisihan pun "
          "selesai dengan damai.",
    ),
  ]),
  SirahPeriod("Awal Kenabian di Makkah", "610–619 M", [
    SirahEvent(
      "610 M",
      "Wahyu Pertama di Gua Hira",
      "Dalam usia 40 tahun, saat berkhalwat di Gua Hira, Rasulullah ﷺ "
          "menerima wahyu pertama melalui Malaikat Jibril: lima ayat awal "
          "Surah Al-'Alaq — \"Iqra'!\" (Bacalah!). Khadijah dan "
          "sepupunya Waraqah bin Naufal meneguhkan bahwa itu adalah wahyu "
          "kenabian.",
    ),
    SirahEvent(
      "610–613 M",
      "Dakwah Sembunyi-sembunyi",
      "Selama sekitar tiga tahun dakwah dilakukan diam-diam. Orang-orang "
          "pertama yang beriman antara lain Khadijah, Abu Bakar, Ali bin "
          "Abi Thalib yang masih belia, dan Zaid bin Haritsah.",
    ),
    SirahEvent(
      "613 M",
      "Dakwah Terang-terangan",
      "Turun perintah untuk berdakwah secara terbuka. Rasulullah ﷺ menyeru "
          "kaumnya di bukit Shafa, namun mayoritas pembesar Quraisy "
          "menolak dan mulai memusuhi kaum muslimin.",
    ),
    SirahEvent(
      "±614 M",
      "Penyiksaan Kaum Muslimin",
      "Kaum muslimin yang lemah disiksa dengan kejam — di antaranya Bilal "
          "bin Rabah yang ditindih batu di padang pasir, serta keluarga "
          "Yasir; Sumayyah, istri Yasir, menjadi syahidah pertama dalam "
          "Islam.",
    ),
    SirahEvent(
      "615 M",
      "Hijrah Pertama ke Habasyah",
      "Untuk menyelamatkan iman mereka, sebagian sahabat hijrah ke "
          "Habasyah (Ethiopia) dan mendapat perlindungan raja Najasyi yang "
          "adil.",
    ),
    SirahEvent(
      "±616 M",
      "Hamzah dan Umar Masuk Islam",
      "Keislaman dua tokoh kuat Quraisy — Hamzah bin Abdul Muthalib dan "
          "Umar bin Khattab — menambah kekuatan dan keberanian kaum "
          "muslimin dalam menampakkan agamanya.",
    ),
    SirahEvent(
      "616–619 M",
      "Pemboikotan Bani Hasyim",
      "Quraisy memboikot total Bani Hasyim dan Bani Muthalib di lembah Abu "
          "Thalib selama sekitar tiga tahun — tidak berjual beli dan tidak "
          "menikahi mereka — hingga kaum muslimin menderita kelaparan "
          "hebat sebelum boikot itu akhirnya dibatalkan.",
    ),
  ]),
  SirahPeriod("Tahun Kesedihan hingga Hijrah", "619–622 M", [
    SirahEvent(
      "619 M",
      "'Amul Huzni — Tahun Kesedihan",
      "Dalam waktu berdekatan Rasulullah ﷺ kehilangan dua pelindung "
          "terbesarnya: istri tercinta Khadijah dan paman beliau Abu "
          "Thalib. Tekanan Quraisy pun semakin keras.",
    ),
    SirahEvent(
      "619 M",
      "Dakwah ke Thaif",
      "Rasulullah ﷺ berjalan ke Thaif berharap sambutan, namun justru "
          "diusir dan dilempari batu hingga terluka. Beliau tetap berdoa "
          "agar keturunan mereka kelak menyembah Allah — teladan kesabaran "
          "yang agung.",
    ),
    SirahEvent(
      "±620 M",
      "Isra' dan Mi'raj",
      "Allah memperjalankan Rasulullah ﷺ pada malam hari dari Masjidil "
          "Haram ke Masjidil Aqsha (Isra'), lalu naik ke langit (Mi'raj). "
          "Pada peristiwa agung inilah shalat lima waktu diwajibkan.",
    ),
    SirahEvent(
      "621 M",
      "Baiat Aqabah Pertama",
      "Dua belas orang penduduk Yatsrib (Madinah) berbaiat kepada "
          "Rasulullah ﷺ di Aqabah, lalu Mush'ab bin Umair diutus untuk "
          "mengajarkan Islam di sana.",
    ),
    SirahEvent(
      "622 M",
      "Baiat Aqabah Kedua",
      "Tujuh puluh lebih penduduk Yatsrib berbaiat siap membela "
          "Rasulullah ﷺ. Jalan hijrah pun terbuka, dan kaum muslimin mulai "
          "berangkat ke Madinah secara bertahap.",
    ),
  ]),
  SirahPeriod("Membangun Madinah", "622–627 M", [
    SirahEvent(
      "622 M / 1 H",
      "Hijrah ke Madinah",
      "Rasulullah ﷺ hijrah bersama Abu Bakar, bersembunyi tiga malam di "
          "Gua Tsur dari kejaran Quraisy. Peristiwa hijrah ini kemudian "
          "menjadi awal penanggalan kalender Islam. Beliau singgah di Quba "
          "dan membangun masjid pertama, Masjid Quba.",
    ),
    SirahEvent(
      "622 M / 1 H",
      "Masjid Nabawi dan Persaudaraan",
      "Di Madinah, Rasulullah ﷺ membangun Masjid Nabawi, mempersaudarakan "
          "kaum Muhajirin dan Anshar, serta menyusun Piagam Madinah yang "
          "mengatur kehidupan bersama seluruh penduduk.",
    ),
    SirahEvent(
      "624 M / 2 H",
      "Perubahan Kiblat dan Puasa",
      "Kiblat shalat dipindahkan dari Baitul Maqdis ke Ka'bah di Makkah, "
          "dan pada tahun yang sama puasa Ramadhan diwajibkan.",
    ),
    SirahEvent(
      "624 M / 2 H",
      "Perang Badar",
      "Pertempuran besar pertama: 313 kaum muslimin menghadapi sekitar "
          "1.000 pasukan Quraisy di Badar. Dengan pertolongan Allah kaum "
          "muslimin menang gemilang — hari itu disebut Yaumul Furqan, hari "
          "pembeda antara yang haq dan yang batil.",
    ),
    SirahEvent(
      "625 M / 3 H",
      "Perang Uhud",
      "Kaum muslimin menghadapi Quraisy di kaki Gunung Uhud. Kelalaian "
          "pasukan pemanah meninggalkan posisinya membuat pasukan muslimin "
          "terdesak; Hamzah bin Abdul Muthalib gugur syahid. Peristiwa ini "
          "menjadi pelajaran besar tentang ketaatan.",
    ),
    SirahEvent(
      "627 M / 5 H",
      "Perang Khandaq (Ahzab)",
      "Pasukan gabungan sekitar 10.000 orang mengepung Madinah. Atas usul "
          "Salman al-Farisi, kaum muslimin menggali parit (khandaq) di "
          "utara kota. Setelah pengepungan yang berat, Allah mengirim "
          "angin badai yang memporak-porandakan pasukan sekutu.",
    ),
  ]),
  SirahPeriod("Perdamaian dan Kemenangan", "628–631 M", [
    SirahEvent(
      "628 M / 6 H",
      "Perjanjian Hudaibiyah",
      "Rasulullah ﷺ dan 1.400 sahabat berniat umrah namun dihalangi "
          "Quraisy, lalu lahirlah Perjanjian Hudaibiyah. Meski tampak "
          "merugikan, perjanjian damai ini disebut Al-Qur'an sebagai "
          "kemenangan yang nyata — dakwah pun menyebar pesat.",
    ),
    SirahEvent(
      "628 M / 7 H",
      "Surat kepada Para Raja",
      "Rasulullah ﷺ mengirim surat dakwah kepada para penguasa dunia — "
          "Heraklius (Romawi), Kisra (Persia), Muqauqis (Mesir), dan "
          "Najasyi (Habasyah) — mengajak mereka kepada Islam.",
    ),
    SirahEvent(
      "629 M / 8 H",
      "Perang Mu'tah",
      "Tiga ribu pasukan muslimin menghadapi pasukan Romawi yang jauh "
          "lebih besar di Mu'tah. Tiga panglima gugur berturut-turut — "
          "Zaid bin Haritsah, Ja'far bin Abi Thalib, dan Abdullah bin "
          "Rawahah — sebelum Khalid bin Walid menyelamatkan pasukan.",
    ),
    SirahEvent(
      "630 M / 8 H",
      "Fathu Makkah — Pembebasan Makkah",
      "Setelah Quraisy melanggar perjanjian, Rasulullah ﷺ memasuki Makkah "
          "dengan 10.000 pasukan nyaris tanpa pertumpahan darah. Ka'bah "
          "dibersihkan dari berhala, dan beliau memaafkan penduduk Makkah: "
          "\"Pergilah, kalian semua bebas.\"",
    ),
    SirahEvent(
      "630 M / 9 H",
      "Perang Tabuk dan Tahun Delegasi",
      "Rasulullah ﷺ memimpin pasukan besar ke Tabuk menghadapi ancaman "
          "Romawi yang akhirnya tidak terjadi pertempuran. Setelah itu "
          "kabilah-kabilah Arab berdatangan menyatakan keislaman — tahun "
          "itu dikenal sebagai 'Amul Wufud, Tahun Delegasi.",
    ),
  ]),
  SirahPeriod("Akhir Hayat", "632 M", [
    SirahEvent(
      "632 M / 10 H",
      "Haji Wada' — Haji Perpisahan",
      "Rasulullah ﷺ menunaikan haji bersama lebih dari seratus ribu kaum "
          "muslimin dan menyampaikan khutbah perpisahan di Arafah: pesan "
          "persaudaraan, keharaman darah dan harta sesama, serta wasiat "
          "berpegang pada Al-Qur'an. Turunlah ayat, \"Pada hari ini telah "
          "Kusempurnakan untukmu agamamu…\" (QS Al-Ma'idah: 3).",
    ),
    SirahEvent(
      "632 M / 11 H",
      "Wafatnya Rasulullah ﷺ",
      "Pada 12 Rabiul Awal 11 H, dalam usia 63 tahun, Rasulullah ﷺ wafat "
          "di Madinah di kamar Aisyah dan dimakamkan di tempat yang sama — "
          "kini berada di dalam Masjid Nabawi. Pesan terakhir beliau di "
          "antaranya: \"Ash-shalah, ash-shalah…\" — jagalah shalat, dan "
          "berbuat baiklah kepada orang-orang yang kalian pimpin.",
    ),
  ]),
];
