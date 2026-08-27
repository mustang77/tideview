// data.js — all content for the Companion. Edit freely: every guide step,
// checklist item, glossary term and quiz question lives here.

/* ---------------- Guest guide ---------------- */
const GUEST_GUIDE = [
  {
    title: "1 · Before you sail",
    icon: "🗓",
    html: `
      <ul>
        <li><strong>Passport</strong> valid at least 6 months beyond your return date; check visa rules for every port country.</li>
        <li><strong>Travel insurance</strong> with medical evacuation cover — ship medical care and evacuations are expensive.</li>
        <li><strong>Arrive one day early</strong> in your departure city. A delayed flight on embarkation day can mean missing the ship.</li>
        <li>Complete <strong>online check-in</strong> and print/save your boarding documents and luggage tags.</li>
        <li>Book popular <strong>shore excursions and specialty dining</strong> before you sail — they sell out.</li>
      </ul>`,
  },
  {
    title: "2 · Embarkation day",
    icon: "🛳",
    html: `
      <ul>
        <li>Pack a <strong>carry-on</strong> with documents, medications, valuables and swimwear — checked bags can take hours to reach your cabin.</li>
        <li>Your <strong>cruise card</strong> is your room key, onboard wallet and ID — keep it on you always (a lanyard helps).</li>
        <li>Cabins are usually ready early afternoon; lunch at the buffet while you wait.</li>
        <li>The <strong>muster drill</strong> (safety briefing) is mandatory — complete it early via the app or at your muster station.</li>
        <li>Be on board by the <strong>all-aboard time</strong> printed on your documents — the ship sails without latecomers.</li>
      </ul>`,
  },
  {
    title: "3 · Life on board",
    icon: "🍽",
    html: `
      <ul>
        <li>Ships run on <strong>ship time</strong>, which may differ from local port time. Always follow ship time.</li>
        <li>Main dining room, buffet and casual venues are included; <strong>specialty restaurants</strong> cost extra.</li>
        <li>Check the <strong>daily program</strong> (paper or app) each evening and plan your next day.</li>
        <li>Everything is charged to your <strong>onboard account</strong> via cruise card — review it every couple of days.</li>
        <li>Wi-Fi at sea is satellite-based: slower and pricier than on land. Buy packages early for discounts.</li>
        <li>Dress codes: most nights are casual; <strong>formal night</strong> is usually once per week — a nice outfit is enough.</li>
      </ul>`,
  },
  {
    title: "4 · Port days",
    icon: "🏝",
    html: `
      <ul>
        <li>Note the <strong>all-aboard time</strong> — typically 30–60 minutes before sailing. The ship will not wait for independent travelers.</li>
        <li>Ship-sold <strong>excursions guarantee</strong> the ship waits if the tour runs late; going independent is cheaper but the risk is yours.</li>
        <li>Some ports use <strong>tenders</strong> (small boats) — allow extra time to get ashore and back.</li>
        <li>Carry your cruise card, a photo ID, small bills in local currency, and the ship's <strong>port agent contact</strong> from the daily program.</li>
      </ul>`,
  },
  {
    title: "5 · Money & tipping",
    icon: "💵",
    html: `
      <ul>
        <li>Most lines add <strong>daily service gratuities</strong> (about $15–$20 per person per day) to your account — use our calculator in Tools.</li>
        <li>Bars add an <strong>automatic 18–20% gratuity</strong> to each order.</li>
        <li><strong>Drink packages</strong> usually pay off from ~5–6 drinks per day — do the math before buying.</li>
        <li>Extra cash tips for your cabin steward or waiter are appreciated but optional.</li>
      </ul>`,
  },
  {
    title: "6 · Health & safety",
    icon: "⛑",
    html: `
      <ul>
        <li>Prone to motion sickness? Choose a <strong>midship cabin on a lower deck</strong>; patches work best applied before you feel ill.</li>
        <li><strong>Wash hands</strong> often and use sanitizer stations — it's the best defense against stomach bugs at sea.</li>
        <li>Know your <strong>muster station</strong> (printed on your cabin door and cruise card).</li>
        <li>The <strong>medical center</strong> can treat most issues; fees apply — another reason for travel insurance.</li>
      </ul>`,
  },
  {
    title: "7 · Disembarkation",
    icon: "🧾",
    html: `
      <ul>
        <li>Settle your <strong>onboard account</strong> the night before; check for surprise charges.</li>
        <li><strong>Self-assist</strong>: carry your own bags and walk off first. Otherwise, bags go outside your cabin the night before and you collect them in the terminal.</li>
        <li>Keep documents, medication and valuables <strong>with you</strong>, not in checked bags.</li>
        <li>Don't book flights before ~noon — disembarkation and customs take time.</li>
      </ul>`,
  },
];

/* ---------------- Crew guide ---------------- */
const CREW_GUIDE = [
  {
    title: "1 · Getting hired",
    icon: "📋",
    html: `
      <ul>
        <li>Apply directly on cruise line career sites or via <strong>official hiring partners</strong> listed there.</li>
        <li><strong>⚠️ Never pay anyone to get a cruise ship job.</strong> Legitimate recruiters don't charge "registration" or "guarantee" fees — that's the #1 scam.</li>
        <li>Contracts typically run <strong>4–9 months</strong> depending on department and rank, followed by ~2 months vacation.</li>
        <li>Expect video interviews and English assessments; hotel roles also test service scenarios.</li>
      </ul>`,
  },
  {
    title: "2 · Documents & training",
    icon: "🎓",
    html: `
      <ul>
        <li><strong>STCW Basic Safety Training</strong> is mandatory for all seafarers: firefighting, sea survival, first aid, personal safety.</li>
        <li>A valid <strong>seafarer medical certificate</strong> (e.g. ENG1 or your flag state's equivalent) is required.</li>
        <li>US itineraries need a <strong>C1/D crew visa</strong>; other regions have their own rules — the company will tell you which.</li>
        <li>Keep passport, medical, STCW and vaccination certificates valid for your <strong>whole contract plus 6 months</strong>.</li>
        <li>The company usually books and pays your <strong>flights to the ship</strong>.</li>
      </ul>`,
  },
  {
    title: "3 · Joining the ship",
    icon: "🚢",
    html: `
      <ul>
        <li>At the gangway you'll <strong>sign on</strong>: crew ID card, cabin assignment, safety number and muster duty.</li>
        <li>Safety induction and your first <strong>crew drill happen within 24 hours</strong> — attendance is law, not choice.</li>
        <li>Learn your <strong>emergency duty</strong> from the muster list; it's your most important job on board.</li>
        <li>First days are heavy: trainings, uniform fitting, department handover. Jet lag is real — sleep when you can.</li>
      </ul>`,
  },
  {
    title: "4 · Life on board",
    icon: "🛏",
    html: `
      <ul>
        <li>Most crew <strong>share a cabin</strong> (2 berths typical); officers and some positions get singles.</li>
        <li>You'll eat in the <strong>crew mess</strong>; many ships also have a crew bar, gym, deck and shop.</li>
        <li>Expect <strong>7-day work weeks</strong> for the whole contract; hours vary by role (often 10–12/day).</li>
        <li>Crew Wi-Fi is discounted but limited — download offline content before you fly.</li>
        <li>Respect cabin quiet hours: your roommate may work the opposite shift.</li>
      </ul>`,
  },
  {
    title: "5 · Departments & ranks",
    icon: "⚓",
    html: `
      <ul>
        <li><strong>Deck</strong>: navigation, safety, security — Captain, Staff Captain, officers, bosun, AB seamen.</li>
        <li><strong>Engine</strong>: propulsion & systems — Chief Engineer, engineers, electricians, fitters.</li>
        <li><strong>Hotel</strong>: the biggest department — food & beverage, galley, housekeeping, entertainment, spa, shops, casino, guest services.</li>
        <li>Officer rank shows as <strong>stripes</strong>: four for the Captain and Chief Engineer, descending from there.</li>
        <li>The <strong>chain of command</strong> is real: requests and problems go through your supervisor first.</li>
      </ul>`,
  },
  {
    title: "6 · Safety duties",
    icon: "🦺",
    html: `
      <ul>
        <li>The <strong>general emergency signal</strong> is seven short blasts + one long blast — know your muster duty response.</li>
        <li>Weekly <strong>crew drills</strong> (fire, abandon ship, crowd control) are mandatory for everyone, every contract.</li>
        <li>Report hazards immediately — the ship's <strong>Safety Management System</strong> depends on it.</li>
        <li>Crew are the guests' guides in an emergency: know your routes, stations and lifejacket locations cold.</li>
      </ul>`,
  },
  {
    title: "7 · Pay & your rights",
    icon: "🧾",
    html: `
      <ul>
        <li>Salaries are usually in <strong>USD</strong>, tax rules depend on your home country; many roles are tips-supplemented.</li>
        <li>The <strong>Maritime Labour Convention (MLC)</strong> guarantees minimum rest: at least 10 hours rest in any 24, and 77 hours per week.</li>
        <li>Your contract must state wages, hours, notice and repatriation — <strong>read it before signing</strong>.</li>
        <li>The <strong>ITF</strong> (International Transport Workers' Federation) helps seafarers with unpaid wages or unfair treatment.</li>
        <li>Send money home via the ship's payroll options or low-fee transfer services; avoid carrying large cash.</li>
      </ul>`,
  },
];

/* ---------------- Checklists ---------------- */
const CHECKLISTS = {
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
};

/* ---------------- Glossary ---------------- */
// category: ship | onboard | crew | safety
const GLOSSARY = [
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
];

const GL_CATS = { all: "All", ship: "Ship & sea", onboard: "On board", crew: "Crew & work", safety: "Safety" };

/* ---------------- Quiz ---------------- */
const QUIZ = [
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
];
