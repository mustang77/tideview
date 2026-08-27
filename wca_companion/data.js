// data.js — all content, in both languages. I18N.en and I18N.id have the
// exact same structure; app.js renders from I18N[currentLang].

const I18N = {

/* ================================================================ EN */
en: {
  ui: {
    navHome: "Home", navGuest: "Guest Guide", navCrew: "Crew Guide", navTools: "Tools",
    navGlossary: "Glossary", navQuiz: "Quiz",
    heroTitle: "Your companion at sea.",
    heroSub: "Guides, checklists and tools for cruise <strong>guests</strong> and cruise <strong>crew</strong> — free, works offline, nothing to install.",
    guestCardTitle: "I'm a Guest",
    guestCardDesc: "First cruise or fiftieth — sail prepared, from booking to disembarkation.",
    crewCardTitle: "I'm Crew",
    crewCardDesc: "Getting hired, joining your ship, life on board, and your rights at sea.",
    chipCountdown: "⏳ Countdown", chipChecklists: "✅ Checklists", chipTip: "💵 Tip calculator",
    chipGlossary: "📖 40+ cruise terms", chipQuiz: "🎓 Ready-to-sail quiz",
    guestTitle: "🧳 Guest Guide",
    guestLead: "Everything a cruise guest needs, in sailing order. Tap a step to open it.",
    crewTitle: "⚓ Crew Guide",
    crewLead: "From application to sign-off — how working at sea really works.",
    toolsTitle: "🛠 Tools",
    cdTitle: "⏳ Countdown", cdWhat: "What are you counting down to?",
    cdPlaceholder: "My cruise / My sign-on date", cdDate: "Date", cdStart: "Start countdown",
    cdChange: "Change", cdDays: "days to go", cdDay: "day to go",
    cdSailing: "Bon voyage — you're sailing!", cdDone: "Voyage complete — set the next date!",
    clTitle: "✅ Packing checklist", clGuest: "Guest", clCrew: "Crew", clPacked: "packed",
    tipTitle: "💵 Gratuity calculator", tipGuests: "Guests", tipNights: "Nights",
    tipRate: "Daily gratuity per person ($)", tipService: "Service gratuities:",
    tipBarBill: "Bar bill ($)", tipBarPct: "Auto-gratuity %", tipBar: "Bar gratuity:",
    tipNote: "Typical 2026 rates: $15–$20 per person per day; bar auto-gratuity 18–20%. Check your cruise line.",
    cvTitle: "🌊 Maritime converter", cvSpeed: "Speed", cvDist: "Distance",
    cvDepth: "Depth / height", cvTemp: "Temperature",
    cvKnotsPh: "knots", cvNmPh: "nautical miles", cvMPh: "meters", cvCPh: "°C",
    glTitle: "📖 Cruise & Maritime Glossary",
    glSearchPh: "Search terms… (e.g. muster, tender, STCW)", glNone: "No terms found.",
    quizTitle: "🎓 Are you ready to sail?",
    quizIntro: "10 questions from the Academy. Guests and crew welcome — no uniform required.",
    quizStart: "Start the quiz", quizAgain: "Try again",
    quizProgress: "Question {n} of {total} · Score {score}",
    footerTag: "— learn the ways of the sea.",
    footerNote: "General guidance only — always follow your cruise line's and ship command's instructions. Content works offline; your checklists and countdown are saved on this device only.",
  },

  glCats: { all: "All", ship: "Ship & sea", onboard: "On board", crew: "Crew & work", safety: "Safety" },

  guestGuide: [
    { title: "1 · Before you sail", icon: "🗓", html: `<ul>
      <li><strong>Passport</strong> valid at least 6 months beyond your return date; check visa rules for every port country.</li>
      <li><strong>Travel insurance</strong> with medical evacuation cover — ship medical care and evacuations are expensive.</li>
      <li><strong>Arrive one day early</strong> in your departure city. A delayed flight on embarkation day can mean missing the ship.</li>
      <li>Complete <strong>online check-in</strong> and print/save your boarding documents and luggage tags.</li>
      <li>Book popular <strong>shore excursions and specialty dining</strong> before you sail — they sell out.</li></ul>` },
    { title: "2 · Embarkation day", icon: "🛳", html: `<ul>
      <li>Pack a <strong>carry-on</strong> with documents, medications, valuables and swimwear — checked bags can take hours to reach your cabin.</li>
      <li>Your <strong>cruise card</strong> is your room key, onboard wallet and ID — keep it on you always (a lanyard helps).</li>
      <li>Cabins are usually ready early afternoon; lunch at the buffet while you wait.</li>
      <li>The <strong>muster drill</strong> (safety briefing) is mandatory — complete it early via the app or at your muster station.</li>
      <li>Be on board by the <strong>all-aboard time</strong> printed on your documents — the ship sails without latecomers.</li></ul>` },
    { title: "3 · Life on board", icon: "🍽", html: `<ul>
      <li>Ships run on <strong>ship time</strong>, which may differ from local port time. Always follow ship time.</li>
      <li>Main dining room, buffet and casual venues are included; <strong>specialty restaurants</strong> cost extra.</li>
      <li>Check the <strong>daily program</strong> (paper or app) each evening and plan your next day.</li>
      <li>Everything is charged to your <strong>onboard account</strong> via cruise card — review it every couple of days.</li>
      <li>Wi-Fi at sea is satellite-based: slower and pricier than on land. Buy packages early for discounts.</li>
      <li>Dress codes: most nights are casual; <strong>formal night</strong> is usually once per week — a nice outfit is enough.</li></ul>` },
    { title: "4 · Port days", icon: "🏝", html: `<ul>
      <li>Note the <strong>all-aboard time</strong> — typically 30–60 minutes before sailing. The ship will not wait for independent travelers.</li>
      <li>Ship-sold <strong>excursions guarantee</strong> the ship waits if the tour runs late; going independent is cheaper but the risk is yours.</li>
      <li>Some ports use <strong>tenders</strong> (small boats) — allow extra time to get ashore and back.</li>
      <li>Carry your cruise card, a photo ID, small bills in local currency, and the ship's <strong>port agent contact</strong> from the daily program.</li></ul>` },
    { title: "5 · Money & tipping", icon: "💵", html: `<ul>
      <li>Most lines add <strong>daily service gratuities</strong> (about $15–$20 per person per day) to your account — use our calculator in Tools.</li>
      <li>Bars add an <strong>automatic 18–20% gratuity</strong> to each order.</li>
      <li><strong>Drink packages</strong> usually pay off from ~5–6 drinks per day — do the math before buying.</li>
      <li>Extra cash tips for your cabin steward or waiter are appreciated but optional.</li></ul>` },
    { title: "6 · Health & safety", icon: "⛑", html: `<ul>
      <li>Prone to motion sickness? Choose a <strong>midship cabin on a lower deck</strong>; patches work best applied before you feel ill.</li>
      <li><strong>Wash hands</strong> often and use sanitizer stations — it's the best defense against stomach bugs at sea.</li>
      <li>Know your <strong>muster station</strong> (printed on your cabin door and cruise card).</li>
      <li>The <strong>medical center</strong> can treat most issues; fees apply — another reason for travel insurance.</li></ul>` },
    { title: "7 · Disembarkation", icon: "🧾", html: `<ul>
      <li>Settle your <strong>onboard account</strong> the night before; check for surprise charges.</li>
      <li><strong>Self-assist</strong>: carry your own bags and walk off first. Otherwise, bags go outside your cabin the night before and you collect them in the terminal.</li>
      <li>Keep documents, medication and valuables <strong>with you</strong>, not in checked bags.</li>
      <li>Don't book flights before ~noon — disembarkation and customs take time.</li></ul>` },
  ],

  crewGuide: [
    { title: "1 · Getting hired", icon: "📋", html: `<ul>
      <li>Apply directly on cruise line career sites or via <strong>official hiring partners</strong> listed there.</li>
      <li><strong>⚠️ Never pay anyone to get a cruise ship job.</strong> Legitimate recruiters don't charge "registration" or "guarantee" fees — that's the #1 scam.</li>
      <li>Contracts typically run <strong>4–9 months</strong> depending on department and rank, followed by ~2 months vacation.</li>
      <li>Expect video interviews and English assessments; hotel roles also test service scenarios.</li></ul>` },
    { title: "2 · Documents & training", icon: "🎓", html: `<ul>
      <li><strong>STCW Basic Safety Training</strong> is mandatory for all seafarers: firefighting, sea survival, first aid, personal safety.</li>
      <li>A valid <strong>seafarer medical certificate</strong> (e.g. ENG1 or your flag state's equivalent) is required.</li>
      <li>US itineraries need a <strong>C1/D crew visa</strong>; other regions have their own rules — the company will tell you which.</li>
      <li>Keep passport, medical, STCW and vaccination certificates valid for your <strong>whole contract plus 6 months</strong>.</li>
      <li>The company usually books and pays your <strong>flights to the ship</strong>.</li></ul>` },
    { title: "3 · Joining the ship", icon: "🚢", html: `<ul>
      <li>At the gangway you'll <strong>sign on</strong>: crew ID card, cabin assignment, safety number and muster duty.</li>
      <li>Safety induction and your first <strong>crew drill happen within 24 hours</strong> — attendance is law, not choice.</li>
      <li>Learn your <strong>emergency duty</strong> from the muster list; it's your most important job on board.</li>
      <li>First days are heavy: trainings, uniform fitting, department handover. Jet lag is real — sleep when you can.</li></ul>` },
    { title: "4 · Life on board", icon: "🛏", html: `<ul>
      <li>Most crew <strong>share a cabin</strong> (2 berths typical); officers and some positions get singles.</li>
      <li>You'll eat in the <strong>crew mess</strong>; many ships also have a crew bar, gym, deck and shop.</li>
      <li>Expect <strong>7-day work weeks</strong> for the whole contract; hours vary by role (often 10–12/day).</li>
      <li>Crew Wi-Fi is discounted but limited — download offline content before you fly.</li>
      <li>Respect cabin quiet hours: your roommate may work the opposite shift.</li></ul>` },
    { title: "5 · Departments & ranks", icon: "⚓", html: `<ul>
      <li><strong>Deck</strong>: navigation, safety, security — Captain, Staff Captain, officers, bosun, AB seamen.</li>
      <li><strong>Engine</strong>: propulsion & systems — Chief Engineer, engineers, electricians, fitters.</li>
      <li><strong>Hotel</strong>: the biggest department — food & beverage, galley, housekeeping, entertainment, spa, shops, casino, guest services.</li>
      <li>Officer rank shows as <strong>stripes</strong>: four for the Captain and Chief Engineer, descending from there.</li>
      <li>The <strong>chain of command</strong> is real: requests and problems go through your supervisor first.</li></ul>` },
    { title: "6 · Safety duties", icon: "🦺", html: `<ul>
      <li>The <strong>general emergency signal</strong> is seven short blasts + one long blast — know your muster duty response.</li>
      <li>Weekly <strong>crew drills</strong> (fire, abandon ship, crowd control) are mandatory for everyone, every contract.</li>
      <li>Report hazards immediately — the ship's <strong>Safety Management System</strong> depends on it.</li>
      <li>Crew are the guests' guides in an emergency: know your routes, stations and lifejacket locations cold.</li></ul>` },
    { title: "7 · Pay & your rights", icon: "🧾", html: `<ul>
      <li>Salaries are usually in <strong>USD</strong>, tax rules depend on your home country; many roles are tips-supplemented.</li>
      <li>The <strong>Maritime Labour Convention (MLC)</strong> guarantees minimum rest: at least 10 hours rest in any 24, and 77 hours per week.</li>
      <li>Your contract must state wages, hours, notice and repatriation — <strong>read it before signing</strong>.</li>
      <li>The <strong>ITF</strong> (International Transport Workers' Federation) helps seafarers with unpaid wages or unfair treatment.</li>
      <li>Send money home via the ship's payroll options or low-fee transfer services; avoid carrying large cash.</li></ul>` },
  ],

  checklists: {
    guest: [
      { group: "Documents", items: ["Passport / ID", "Cruise boarding documents", "Travel insurance papers", "Credit cards & some cash", "Printed excursion tickets"] },
      { group: "Essentials", items: ["Medications (in carry-on!)", "Sunscreen & after-sun", "Sunglasses & hat", "Seasickness remedies", "Lanyard for cruise card", "Magnetic hooks", "Reusable water bottle", "Non-surge power strip / USB hub"] },
      { group: "Clothing", items: ["Formal night outfit", "Swimwear (pack 2)", "Comfortable walking shoes", "Light jacket for deck", "Day bag for ports"] },
    ],
    crew: [
      { group: "Documents", items: ["Passport (6+ months valid)", "Seafarer's book (if issued)", "STCW certificates", "Medical certificate (ENG1 etc.)", "Visas (C1/D etc.)", "Contract / Letter of Employment", "Extra passport photos"] },
      { group: "Work life", items: ["Black work shoes (non-slip)", "Watch with alarm", "Power strip / USB hub", "Universal adapter", "Padlock for locker", "Highlighters & pens for trainings"] },
      { group: "Cabin comfort", items: ["Earplugs & sleep mask", "Shower slippers", "Offline movies/music downloaded", "Photos from home", "Snacks from home", "Small first-aid kit"] },
    ],
  },

  glossary: [
    ["Aft", "The rear section of the ship.", "ship"],
    ["All aboard time", "Deadline to be back on board in port, usually 30–60 min before sailing. The ship will not wait!", "onboard"],
    ["Berth", "A bed on a ship, or the dock space where a ship parks.", "ship"],
    ["Bosun", "Senior deck crew member supervising sailors and deck maintenance.", "crew"],
    ["Bow", "The front of the ship.", "ship"],
    ["Bridge", "The command center from which the ship is navigated.", "ship"],
    ["C1/D visa", "US visa combination required for crew joining or working on ships calling at US ports.", "crew"],
    ["Cabin / Stateroom", "Your room on board.", "onboard"],
    ["Crew mess", "The crew's own dining room.", "crew"],
    ["Cruise card", "Your room key, onboard wallet and ID in one card.", "onboard"],
    ["Disembarkation", "Leaving the ship at the end of the voyage.", "onboard"],
    ["Draft", "How deep the ship sits below the waterline.", "ship"],
    ["Embarkation", "Boarding the ship on day one.", "onboard"],
    ["ENG1", "The UK seafarer medical certificate; other flag states have equivalents.", "crew"],
    ["Galley", "The ship's kitchen.", "ship"],
    ["Gangway", "The ramp or stairs used to get on and off the ship.", "ship"],
    ["General emergency signal", "Seven short blasts + one long blast on the ship's whistle and alarms.", "safety"],
    ["Gross tonnage", "A measure of a ship's total enclosed volume (not weight).", "ship"],
    ["Guarantee cabin", "Discounted booking where the line picks your exact cabin.", "onboard"],
    ["ITF", "International Transport Workers' Federation — the union federation that assists seafarers.", "crew"],
    ["Knot", "Speed at sea: 1 knot = 1.852 km/h (1.15 mph).", "ship"],
    ["Lido deck", "The pool deck, usually with casual buffet dining.", "onboard"],
    ["MLC", "Maritime Labour Convention — the 'seafarers' bill of rights': rest hours, contracts, repatriation.", "crew"],
    ["Muster drill", "Mandatory safety briefing before sailing, at your muster station.", "safety"],
    ["Muster list", "The ship's master document assigning every crew member an emergency duty.", "safety"],
    ["Muster station", "Your assigned emergency assembly point.", "safety"],
    ["Port (side)", "The left side of the ship facing forward. Tip: 'port' and 'left' both have four letters.", "ship"],
    ["Port agent", "The ship's local representative in each port — the number to call if you're stranded ashore.", "onboard"],
    ["Port of call", "A destination where the ship stops.", "onboard"],
    ["Purser", "Officer in charge of accounts and administration — today usually Guest Services.", "crew"],
    ["Repositioning cruise", "One-way voyage moving a ship between regions; longer and often cheaper.", "onboard"],
    ["Sea day", "A full day at sea with no port stop.", "onboard"],
    ["Ship time", "The time zone the ship runs on — may differ from the port. Always follow ship time.", "onboard"],
    ["Shore excursion", "A guided tour or activity booked at a port of call.", "onboard"],
    ["Sign-on / Sign-off", "Officially joining or leaving a ship's crew, recorded in ship's articles.", "crew"],
    ["Starboard", "The right side of the ship facing forward.", "ship"],
    ["STCW", "Standards of Training, Certification and Watchkeeping — the mandatory basic safety training for all seafarers.", "crew"],
    ["Stern", "The rearmost part of the ship.", "ship"],
    ["Tender", "Small boat shuttling passengers ashore when the ship anchors off the coast.", "ship"],
    ["Watch", "A crew duty shift, e.g. the 4–8 navigation watch on the bridge.", "crew"],
  ],

  quiz: [
    { q: "Which side of the ship is 'starboard'?", a: ["Right side facing forward", "Left side facing forward", "The rear", "The side facing the port"], correct: 0 },
    { q: "What is a 'tender'?", a: ["A small boat taking guests ashore", "The ship's kitchen", "A junior officer", "A type of cabin"], correct: 0 },
    { q: "The general emergency signal is…", a: ["Seven short blasts + one long", "Three long blasts", "One short blast", "A continuous siren only"], correct: 0 },
    { q: "The ship departs at 17:00. All aboard time is most likely…", a: ["16:00–16:30", "17:00 sharp", "18:00", "Whenever you're back"], correct: 0 },
    { q: "'Ship time' means…", a: ["The time zone the ship runs on — follow it always", "Local time in every port", "The captain's watch", "Time until departure"], correct: 0 },
    { q: "STCW is…", a: ["Mandatory basic safety training for seafarers", "A type of visa", "A cruise loyalty program", "A deck on the ship"], correct: 0 },
    { q: "A legitimate cruise ship recruiter will…", a: ["Never charge you a fee for the job", "Ask a small registration fee", "Ask you to pay for a 'guaranteed' position", "Only contact you on WhatsApp"], correct: 0 },
    { q: "Under MLC rules, crew must get at least…", a: ["10 hours rest in any 24-hour period", "2 days off per week", "8 hours rest per week", "No minimum — it's the captain's call"], correct: 0 },
    { q: "Your medications should travel…", a: ["In your carry-on bag", "In your checked suitcase", "In your cabin minibar", "Mailed to the ship"], correct: 0 },
    { q: "One knot equals…", a: ["1.852 km/h", "1 km/h", "10 km/h", "1 mile per minute"], correct: 0 },
  ],

  verdicts: [
    [10, "⚓ Officer material — welcome aboard!"],
    [8, "🚢 Seasoned sailor — you know your ship."],
    [5, "🌊 Promising deckhand — one more read of the guides."],
    [0, "🦀 Landlubber (for now) — the Academy awaits you!"],
  ],
},

/* ================================================================ ID */
id: {
  ui: {
    navHome: "Beranda", navGuest: "Panduan Tamu", navCrew: "Panduan Kru", navTools: "Alat",
    navGlossary: "Glosarium", navQuiz: "Kuis",
    heroTitle: "Teman setiamu di lautan.",
    heroSub: "Panduan, checklist, dan alat untuk <strong>tamu</strong> dan <strong>kru</strong> kapal pesiar — gratis, bisa offline, tanpa instal apa pun.",
    guestCardTitle: "Saya Tamu",
    guestCardDesc: "Pelayaran pertama atau kelima puluh — berlayar dengan siap, dari booking sampai turun kapal.",
    crewCardTitle: "Saya Kru",
    crewCardDesc: "Cara diterima kerja, naik kapal, kehidupan di atas kapal, dan hak-hakmu di laut.",
    chipCountdown: "⏳ Hitung mundur", chipChecklists: "✅ Checklist", chipTip: "💵 Kalkulator tip",
    chipGlossary: "📖 40+ istilah kapal", chipQuiz: "🎓 Kuis siap berlayar",
    guestTitle: "🧳 Panduan Tamu",
    guestLead: "Semua yang dibutuhkan tamu kapal pesiar, urut sesuai perjalanan. Ketuk untuk membuka.",
    crewTitle: "⚓ Panduan Kru",
    crewLead: "Dari melamar sampai sign-off — beginilah kerja di laut yang sebenarnya.",
    toolsTitle: "🛠 Alat",
    cdTitle: "⏳ Hitung mundur", cdWhat: "Menghitung mundur untuk apa?",
    cdPlaceholder: "Pelayaranku / Tanggal sign-on", cdDate: "Tanggal", cdStart: "Mulai hitung mundur",
    cdChange: "Ubah", cdDays: "hari lagi", cdDay: "hari lagi",
    cdSailing: "Bon voyage — kamu sedang berlayar!", cdDone: "Pelayaran selesai — pasang tanggal berikutnya!",
    clTitle: "✅ Checklist bawaan", clGuest: "Tamu", clCrew: "Kru", clPacked: "sudah dikemas",
    tipTitle: "💵 Kalkulator gratuity", tipGuests: "Jumlah tamu", tipNights: "Malam",
    tipRate: "Gratuity harian per orang ($)", tipService: "Gratuity layanan:",
    tipBarBill: "Tagihan bar ($)", tipBarPct: "Auto-gratuity %", tipBar: "Gratuity bar:",
    tipNote: "Tarif umum 2026: $15–$20 per orang per hari; auto-gratuity bar 18–20%. Cek cruise line-mu.",
    cvTitle: "🌊 Konversi maritim", cvSpeed: "Kecepatan", cvDist: "Jarak",
    cvDepth: "Kedalaman / tinggi", cvTemp: "Suhu",
    cvKnotsPh: "knot", cvNmPh: "mil laut", cvMPh: "meter", cvCPh: "°C",
    glTitle: "📖 Glosarium Kapal Pesiar & Maritim",
    glSearchPh: "Cari istilah… (mis. muster, tender, STCW)", glNone: "Istilah tidak ditemukan.",
    quizTitle: "🎓 Sudah siap berlayar?",
    quizIntro: "10 pertanyaan dari Academy. Tamu dan kru boleh ikut — tak perlu seragam.",
    quizStart: "Mulai kuis", quizAgain: "Coba lagi",
    quizProgress: "Pertanyaan {n} dari {total} · Skor {score}",
    footerTag: "— belajar cara-cara lautan.",
    footerNote: "Panduan umum saja — selalu ikuti instruksi cruise line dan komando kapal. Konten bisa offline; checklist dan hitung mundurmu tersimpan di perangkat ini saja.",
  },

  glCats: { all: "Semua", ship: "Kapal & laut", onboard: "Di kapal", crew: "Kru & kerja", safety: "Keselamatan" },

  guestGuide: [
    { title: "1 · Sebelum berlayar", icon: "🗓", html: `<ul>
      <li><strong>Paspor</strong> harus berlaku minimal 6 bulan setelah tanggal pulang; cek aturan visa setiap negara pelabuhan.</li>
      <li><strong>Asuransi perjalanan</strong> dengan perlindungan evakuasi medis — perawatan medis di kapal dan evakuasi itu mahal.</li>
      <li><strong>Datang sehari lebih awal</strong> di kota keberangkatan. Pesawat delay di hari embarkasi bisa berarti ketinggalan kapal.</li>
      <li>Selesaikan <strong>check-in online</strong> dan cetak/simpan dokumen boarding serta label bagasi.</li>
      <li>Pesan <strong>shore excursion dan restoran spesial</strong> yang populer sebelum berlayar — cepat habis.</li></ul>` },
    { title: "2 · Hari embarkasi", icon: "🛳", html: `<ul>
      <li>Siapkan <strong>tas jinjing</strong> berisi dokumen, obat, barang berharga, dan baju renang — koper bisa berjam-jam baru sampai kabin.</li>
      <li><strong>Cruise card</strong> adalah kunci kamar, dompet, dan identitasmu — bawa selalu (pakai lanyard lebih praktis).</li>
      <li>Kabin biasanya siap awal siang; makan siang di buffet sambil menunggu.</li>
      <li><strong>Muster drill</strong> (pengarahan keselamatan) itu wajib — selesaikan lebih awal lewat aplikasi atau di muster station.</li>
      <li>Naik kapal sebelum <strong>all-aboard time</strong> yang tertera di dokumen — kapal berangkat tanpa yang terlambat.</li></ul>` },
    { title: "3 · Kehidupan di kapal", icon: "🍽", html: `<ul>
      <li>Kapal memakai <strong>ship time</strong>, yang bisa berbeda dari waktu pelabuhan. Selalu ikuti ship time.</li>
      <li>Main dining room, buffet, dan venue kasual sudah termasuk; <strong>restoran spesial</strong> bayar ekstra.</li>
      <li>Cek <strong>program harian</strong> (kertas atau aplikasi) setiap malam dan rencanakan hari berikutnya.</li>
      <li>Semua transaksi masuk <strong>akun onboard</strong> lewat cruise card — periksa setiap beberapa hari.</li>
      <li>Wi-Fi di laut memakai satelit: lebih lambat dan mahal daripada di darat. Beli paket lebih awal untuk diskon.</li>
      <li>Dress code: kebanyakan malam kasual; <strong>formal night</strong> biasanya sekali seminggu — pakaian rapi sudah cukup.</li></ul>` },
    { title: "4 · Hari di pelabuhan", icon: "🏝", html: `<ul>
      <li>Catat <strong>all-aboard time</strong> — biasanya 30–60 menit sebelum berlayar. Kapal tidak menunggu wisatawan mandiri.</li>
      <li><strong>Excursion resmi kapal dijamin</strong> ditunggu bila tur telat; jalan sendiri lebih murah tapi risikonya milikmu.</li>
      <li>Beberapa pelabuhan memakai <strong>tender</strong> (perahu kecil) — sediakan waktu ekstra untuk ke darat dan kembali.</li>
      <li>Bawa cruise card, kartu identitas, uang kecil mata uang lokal, dan <strong>kontak port agent</strong> dari program harian.</li></ul>` },
    { title: "5 · Uang & tip", icon: "💵", html: `<ul>
      <li>Kebanyakan cruise line menambahkan <strong>gratuity harian</strong> (sekitar $15–$20 per orang per hari) ke akunmu — pakai kalkulator di menu Alat.</li>
      <li>Bar menambahkan <strong>gratuity otomatis 18–20%</strong> di setiap pesanan.</li>
      <li><strong>Paket minuman</strong> biasanya baru untung mulai ~5–6 gelas per hari — hitung dulu sebelum beli.</li>
      <li>Tip tunai tambahan untuk cabin steward atau pelayan dihargai tapi tidak wajib.</li></ul>` },
    { title: "6 · Kesehatan & keselamatan", icon: "⛑", html: `<ul>
      <li>Gampang mabuk laut? Pilih <strong>kabin tengah kapal di dek bawah</strong>; koyo anti-mabuk paling efektif dipakai sebelum mual.</li>
      <li><strong>Cuci tangan</strong> sering dan pakai hand sanitizer — pertahanan terbaik dari virus perut di laut.</li>
      <li>Hafalkan <strong>muster station</strong>-mu (tertera di pintu kabin dan cruise card).</li>
      <li><strong>Medical center</strong> bisa menangani kebanyakan masalah; berbayar — satu lagi alasan punya asuransi.</li></ul>` },
    { title: "7 · Turun kapal", icon: "🧾", html: `<ul>
      <li>Selesaikan <strong>akun onboard</strong> malam sebelumnya; cek tagihan yang aneh.</li>
      <li><strong>Self-assist</strong>: bawa koper sendiri dan turun paling awal. Kalau tidak, koper ditaruh di depan kabin malam sebelumnya dan diambil di terminal.</li>
      <li>Dokumen, obat, dan barang berharga <strong>tetap dibawa sendiri</strong>, bukan di koper.</li>
      <li>Jangan pesan penerbangan sebelum ~tengah hari — proses turun kapal dan bea cukai butuh waktu.</li></ul>` },
  ],

  crewGuide: [
    { title: "1 · Cara diterima kerja", icon: "📋", html: `<ul>
      <li>Lamar langsung di situs karier cruise line atau lewat <strong>agen perekrutan resmi</strong> yang tercantum di sana.</li>
      <li><strong>⚠️ Jangan pernah membayar siapa pun untuk dapat kerja di kapal pesiar.</strong> Perekrut resmi tidak memungut biaya "pendaftaran" atau "jaminan" — itu penipuan #1.</li>
      <li>Kontrak biasanya <strong>4–9 bulan</strong> tergantung departemen dan jabatan, lalu libur ~2 bulan.</li>
      <li>Siapkan wawancara video dan tes bahasa Inggris; posisi hotel juga dites skenario pelayanan.</li></ul>` },
    { title: "2 · Dokumen & pelatihan", icon: "🎓", html: `<ul>
      <li><strong>STCW Basic Safety Training</strong> wajib untuk semua pelaut: pemadaman kebakaran, bertahan di laut, P3K, keselamatan diri.</li>
      <li>Wajib punya <strong>sertifikat medis pelaut</strong> yang berlaku (mis. ENG1 atau setara dari negara bendera).</li>
      <li>Rute AS butuh <strong>visa kru C1/D</strong>; wilayah lain punya aturan sendiri — perusahaan akan memberi tahu.</li>
      <li>Pastikan paspor, medis, STCW, dan sertifikat vaksin berlaku selama <strong>seluruh kontrak plus 6 bulan</strong>.</li>
      <li>Perusahaan biasanya memesan dan membayar <strong>tiket pesawat ke kapal</strong>.</li></ul>` },
    { title: "3 · Naik kapal (sign-on)", icon: "🚢", html: `<ul>
      <li>Di gangway kamu akan <strong>sign on</strong>: kartu ID kru, pembagian kabin, nomor keselamatan, dan tugas muster.</li>
      <li>Induksi keselamatan dan <strong>drill kru pertama dilakukan dalam 24 jam</strong> — hadir itu hukum, bukan pilihan.</li>
      <li>Pelajari <strong>tugas daruratmu</strong> dari muster list; itu pekerjaan terpentingmu di kapal.</li>
      <li>Hari-hari pertama padat: pelatihan, ukur seragam, serah terima. Jet lag itu nyata — tidurlah kapan pun bisa.</li></ul>` },
    { title: "4 · Kehidupan di kapal", icon: "🛏", html: `<ul>
      <li>Kebanyakan kru <strong>berbagi kabin</strong> (umumnya 2 orang); perwira dan beberapa posisi dapat kamar sendiri.</li>
      <li>Makan di <strong>crew mess</strong>; banyak kapal juga punya crew bar, gym, dek, dan toko khusus kru.</li>
      <li>Siap-siap <strong>kerja 7 hari seminggu</strong> sepanjang kontrak; jam kerja tergantung posisi (sering 10–12 jam/hari).</li>
      <li>Wi-Fi kru diskon tapi terbatas — unduh konten offline sebelum terbang.</li>
      <li>Hormati jam tenang kabin: teman sekamarmu mungkin kerja shift berlawanan.</li></ul>` },
    { title: "5 · Departemen & jabatan", icon: "⚓", html: `<ul>
      <li><strong>Deck</strong>: navigasi, keselamatan, keamanan — Kapten, Staff Captain, perwira, bosun, AB seaman.</li>
      <li><strong>Engine</strong>: mesin & sistem — Chief Engineer, engineer, teknisi listrik, fitter.</li>
      <li><strong>Hotel</strong>: departemen terbesar — food & beverage, galley, housekeeping, hiburan, spa, toko, kasino, guest services.</li>
      <li>Pangkat perwira ditunjukkan lewat <strong>strip</strong>: empat untuk Kapten dan Chief Engineer, menurun dari situ.</li>
      <li><strong>Rantai komando</strong> itu nyata: permintaan dan masalah lewat atasanmu dulu.</li></ul>` },
    { title: "6 · Tugas keselamatan", icon: "🦺", html: `<ul>
      <li><strong>Sinyal darurat umum</strong> adalah tujuh tiup pendek + satu tiup panjang — hafalkan respons tugas muster-mu.</li>
      <li><strong>Drill kru mingguan</strong> (kebakaran, tinggalkan kapal, kendali kerumunan) wajib untuk semua, setiap kontrak.</li>
      <li>Laporkan bahaya segera — <strong>Safety Management System</strong> kapal bergantung padanya.</li>
      <li>Kru adalah pemandu tamu saat darurat: hafalkan rute, station, dan lokasi pelampung di luar kepala.</li></ul>` },
    { title: "7 · Gaji & hak-hakmu", icon: "🧾", html: `<ul>
      <li>Gaji biasanya dalam <strong>USD</strong>, aturan pajak tergantung negara asal; banyak posisi ditambah tip.</li>
      <li><strong>Maritime Labour Convention (MLC)</strong> menjamin istirahat minimum: 10 jam per 24 jam, dan 77 jam per minggu.</li>
      <li>Kontrak harus mencantumkan gaji, jam kerja, pemberitahuan, dan repatriasi — <strong>baca sebelum tanda tangan</strong>.</li>
      <li><strong>ITF</strong> (International Transport Workers' Federation) membantu pelaut soal gaji tak dibayar atau perlakuan tak adil.</li>
      <li>Kirim uang ke rumah lewat opsi payroll kapal atau layanan transfer murah; hindari bawa uang tunai banyak.</li></ul>` },
  ],

  checklists: {
    guest: [
      { group: "Dokumen", items: ["Paspor / KTP", "Dokumen boarding kapal", "Berkas asuransi perjalanan", "Kartu kredit & uang tunai", "Tiket excursion tercetak"] },
      { group: "Penting", items: ["Obat-obatan (di tas jinjing!)", "Sunscreen & after-sun", "Kacamata hitam & topi", "Obat mabuk laut", "Lanyard untuk cruise card", "Kait magnet", "Botol minum isi ulang", "Stop kontak tanpa surge / hub USB"] },
      { group: "Pakaian", items: ["Baju formal night", "Baju renang (bawa 2)", "Sepatu jalan yang nyaman", "Jaket tipis untuk dek", "Tas kecil untuk pelabuhan"] },
    ],
    crew: [
      { group: "Dokumen", items: ["Paspor (berlaku 6+ bulan)", "Buku pelaut (jika ada)", "Sertifikat STCW", "Sertifikat medis (ENG1 dll.)", "Visa (C1/D dll.)", "Kontrak / Letter of Employment", "Pas foto cadangan"] },
      { group: "Kerja", items: ["Sepatu kerja hitam (anti selip)", "Jam tangan dengan alarm", "Stop kontak / hub USB", "Adaptor universal", "Gembok untuk loker", "Stabilo & pulpen untuk pelatihan"] },
      { group: "Kenyamanan kabin", items: ["Penyumbat telinga & penutup mata", "Sandal kamar mandi", "Film/musik offline sudah diunduh", "Foto keluarga", "Camilan dari rumah", "Kotak P3K kecil"] },
    ],
  },

  glossary: [
    ["Aft", "Bagian belakang kapal.", "ship"],
    ["All aboard time", "Batas waktu kembali ke kapal di pelabuhan, biasanya 30–60 menit sebelum berlayar. Kapal tidak menunggu!", "onboard"],
    ["Berth", "Tempat tidur di kapal, atau tempat sandar kapal di dermaga.", "ship"],
    ["Bosun", "Kru dek senior yang mengawasi pelaut dan perawatan dek.", "crew"],
    ["Bow", "Bagian depan kapal (haluan).", "ship"],
    ["Bridge", "Anjungan — pusat komando tempat kapal dinavigasikan.", "ship"],
    ["C1/D visa", "Kombinasi visa AS yang wajib bagi kru yang bekerja di kapal yang singgah di pelabuhan AS.", "crew"],
    ["Cabin / Stateroom", "Kamarmu di kapal.", "onboard"],
    ["Crew mess", "Ruang makan khusus kru.", "crew"],
    ["Cruise card", "Kunci kamar, dompet onboard, dan kartu identitas dalam satu kartu.", "onboard"],
    ["Disembarkation", "Turun dari kapal di akhir pelayaran.", "onboard"],
    ["Draft", "Kedalaman kapal di bawah garis air.", "ship"],
    ["Embarkation", "Naik kapal di hari pertama.", "onboard"],
    ["ENG1", "Sertifikat medis pelaut Inggris; negara bendera lain punya padanannya.", "crew"],
    ["Galley", "Dapur kapal.", "ship"],
    ["Gangway", "Tangga atau jembatan untuk naik-turun kapal.", "ship"],
    ["General emergency signal", "Tujuh tiup pendek + satu tiup panjang pada peluit dan alarm kapal.", "safety"],
    ["Gross tonnage", "Ukuran volume tertutup total kapal (bukan berat).", "ship"],
    ["Guarantee cabin", "Booking diskon di mana cruise line yang memilih kabin persisnya.", "onboard"],
    ["ITF", "International Transport Workers' Federation — federasi serikat yang membantu pelaut.", "crew"],
    ["Knot", "Kecepatan di laut: 1 knot = 1,852 km/jam (1,15 mph).", "ship"],
    ["Lido deck", "Dek kolam renang, biasanya dengan buffet kasual.", "onboard"],
    ["MLC", "Maritime Labour Convention — 'undang-undang hak pelaut': jam istirahat, kontrak, repatriasi.", "crew"],
    ["Muster drill", "Pengarahan keselamatan wajib sebelum berlayar, di muster station-mu.", "safety"],
    ["Muster list", "Dokumen induk kapal yang memberi setiap kru tugas darurat.", "safety"],
    ["Muster station", "Titik kumpul daruratmu yang sudah ditentukan.", "safety"],
    ["Port (side)", "Sisi kiri kapal menghadap ke depan. Tips: 'port' dan 'left' sama-sama empat huruf.", "ship"],
    ["Port agent", "Perwakilan lokal kapal di tiap pelabuhan — nomor yang dihubungi kalau tertinggal di darat.", "onboard"],
    ["Port of call", "Destinasi tempat kapal singgah.", "onboard"],
    ["Purser", "Perwira urusan keuangan dan administrasi — sekarang biasanya Guest Services.", "crew"],
    ["Repositioning cruise", "Pelayaran satu arah memindahkan kapal antar wilayah; lebih lama dan sering lebih murah.", "onboard"],
    ["Sea day", "Hari penuh di laut tanpa singgah pelabuhan.", "onboard"],
    ["Ship time", "Zona waktu yang dipakai kapal — bisa berbeda dari pelabuhan. Selalu ikuti ship time.", "onboard"],
    ["Shore excursion", "Tur atau aktivitas berpemandu yang dipesan di pelabuhan singgah.", "onboard"],
    ["Sign-on / Sign-off", "Resmi bergabung atau meninggalkan kru kapal, tercatat di dokumen kapal.", "crew"],
    ["Starboard", "Sisi kanan kapal menghadap ke depan.", "ship"],
    ["STCW", "Standards of Training, Certification and Watchkeeping — pelatihan keselamatan dasar wajib semua pelaut.", "crew"],
    ["Stern", "Bagian paling belakang kapal (buritan).", "ship"],
    ["Tender", "Perahu kecil pengantar penumpang ke darat saat kapal lego jangkar di lepas pantai.", "ship"],
    ["Watch", "Shift jaga kru, mis. jaga navigasi 4–8 di anjungan.", "crew"],
  ],

  quiz: [
    { q: "Sisi kapal yang disebut 'starboard' adalah…", a: ["Sisi kanan menghadap ke depan", "Sisi kiri menghadap ke depan", "Bagian belakang", "Sisi yang menghadap pelabuhan"], correct: 0 },
    { q: "Apa itu 'tender'?", a: ["Perahu kecil pengantar tamu ke darat", "Dapur kapal", "Perwira junior", "Jenis kabin"], correct: 0 },
    { q: "Sinyal darurat umum adalah…", a: ["Tujuh tiup pendek + satu panjang", "Tiga tiup panjang", "Satu tiup pendek", "Hanya sirene terus-menerus"], correct: 0 },
    { q: "Kapal berangkat pukul 17:00. All aboard time kemungkinan besar…", a: ["16:00–16:30", "Tepat 17:00", "18:00", "Kapan pun kamu kembali"], correct: 0 },
    { q: "'Ship time' artinya…", a: ["Zona waktu yang dipakai kapal — selalu diikuti", "Waktu lokal di setiap pelabuhan", "Jam tangan kapten", "Waktu sampai keberangkatan"], correct: 0 },
    { q: "STCW adalah…", a: ["Pelatihan keselamatan dasar wajib untuk pelaut", "Jenis visa", "Program loyalitas kapal pesiar", "Nama dek di kapal"], correct: 0 },
    { q: "Perekrut kapal pesiar yang resmi akan…", a: ["Tidak pernah memungut biaya untuk pekerjaan", "Minta biaya pendaftaran kecil", "Minta bayaran untuk posisi 'terjamin'", "Hanya menghubungi lewat WhatsApp"], correct: 0 },
    { q: "Menurut aturan MLC, kru minimal mendapat…", a: ["Istirahat 10 jam dalam tiap 24 jam", "Libur 2 hari per minggu", "Istirahat 8 jam per minggu", "Tidak ada minimum — terserah kapten"], correct: 0 },
    { q: "Obat-obatanmu sebaiknya dibawa…", a: ["Di tas jinjing", "Di koper bagasi", "Di minibar kabin", "Dikirim pos ke kapal"], correct: 0 },
    { q: "Satu knot sama dengan…", a: ["1,852 km/jam", "1 km/jam", "10 km/jam", "1 mil per menit"], correct: 0 },
  ],

  verdicts: [
    [10, "⚓ Calon perwira — selamat datang di kapal!"],
    [8, "🚢 Pelaut berpengalaman — kamu paham kapalmu."],
    [5, "🌊 Kelasi menjanjikan — baca panduannya sekali lagi."],
    [0, "🦀 Anak darat (untuk sekarang) — Academy menantimu!"],
  ],
},
};
