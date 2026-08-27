// popup.js — runs inside the popup window each time it opens.
// The popup is short-lived: it is destroyed the moment it closes,
// so persistent data goes in chrome.storage.

const statusEl = document.getElementById("status");
const infoEl = document.getElementById("video-info");
const titleEl = document.getElementById("video-title");
const idEl = document.getElementById("video-id");
const countEl = document.getElementById("copy-count");

let videoId = null;

async function init() {
  // Show the stored copy counter (demonstrates chrome.storage).
  const { copyCount = 0 } = await chrome.storage.local.get("copyCount");
  countEl.textContent = copyCount;

  // Find the active tab and ask its content script for video info.
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.url?.includes("youtube.com")) return;

  try {
    const info = await chrome.tabs.sendMessage(tab.id, { type: "GET_VIDEO_INFO" });
    if (info?.videoId) {
      videoId = info.videoId;
      titleEl.textContent = info.title;
      idEl.textContent = info.videoId;
      statusEl.hidden = true;
      infoEl.hidden = false;
    } else {
      statusEl.textContent = "This YouTube page isn't a video.";
    }
  } catch {
    // Content script not injected yet (e.g. tab opened before install) —
    // reloading the tab fixes it.
    statusEl.textContent = "Reload the YouTube tab, then try again.";
  }
}

async function bumpCounter() {
  const { copyCount = 0 } = await chrome.storage.local.get("copyCount");
  await chrome.storage.local.set({ copyCount: copyCount + 1 });
  countEl.textContent = copyCount + 1;
}

document.getElementById("copy-btn").addEventListener("click", async () => {
  if (!videoId) return;
  await navigator.clipboard.writeText(videoId);
  await bumpCounter();
  window.close();
});

document.getElementById("copy-link-btn").addEventListener("click", async () => {
  if (!videoId) return;
  await navigator.clipboard.writeText(`https://www.youtube.com/watch?v=${videoId}`);
  await bumpCounter();
  window.close();
});

init();
