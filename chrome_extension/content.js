// content.js — a content script.
// Injected into every matching page (see "content_scripts" in manifest.json).
// It can read and modify the page's DOM, but runs in an isolated world:
// it shares the DOM with the page, not the page's JavaScript variables.

function getVideoId() {
  // youtube.com/watch?v=VIDEO_ID
  const url = new URL(location.href);
  if (url.pathname === "/watch") return url.searchParams.get("v");
  // youtube.com/shorts/VIDEO_ID
  const shorts = url.pathname.match(/^\/shorts\/([\w-]{5,})/);
  if (shorts) return shorts[1];
  return null;
}

function showToast(text) {
  const el = document.createElement("div");
  el.textContent = text;
  el.style.cssText = `
    position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%);
    background: #9c6b26; color: #fff; padding: 10px 18px; border-radius: 8px;
    font: 14px system-ui, sans-serif; z-index: 999999; box-shadow: 0 4px 12px rgba(0,0,0,.3);
  `;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 2200);
}

// Respond to messages from the popup and the background service worker.
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === "GET_VIDEO_INFO") {
    sendResponse({ videoId: getVideoId(), title: document.title.replace(/ - YouTube$/, "") });
  }
  if (msg.type === "COPY_VIDEO_ID") {
    const id = getVideoId();
    if (id) {
      navigator.clipboard.writeText(id).then(() => showToast(`Copied video ID: ${id}`));
    } else {
      showToast("No video on this page");
    }
  }
  return true; // keep the message channel open for async sendResponse
});
