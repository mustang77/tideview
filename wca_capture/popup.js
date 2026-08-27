// popup.js — the three entry points. The popup only kicks things off,
// then closes; background.js and the injected script do the work.

async function activeTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab;
}

// Chrome forbids ALL extensions from capturing its own pages (New Tab,
// chrome://, the Web Store). Detect that up front and say so, instead of
// letting the buttons fail silently.
(async () => {
  const tab = await activeTab();
  const capturable = /^(https?|file):/.test(tab?.url || "");
  if (!capturable) {
    document.getElementById("cap-visible").disabled = true;
    document.getElementById("cap-area").disabled = true;
    document.querySelector(".note").textContent =
      "⚠️ Chrome pages (New Tab, chrome://, Web Store) can't be captured — open any normal website first. Screen recording still works!";
  }
})();

document.getElementById("cap-visible").addEventListener("click", async () => {
  chrome.runtime.sendMessage({ type: "CAPTURE_VISIBLE", dpr: window.devicePixelRatio });
  window.close();
});

document.getElementById("cap-area").addEventListener("click", async () => {
  const tab = await activeTab();
  try {
    // Inject the area-selection overlay into the current page.
    await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ["select.js"] });
    window.close();
  } catch {
    // chrome:// pages and the Web Store cannot be scripted.
    document.querySelector(".note").textContent =
      "⚠️ This page can't be captured (Chrome system page). Try a normal website.";
  }
});

document.getElementById("record").addEventListener("click", () => {
  chrome.tabs.create({ url: chrome.runtime.getURL("recorder.html") });
  window.close();
});
