// app.js — behavior + multi-language rendering.
// Languages live in I18N (data.js); adding a new one = adding a block there
// plus an <option> in the #lang-select dropdown.
// localStorage keys:
//   wca_lang     "en" | "id"
//   wca_cd       {name, date}
//   wca_checked  {guest:{"0:1":true}, crew:{...}}  (group:item indexes — language-independent)
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

let lang = store.get("wca_lang", null) || (navigator.language?.startsWith("id") ? "id" : "en");
if (!I18N[lang]) lang = "en";
const T = () => I18N[lang];

/* ---------------- Language switching ---------------- */
function applyLang() {
  document.documentElement.lang = lang;
  $("#lang-select").value = lang;
  const ui = T().ui;
  $$("[data-i18n]").forEach((el) => (el.textContent = ui[el.dataset.i18n] ?? el.textContent));
  $$("[data-i18n-html]").forEach((el) => (el.innerHTML = ui[el.dataset.i18nHtml] ?? el.innerHTML));
  $$("[data-i18n-ph]").forEach((el) => (el.placeholder = ui[el.dataset.i18nPh] ?? el.placeholder));

  renderGuide($("#guest-guide"), T().guestGuide);
  renderGuide($("#crew-guide"), T().crewGuide);
  renderChecklist();
  renderFilters();
  renderGlossary();
  refreshCountdownLabel();
  resetQuizToIntro();
}

$("#lang-select") && $("#lang-select").addEventListener("change", (e) => {
  lang = e.target.value;
  store.set("wca_lang", lang);
  applyLang();
});

/* ---------------- Navigation (hash-based views) ---------------- */
const VIEWS = ["home", "guest", "crew", "tools", "glossary", "quiz"];

function show(view) {
  if (!VIEWS.includes(view)) view = "home";
  $$(".view").forEach((v) => v.classList.toggle("active", v.id === view));
  $$("#nav a").forEach((a) => a.classList.toggle("active", a.dataset.nav === view));
  window.scrollTo(0, 0);
}
window.addEventListener("hashchange", () => show(location.hash.slice(1)));

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

/* ---------------- Countdown ---------------- */
function refreshCountdownLabel() {
  const data = store.get("wca_cd", null);
  if (!data?.date) {
    $("#cd-display").hidden = true;
    $("#cd-setup").hidden = false;
    return;
  }
  const ui = T().ui;
  const days = Math.ceil((new Date(data.date + "T00:00") - new Date()) / 86400000);
  $("#cd-cruise-name").textContent = data.name;
  if (days > 0) {
    $("#cd-days").textContent = days;
    $("#cd-label").textContent = days === 1 ? ui.cdDay : ui.cdDays;
  } else if (days > -60) {
    $("#cd-days").textContent = "🚢";
    $("#cd-label").textContent = ui.cdSailing;
  } else {
    $("#cd-days").textContent = "🌅";
    $("#cd-label").textContent = ui.cdDone;
  }
  $("#cd-setup").hidden = true;
  $("#cd-display").hidden = false;
}

$("#cd-save").addEventListener("click", () => {
  const date = $("#cd-date").value;
  if (!date) return;
  const name = $("#cd-name").value.trim() || (lang === "id" ? "Pelayaranku" : "My voyage");
  store.set("wca_cd", { name, date });
  refreshCountdownLabel();
});
$("#cd-reset").addEventListener("click", () => {
  store.del("wca_cd");
  refreshCountdownLabel();
});

/* ---------------- Checklist (guest / crew, language-independent keys) ---------------- */
let listKind = "guest";

function renderChecklist() {
  const checked = store.get("wca_checked", {})[listKind] || {};
  const groups = T().checklists[listKind];
  const container = $("#cl-groups");
  container.innerHTML = "";
  let total = 0, done = 0;

  groups.forEach(({ group, items }, gi) => {
    const div = document.createElement("div");
    div.className = "cl-group";
    div.innerHTML = `<h3>${group}</h3>`;
    items.forEach((label, ii) => {
      total++;
      const key = `${gi}:${ii}`;
      const isOn = !!checked[key];
      if (isOn) done++;
      const row = document.createElement("label");
      row.className = "cl-item" + (isOn ? " checked" : "");
      const box = document.createElement("input");
      box.type = "checkbox";
      box.checked = isOn;
      box.addEventListener("change", () => {
        const all = store.get("wca_checked", {});
        all[listKind] = all[listKind] || {};
        if (box.checked) all[listKind][key] = true;
        else delete all[listKind][key];
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
  $("#gl-filters").innerHTML = Object.entries(T().glCats)
    .map(([k, label]) => `<button class="seg-btn ${k === glCat ? "active" : ""}" data-cat="${k}">${label}</button>`)
    .join("");
  $$("#gl-filters .seg-btn").forEach((btn) =>
    btn.addEventListener("click", () => { glCat = btn.dataset.cat; renderFilters(); renderGlossary(); })
  );
}

function renderGlossary() {
  const q = $("#gl-search").value.trim().toLowerCase();
  const cats = T().glCats;
  const rows = T().glossary.filter(
    ([term, def, cat]) =>
      (glCat === "all" || cat === glCat) &&
      (!q || term.toLowerCase().includes(q) || def.toLowerCase().includes(q))
  );
  $("#gl-list").innerHTML = rows.length
    ? rows
        .map(([term, def, cat]) => `<dt>${term} <span class="cat">${cats[cat]}</span></dt><dd>${def}</dd>`)
        .join("")
    : `<dd>${T().ui.glNone}</dd>`;
}

$("#gl-search").addEventListener("input", renderGlossary);

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

function resetQuizToIntro() {
  $("#quiz-intro").hidden = false;
  $("#quiz-q").hidden = true;
  $("#quiz-done").hidden = true;
}

function startQuiz() {
  quizOrder = shuffled(T().quiz);
  quizIndex = 0;
  quizScore = 0;
  $("#quiz-intro").hidden = true;
  $("#quiz-done").hidden = true;
  $("#quiz-q").hidden = false;
  askQuestion();
}

function askQuestion() {
  const item = quizOrder[quizIndex];
  $("#quiz-progress").textContent = T().ui.quizProgress
    .replace("{n}", quizIndex + 1)
    .replace("{total}", quizOrder.length)
    .replace("{score}", quizScore);
  $("#quiz-question").textContent = item.q;

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
  $("#quiz-verdict").textContent = T().verdicts.find(([min]) => quizScore >= min)[1];
}

$("#quiz-start").addEventListener("click", startQuiz);
$("#quiz-again").addEventListener("click", startQuiz);

/* ---------------- Boot ---------------- */
applyLang();
show(location.hash.slice(1) || "home");
