// editor.js — annotation editor. Loads the screenshot that background.js
// stored under "pending", crops it if an area was selected, and lets the
// user draw on it before downloading or copying.

const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
const toast = document.getElementById("toast");
const textInput = document.getElementById("text-input");

let tool = "pen";
let color = "#e53935";
let size = 4;
let drawing = false;
let startX = 0, startY = 0;
let snapshot = null;        // canvas state at the start of the current stroke
const undoStack = [];       // previous states (data URLs), max 20

function showToast(msg) {
  toast.textContent = msg;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 1800);
}

/* ---------- Load the screenshot ---------- */
async function load() {
  const { pending } = await chrome.storage.local.get("pending");
  if (!pending) {
    showToast("No screenshot found — capture one from the toolbar popup.");
    return;
  }
  chrome.storage.local.remove("pending");

  const img = new Image();
  img.onload = () => {
    const { rect, dpr } = pending;
    if (rect) {
      // Area capture: crop. The rect is in CSS pixels; the screenshot is in
      // device pixels, so scale by devicePixelRatio.
      canvas.width = Math.round(rect.w * dpr);
      canvas.height = Math.round(rect.h * dpr);
      ctx.drawImage(
        img,
        Math.round(rect.x * dpr), Math.round(rect.y * dpr),
        canvas.width, canvas.height,
        0, 0, canvas.width, canvas.height
      );
    } else {
      canvas.width = img.width;
      canvas.height = img.height;
      ctx.drawImage(img, 0, 0);
    }
  };
  img.src = pending.dataUrl;
}

/* ---------- Toolbar ---------- */
document.querySelectorAll("[data-tool]").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("[data-tool]").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    tool = btn.dataset.tool;
    textInput.style.display = tool === "text" ? "inline-block" : "none";
    if (tool === "text") textInput.focus();
  });
});
document.getElementById("color").addEventListener("input", (e) => (color = e.target.value));
document.getElementById("size").addEventListener("input", (e) => (size = +e.target.value));

document.getElementById("undo").addEventListener("click", () => {
  const prev = undoStack.pop();
  if (!prev) return;
  const img = new Image();
  img.onload = () => { ctx.clearRect(0, 0, canvas.width, canvas.height); ctx.drawImage(img, 0, 0); };
  img.src = prev;
});

/* ---------- Drawing ---------- */
// The canvas is displayed scaled down (max-width), so convert mouse
// coordinates to real canvas pixels.
function pos(e) {
  const r = canvas.getBoundingClientRect();
  return {
    x: ((e.clientX - r.left) / r.width) * canvas.width,
    y: ((e.clientY - r.top) / r.height) * canvas.height,
  };
}

function pushUndo() {
  undoStack.push(canvas.toDataURL());
  if (undoStack.length > 20) undoStack.shift();
}

function styleCtx() {
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = size;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
}

canvas.addEventListener("mousedown", (e) => {
  const p = pos(e);
  pushUndo();
  styleCtx();

  if (tool === "text") {
    const label = textInput.value.trim() || "Text";
    ctx.font = `bold ${size * 6}px system-ui, sans-serif`;
    ctx.fillText(label, p.x, p.y);
    return;
  }

  drawing = true;
  startX = p.x; startY = p.y;
  snapshot = ctx.getImageData(0, 0, canvas.width, canvas.height);
  if (tool === "pen") { ctx.beginPath(); ctx.moveTo(p.x, p.y); }
});

canvas.addEventListener("mousemove", (e) => {
  if (!drawing) return;
  const p = pos(e);
  styleCtx();

  if (tool === "pen") {
    ctx.lineTo(p.x, p.y);
    ctx.stroke();
    return;
  }

  // Shape preview: restore the pre-stroke state, then draw the shape.
  ctx.putImageData(snapshot, 0, 0);
  if (tool === "rect") {
    ctx.strokeRect(startX, startY, p.x - startX, p.y - startY);
  } else if (tool === "arrow") {
    drawArrow(startX, startY, p.x, p.y);
  }
});

window.addEventListener("mouseup", () => (drawing = false));

function drawArrow(x1, y1, x2, y2) {
  const head = Math.max(12, size * 3.5);
  const angle = Math.atan2(y2 - y1, x2 - x1);
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.stroke();
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - head * Math.cos(angle - Math.PI / 6), y2 - head * Math.sin(angle - Math.PI / 6));
  ctx.lineTo(x2 - head * Math.cos(angle + Math.PI / 6), y2 - head * Math.sin(angle + Math.PI / 6));
  ctx.closePath();
  ctx.fill();
}

/* ---------- Export ---------- */
document.getElementById("download").addEventListener("click", () => {
  const a = document.createElement("a");
  a.href = canvas.toDataURL("image/png");
  a.download = `WCA-screenshot-${new Date().toISOString().replace(/[:.]/g, "-")}.png`;
  a.click();
  showToast("Screenshot downloaded ✓");
});

document.getElementById("copy").addEventListener("click", () => {
  canvas.toBlob(async (blob) => {
    try {
      await navigator.clipboard.write([new ClipboardItem({ "image/png": blob })]);
      showToast("Copied to clipboard ✓");
    } catch {
      showToast("Copy failed — use Download instead.");
    }
  });
});

load();
