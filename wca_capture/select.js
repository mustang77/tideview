// select.js — injected into the page when the user picks "Capture selected
// area". Draws a fullscreen overlay; the user drags a rectangle; the chosen
// rect (in viewport CSS pixels) is sent to the service worker, which then
// takes the screenshot and the editor crops it.

(() => {
  // Avoid double-injection if the user clicks the button twice.
  if (document.getElementById("__wca_select_overlay")) return;

  const overlay = document.createElement("div");
  overlay.id = "__wca_select_overlay";
  overlay.style.cssText =
    "position:fixed;inset:0;z-index:2147483647;cursor:crosshair;background:rgba(0,0,0,.25);";
  const box = document.createElement("div");
  box.style.cssText =
    "position:fixed;border:2px dashed #fff;background:rgba(2,136,209,.15);display:none;" +
    "box-shadow:0 0 0 9999px rgba(0,0,0,.25);z-index:2147483647;pointer-events:none;";
  const hint = document.createElement("div");
  hint.textContent = "Drag to select an area — Esc to cancel";
  hint.style.cssText =
    "position:fixed;top:16px;left:50%;transform:translateX(-50%);background:#0c4a8a;color:#fff;" +
    "padding:6px 14px;border-radius:20px;font:13px system-ui;z-index:2147483647;pointer-events:none;";
  document.documentElement.append(overlay, box, hint);

  let sx = 0, sy = 0, dragging = false;

  const cleanup = () => { overlay.remove(); box.remove(); hint.remove(); };

  overlay.addEventListener("mousedown", (e) => {
    dragging = true;
    sx = e.clientX; sy = e.clientY;
    // Once dragging starts, the dimming comes from the box's shadow instead.
    overlay.style.background = "transparent";
    box.style.display = "block";
    e.preventDefault();
  });

  overlay.addEventListener("mousemove", (e) => {
    if (!dragging) return;
    const x = Math.min(sx, e.clientX), y = Math.min(sy, e.clientY);
    const w = Math.abs(e.clientX - sx), h = Math.abs(e.clientY - sy);
    Object.assign(box.style, { left: x + "px", top: y + "px", width: w + "px", height: h + "px" });
  });

  overlay.addEventListener("mouseup", (e) => {
    const rect = {
      x: Math.min(sx, e.clientX),
      y: Math.min(sy, e.clientY),
      w: Math.abs(e.clientX - sx),
      h: Math.abs(e.clientY - sy),
    };
    cleanup();
    if (rect.w < 5 || rect.h < 5) return; // accidental click
    // Wait two frames so the overlay is really gone before the screenshot.
    requestAnimationFrame(() =>
      requestAnimationFrame(() =>
        chrome.runtime.sendMessage({ type: "AREA_SELECTED", rect, dpr: window.devicePixelRatio })
      )
    );
  });

  window.addEventListener("keydown", function esc(e) {
    if (e.key === "Escape") { cleanup(); window.removeEventListener("keydown", esc); }
  });
})();
