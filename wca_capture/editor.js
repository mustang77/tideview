// editor.js — annotation editor. Loads the screenshot that background.js
// stored under "pending", crops it if an area was selected, and offers a
// full toolset: pen, marker, line, arrow, box, circle, text, blur.

const canvas = document.getElementById("canvas");
const ctx = canvas.getContext("2d");
const toast = document.getElementById("toast");
const textInput = document.getElementById("text-input");

let tool = "pen";
let color = "#e53935";
let size = 4;
let drawing = false;
let startX = 0, startY = 0;
let lastX = 0, lastY = 0;
let points = [];            // pen/marker stroke points
let snapshot = null;        // canvas state at the start of the current stroke
const undoStack = [];       // previous states (data URLs), max 30
const redoStack = [];

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

function restoreFrom(dataUrl) {
  const img = new Image();
  img.onload = () => { ctx.clearRect(0, 0, canvas.width, canvas.height); ctx.drawImage(img, 0, 0); };
  img.src = dataUrl;
}

document.getElementById("undo").addEventListener("click", () => {
  const prev = undoStack.pop();
  if (!prev) return;
  redoStack.push(canvas.toDataURL());
  restoreFrom(prev);
});

document.getElementById("redo").addEventListener("click", () => {
  const next = redoStack.pop();
  if (!next) return;
  undoStack.push(canvas.toDataURL());
  restoreFrom(next);
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
  if (undoStack.length > 30) undoStack.shift();
  redoStack.length = 0; // a new action invalidates redo history
}

function styleCtx() {
  ctx.strokeStyle = color;
  ctx.fillStyle = color;
  ctx.lineWidth = size;
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  ctx.globalAlpha = 1;
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
  startX = lastX = p.x;
  startY = lastY = p.y;
  points = [p];
  snapshot = ctx.getImageData(0, 0, canvas.width, canvas.height);
  if (tool === "pen") { ctx.beginPath(); ctx.moveTo(p.x, p.y); }
});

canvas.addEventListener("mousemove", (e) => {
  if (!drawing) return;
  const p = pos(e);
  lastX = p.x; lastY = p.y;
  styleCtx();

  if (tool === "pen") {
    ctx.lineTo(p.x, p.y);
    ctx.stroke();
    return;
  }

  // All other tools redraw a live preview on top of the pre-stroke state.
  ctx.putImageData(snapshot, 0, 0);

  if (tool === "marker") {
    // One smooth translucent stroke: redraw the whole path each frame so
    // overlapping segments don't stack up darker.
    points.push(p);
    ctx.globalAlpha = 0.35;
    ctx.lineWidth = size * 4;
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    points.forEach((pt) => ctx.lineTo(pt.x, pt.y));
    ctx.stroke();
    ctx.globalAlpha = 1;
  } else if (tool === "line") {
    ctx.beginPath();
    ctx.moveTo(startX, startY);
    ctx.lineTo(p.x, p.y);
    ctx.stroke();
  } else if (tool === "arrow") {
    drawArrow(startX, startY, p.x, p.y);
  } else if (tool === "rect") {
    ctx.strokeRect(startX, startY, p.x - startX, p.y - startY);
  } else if (tool === "ellipse") {
    ctx.beginPath();
    ctx.ellipse(
      (startX + p.x) / 2, (startY + p.y) / 2,
      Math.abs(p.x - startX) / 2, Math.abs(p.y - startY) / 2,
      0, 0, Math.PI * 2
    );
    ctx.stroke();
  } else if (tool === "blur") {
    // Preview: dashed rectangle over the area that will be pixelated.
    ctx.save();
    ctx.setLineDash([8, 6]);
    ctx.lineWidth = 2;
    ctx.strokeStyle = "#0c4a8a";
    ctx.strokeRect(startX, startY, p.x - startX, p.y - startY);
    ctx.restore();
  }
});

window.addEventListener("mouseup", () => {
  if (!drawing) return;
  drawing = false;
  if (tool === "blur") {
    ctx.putImageData(snapshot, 0, 0); // remove the dashed preview
    applyPixelate(startX, startY, lastX, lastY);
  }
});

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

// Mosaic/pixelate a region: draw it tiny, then scale it back up with
// smoothing off. Great for hiding emails, names, keys in screenshots.
function applyPixelate(x1, y1, x2, y2) {
  const x = Math.round(Math.min(x1, x2));
  const y = Math.round(Math.min(y1, y2));
  const w = Math.round(Math.abs(x2 - x1));
  const h = Math.round(Math.abs(y2 - y1));
  if (w < 4 || h < 4) return;

  const block = Math.max(6, Math.round(Math.max(w, h) / 24)); // pixel size
  const tmp = document.createElement("canvas");
  tmp.width = Math.max(1, Math.round(w / block));
  tmp.height = Math.max(1, Math.round(h / block));
  const tctx = tmp.getContext("2d");
  tctx.imageSmoothingEnabled = false;
  tctx.drawImage(canvas, x, y, w, h, 0, 0, tmp.width, tmp.height);

  ctx.save();
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(tmp, 0, 0, tmp.width, tmp.height, x, y, w, h);
  ctx.restore();
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
