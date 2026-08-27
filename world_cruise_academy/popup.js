// popup.js — all the logic. Runs each time the popup opens.
// Persistent data lives in chrome.storage.local under these keys:
//   cruise:    { name, date }        — the countdown target
//   checked:   { "<item label>": true, ... } — packing progress
//   tipOffset: number                — how far the user clicked past today's tip

const $ = (sel) => document.querySelector(sel);

/* ---------- Tabs ---------- */
document.querySelectorAll(".tab").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tab, .panel").forEach((el) => el.classList.remove("active"));
    btn.classList.add("active");
    $("#" + btn.dataset.tab).classList.add("active");
  });
});

/* ---------- Countdown ---------- */
async function initCountdown() {
  const { cruise } = await chrome.storage.local.get("cruise");
  if (cruise?.date) renderCountdown(cruise);

  $("#cd-save").addEventListener("click", async () => {
    const date = $("#cd-date").value;
    if (!date) return;
    const data = { name: $("#cd-name").value.trim() || "My cruise", date };
    await chrome.storage.local.set({ cruise: data });
    renderCountdown(data);
  });

  $("#cd-reset").addEventListener("click", async () => {
    await chrome.storage.local.remove("cruise");
    $("#cd-display").hidden = true;
    $("#cd-setup").hidden = false;
  });
}

function renderCountdown({ name, date }) {
  const days = Math.ceil((new Date(date + "T00:00") - new Date()) / 86400000);
  $("#cd-cruise-name").textContent = name;
  if (days > 0) {
    $("#cd-days").textContent = days;
    $("#cd-label").textContent = days === 1 ? "day until you sail" : "days until you sail";
  } else if (days > -14) {
    $("#cd-days").textContent = "🚢";
    $("#cd-label").textContent = "Bon voyage — you're sailing!";
  } else {
    $("#cd-days").textContent = "🌅";
    $("#cd-label").textContent = "Cruise complete — time to book the next one!";
  }
  $("#cd-setup").hidden = true;
  $("#cd-display").hidden = false;
}

/* ---------- Packing checklist ---------- */
async function initChecklist() {
  const { checked = {} } = await chrome.storage.local.get("checked");
  const container = $("#cl-groups");
  let total = 0;

  WCA_CHECKLIST.forEach(({ group, items }) => {
    const div = document.createElement("div");
    div.className = "cl-group";
    div.innerHTML = `<h2>${group}</h2>`;
    items.forEach((label) => {
      total++;
      const row = document.createElement("label");
      row.className = "cl-item" + (checked[label] ? " checked" : "");
      const box = document.createElement("input");
      box.type = "checkbox";
      box.checked = !!checked[label];
      box.addEventListener("change", async () => {
        const store = (await chrome.storage.local.get("checked")).checked || {};
        if (box.checked) store[label] = true;
        else delete store[label];
        await chrome.storage.local.set({ checked: store });
        row.classList.toggle("checked", box.checked);
        updateProgress();
      });
      const span = document.createElement("span");
      span.textContent = label;
      row.append(box, span);
      div.appendChild(row);
    });
    container.appendChild(div);
  });

  $("#cl-total").textContent = total;
  updateProgress();

  async function updateProgress() {
    const store = (await chrome.storage.local.get("checked")).checked || {};
    $("#cl-done").textContent = Object.keys(store).length;
  }
}

/* ---------- Glossary ---------- */
function initGlossary() {
  const list = $("#gl-list");

  function render(filter = "") {
    list.innerHTML = "";
    const q = filter.trim().toLowerCase();
    WCA_GLOSSARY
      .filter(([term, def]) => !q || term.toLowerCase().includes(q) || def.toLowerCase().includes(q))
      .forEach(([term, def]) => {
        const dt = document.createElement("dt");
        dt.textContent = term;
        const dd = document.createElement("dd");
        dd.textContent = def;
        list.append(dt, dd);
      });
    if (!list.children.length) {
      list.innerHTML = "<dd>No terms found.</dd>";
    }
  }

  $("#gl-search").addEventListener("input", (e) => render(e.target.value));
  render();
}

/* ---------- Tip of the day ---------- */
async function initTips() {
  // Deterministic "tip of the day": day number since epoch mod tip count,
  // plus however many times the user clicked "Show another tip".
  const dayIndex = Math.floor(Date.now() / 86400000);
  let { tipOffset = 0 } = await chrome.storage.local.get("tipOffset");

  const show = () => {
    $("#tip-text").textContent = WCA_TIPS[(dayIndex + tipOffset) % WCA_TIPS.length];
  };

  $("#tip-next").addEventListener("click", async () => {
    tipOffset++;
    await chrome.storage.local.set({ tipOffset });
    show();
  });

  show();
}

initCountdown();
initChecklist();
initGlossary();
initTips();
