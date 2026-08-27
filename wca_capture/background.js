// background.js — service worker.
// Owns the actual screen capture (chrome.tabs.captureVisibleTab) because the
// popup closes itself before the shot is taken. The captured image is handed
// to the editor page through chrome.storage.local under the key "pending".

async function captureAndOpenEditor(rect, dpr) {
  // Small delay so the popup / selection overlay is fully gone from screen.
  await new Promise((r) => setTimeout(r, 150));
  try {
    const dataUrl = await chrome.tabs.captureVisibleTab({ format: "png" });
    await chrome.storage.local.set({ pending: { dataUrl, rect: rect || null, dpr: dpr || 1 } });
    await chrome.tabs.create({ url: chrome.runtime.getURL("editor.html") });
  } catch (e) {
    // Typically: a chrome:// page or the Web Store, where capture is forbidden.
    console.error("Capture failed:", e);
    // Make the failure visible instead of silent: red badge on the icon.
    chrome.action.setBadgeBackgroundColor({ color: "#e53935" });
    chrome.action.setBadgeText({ text: "!" });
    setTimeout(() => chrome.action.setBadgeText({ text: "" }), 5000);
  }
}

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.type === "CAPTURE_VISIBLE") captureAndOpenEditor(null, msg.dpr);
  if (msg.type === "AREA_SELECTED") captureAndOpenEditor(msg.rect, msg.dpr);
});
