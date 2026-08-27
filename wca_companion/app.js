// app.js — all behavior for the Companion.
// Persistence uses localStorage (this is a website, not an extension):
//   wca_cd       {name, date}         countdown
//   wca_checked  {guest:{}, crew:{}}  checklist progress
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];

const store = {
  get(key, fallback) {
    try { return JSON.parse(localStorage.getItem(key)) ?? fallback; }
    catch { return fallback; }
  },
  set(key, val) {
    try { localStorage.setItem(key, JSON.stringify(val)); } catch {}
  },
  del(key) { try { localStorage.removeItem(key); } catch {} },
};

/* ---------------- Navigation (hash-based views) ---------------- */
const VIEWS = ["home", "guest", "crew", "tools", "glossary", "quiz"];

function show(view) {
  if (!VIEWS.includes(view)) view = "home";
  $$(".view").forEach((v) => v.classList.toggle("active", v.id === view));
  $$("#nav a").forEach((a) => a.classList.toggle("active", a.dataset.nav === view));
  window.scrollTo(0, 0);
}

window.addEventListener("hashchange", () => show(location.hash.slice(1)));
show(location.hash.slice(1) || "home");

/* ---------------- Guides (accordion) ---------------- */
function renderGuide(el, steps) {
  el.innerHTML = steps
    .map(
      (s, i) => `
      <details ${i === 0 ? "open" : ""}>
        <summary>${s.icon} ${s.title}</summary>
        <div class="body">${s.html}</div>
      </details>`
    )
    .join("");
}
renderGuide($("#guest-guide"), GUEST_GUIDE);
renderGuide($("#crew-guide"), CREW_GUIDE);

/* ---------------- Countdown ---------------- */
function renderCountdown(data) {
  const days = Math.ceil((new Date(data.date + "T00:00") - new Date()) / 86400000);
  $("#cd-cruise-name").textContent = data.name;
  if (days > 0) {
    $("#cd-days").textContent = days;
    $("#cd-label").textContent = days === 1 ? "day to go" : "days to go";
  } else if (days > -60) {
    $("#cd-days").textContent = "🚢";
    $("#cd-label").textContent = "Bon voyage — you're sailing!";
  } else {
    $("#cd-days").textContent = "🌅";
    $("#cd-label").textContent = "Voyage complete — set the next date!";
  }
  $("#cd-setup").hidden = true;
  $("#cd-display").hidden = false;
}

const savedCd = store.get("wca_cd", null);
if (savedCd?.date) renderCountdown(savedCd);

$("#cd-save").addEventListener("click", () => {
  const date = $("#cd-date").value;
  if (!date) return;
  const data = { name: $("#cd-name").value.trim() || "My voyage", date };
  store.set("wca_cd", data);
  renderCountdown(data);
});
$("#cd-reset").addEventListener("click", () => {
  store.del("wca_cd");
  $("#cd-display").hidden = true;
  $("#cd-setup").hidden = false;
});

/* ---------------- Checklist (guest / crew) ---------------- */
let listKind = "guest";

function renderChecklist() {
  const checked = store.get("wca_checked", {})[listKind] || {};
  const groups = CHECKLISTS[listKind];
  const container = $("#cl-groups");
  container.innerHTML = "";
  let total = 0, done = 0;

  groups.forEach(({ group, items }) => {
    const div = document.createElement("div");
    div.className = "cl-group";
    div.innerHTML = `<h3>${group}</h3>`;
    items.forEach((label) => {
      total++;
      const isOn = !!checked[label];
      if (isOn) done++;
      const row = document.createElement("label");
      row.className = "cl-item" + (isOn ? " checked" : "");
      const box = document.createElement("input");
      box.type = "checkbox";
      box.checked = isOn;
      box.addEventListener("change", () => {
        const all = store.get("wca_checked", {});
        all[listKind] = all[listKind] || {};
        if (box.checked) all[listKind][label] = true;
        else delete all[listKind][label];
        store.set("wca_checked", all);
        renderChecklist();
      });
      const span = document.createElement("span");
      span.textContent = label;
      row.append(box, span);
      div.appendChild(row);
    });
    container.appendChild(div);
  });

  $("#cl-total").textContent = total;
  $("#cl-done").textContent = done;
}

$$(".seg-btn[data-list]").forEach((btn) =>
  btn.addEventListener("click", () => {
    $$(".seg-btn[data-list]").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    listKind = btn.dataset.list;
    renderChecklist();
  })
);
renderChecklist();

/* ---------------- Gratuity calculator ---------------- */
function calcTips() {
  const guests = +$("#tip-guests").value || 0;
  const nights = +$("#tip-nights").value || 0;
  const rate = +$("#tip-rate").value || 0;
  $("#tip-total").textContent = "$" + (guests * nights * rate).toFixed(2);
  const bill = +$("#bar-bill").value || 0;
  const pct = +$("#bar-pct").value || 0;
  $("#bar-total").textContent = "$" + ((bill * pct) / 100).toFixed(2);
}
["tip-guests", "tip-nights", "tip-rate", "bar-bill", "bar-pct"].forEach((id) =>
  $("#" + id).addEventListener("input", calcTips)
);
calcTips();

/* ---------------- Maritime converter ---------------- */
function bindConv(inputId, outputId, fn) {
  $("#" + inputId).addEventListener("input", (e) => {
    const v = parseFloat(e.target.value);
    $("#" + outputId).textContent = isNaN(v) ? "" : fn(v);
  });
}
bindConv("cv-knots", "cv-speed", (v) => `= ${(v * 1.852).toFixed(1)} km/h · ${(v * 1.15078).toFixed(1)} mph`);
bindConv("cv-nm", "cv-dist", (v) => `= ${(v * 1.852).toFixed(1)} km · ${(v * 1.15078).toFixed(1)} mi`);
bindConv("cv-m", "cv-len", (v) => `= ${(v * 3.28084).toFixed(1)} ft`);
bindConv("cv-c", "cv-temp", (v) => `= ${((v * 9) / 5 + 32).toFixed(1)} °F`);

/* ---------------- Glossary ---------------- */
let glCat = "all";

function renderFilters() {
  $("#gl-filters").innerHTML = Object.entries(GL_CATS)
    .map(([k, label]) => `<button class="seg-btn ${k === glCat ? "active" : ""}" data-cat="${k}">${label}</button>`)
    .join("");
  $$("#gl-filters .seg-btn").forEach((btn) =>
    btn.addEventListener("click", () => { glCat = btn.dataset.cat; renderFilters(); renderGlossary(); })
  );
}

function renderGlossary() {
  const q = $("#gl-search").value.trim().toLowerCase();
  const list = $("#gl-list");
  const rows = GLOSSARY.filter(
    ([term, def, cat]) =>
      (glCat === "all" || cat === glCat) &&
      (!q || term.toLowerCase().includes(q) || def.toLowerCase().includes(q))
  );
  list.innerHTML = rows.length
    ? rows
        .map(
          ([term, def, cat]) =>
            `<dt>${term} <span class="cat">${GL_CATS[cat]}</span></dt><dd>${def}</dd>`
        )
        .join("")
    : "<dd>No terms found.</dd>";
}

$("#gl-search").addEventListener("input", renderGlossary);
renderFilters();
renderGlossary();

/* ---------------- Quiz ---------------- */
let quizOrder = [], quizIndex = 0, quizScore = 0;

function shuffled(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function startQuiz() {
  quizOrder = shuffled(QUIZ);
  quizIndex = 0;
  quizScore = 0;
  $("#quiz-intro").hidden = true;
  $("#quiz-done").hidden = true;
  $("#quiz-q").hidden = false;
  askQuestion();
}

function askQuestion() {
  const item = quizOrder[quizIndex];
  $("#quiz-progress").textContent = `Question ${quizIndex + 1} of ${quizOrder.length} · Score ${quizScore}`;
  $("#quiz-question").textContent = item.q;

  // Shuffle answers, remember where the correct one landed.
  const answers = shuffled(item.a.map((text, i) => ({ text, good: i === item.correct })));
  const box = $("#quiz-answers");
  box.innerHTML = "";
  let answered = false;

  answers.forEach((ans) => {
    const btn = document.createElement("button");
    btn.textContent = ans.text;
    btn.addEventListener("click", () => {
      if (answered) return;
      answered = true;
      if (ans.good) { btn.classList.add("good"); quizScore++; }
      else {
        btn.classList.add("bad");
        [...box.children].find((b) => b.dataset.good === "1")?.classList.add("good");
      }
      setTimeout(() => {
        quizIndex++;
        if (quizIndex < quizOrder.length) askQuestion();
        else endQuiz();
      }, 900);
    });
    if (ans.good) btn.dataset.good = "1";
    box.appendChild(btn);
  });
}

function endQuiz() {
  $("#quiz-q").hidden = true;
  $("#quiz-done").hidden = false;
  $("#quiz-score").textContent = `${quizScore} / ${quizOrder.length}`;
  const verdicts = [
    [10, "⚓ Officer material — welcome aboard!"],
    [8, "🚢 Seasoned sailor — you know your ship."],
    [5, "🌊 Promising deckhand — one more read of the guides."],
    [0, "🦀 Landlubber (for now) — the Academy awaits you!"],
  ];
  $("#quiz-verdict").textContent = verdicts.find(([min]) => quizScore >= min)[1];
}

$("#quiz-start").addEventListener("click", startQuiz);
$("#quiz-again").addEventListener("click", startQuiz);
