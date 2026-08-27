// background.js — the extension's service worker.
// Runs in the background with no page attached. It wakes up for events
// (install, messages, context-menu clicks) and goes back to sleep, so
// never keep state in globals here — use chrome.storage instead.

chrome.runtime.onInstalled.addListener(() => {
  // Create a right-click menu entry that appears on YouTube pages.
  chrome.contextMenus.create({
    id: "copy-video-id",
    title: "Copy YouTube video ID",
    contexts: ["page"],
    documentUrlPatterns: ["*://www.youtube.com/watch*", "*://m.youtube.com/watch*"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId !== "copy-video-id" || !tab?.id) return;
  // Ask the content script on that tab for the video ID, then copy it
  // there (the service worker itself has no DOM/clipboard access).
  chrome.tabs.sendMessage(tab.id, { type: "COPY_VIDEO_ID" });
});
