# TideView Helper — Chrome Extension Starter

A minimal, working Manifest V3 Chrome extension. On any YouTube video page it
shows the video's title and ID in a popup and lets you copy them; it also adds
a right-click menu item ("Copy YouTube video ID").

## How to load it in Chrome

1. Open Chrome and go to `chrome://extensions`
2. Turn on **Developer mode** (toggle in the top-right corner)
3. Click **Load unpacked**
4. Select this `chrome_extension/` folder
5. The extension appears in the toolbar (pin it via the puzzle-piece icon)

Open any YouTube video, click the extension icon, and you'll see the video ID.

## How the pieces fit together

| File | Role |
|---|---|
| `manifest.json` | The heart of every extension — declares name, version, permissions, and which files do what. Chrome reads this first. |
| `popup/popup.html` + `.css` + `.js` | The small window that opens when you click the toolbar icon. Short-lived: destroyed when closed. |
| `content.js` | A **content script** — injected into pages matching the patterns in the manifest (here: youtube.com). It can read/change the page's DOM. |
| `background.js` | A **service worker** — runs in the background with no UI, wakes for events (installs, messages, context-menu clicks), then sleeps. |

The three contexts talk to each other with **message passing**
(`chrome.runtime.sendMessage` / `chrome.tabs.sendMessage`), and share
persistent data through **`chrome.storage`**.

## Development cycle

1. Edit the files
2. Go to `chrome://extensions` and click the ↻ reload button on the extension
   (popup/CSS changes apply on reopen; manifest/background changes need the reload)
3. Reload the target web page if you changed `content.js`
4. Debugging:
   - Popup: right-click the popup → **Inspect**
   - Content script: normal page DevTools (F12) → its logs show in the Console
   - Service worker: `chrome://extensions` → click the **service worker** link

## Key concepts when building your own

- **Manifest V3** is required for new extensions (V2 is being phased out).
- **Permissions**: request the minimum you need. `activeTab` (access to the
  current tab only when clicked) is preferred over broad host permissions.
- **CSP**: inline `<script>` in extension pages is blocked — always use
  separate `.js` files.
- **No remote code**: all JavaScript must ship inside the extension package.
- **State**: service workers are killed and restarted constantly — persist
  anything important with `chrome.storage`, never globals.

## Publishing to the Chrome Web Store

1. Zip the contents of this folder (manifest.json at the zip root)
2. Register as a developer at the
   [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole)
   (one-time $5 fee)
3. Upload the zip, fill in the store listing (description, screenshots, a
   128×128 icon), and declare your permissions/privacy practices
4. Submit for review — usually approved within a few days

## Official docs

- Getting started: https://developer.chrome.com/docs/extensions/get-started
- API reference: https://developer.chrome.com/docs/extensions/reference
- Manifest V3 overview: https://developer.chrome.com/docs/extensions/develop/migrate/what-is-mv3
