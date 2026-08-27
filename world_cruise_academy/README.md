# WORLD CRUISE ACADEMY — Chrome Extension

A free cruise companion: cruise countdown, packing checklist, searchable cruise
glossary, and a daily cruise tip. Built as a Manifest V3 extension with **no
server, no accounts, and only the `storage` permission** — which keeps Chrome
Web Store review fast and simple.

## Files

| File | What it is |
|---|---|
| `manifest.json` | Extension metadata: name, version, icons, permissions |
| `popup.html/css/js` | The popup UI and logic (4 tabs) |
| `data.js` | All content — checklist items, glossary terms, tips. **Edit this to add content.** |
| `icons/` | Toolbar + store icons (16/48/128 px) |
| `STORE_LISTING.md` | Ready-to-paste text for the Chrome Web Store listing |

## Test it locally

1. Open `chrome://extensions`, enable **Developer mode**
2. **Load unpacked** → select this `world_cruise_academy` folder
3. Click the ship icon in the toolbar

## Before you publish — 2 things to change

1. **Website link**: in `popup.html`, the footer link points to
   `https://www.worldcruiseacademy.com` — change it to your real website URL.
2. Review the content in `data.js` and make it your own.

## Publish to the Chrome Web Store

1. Create a developer account at
   https://chrome.google.com/webstore/devconsole (one-time $5 fee)
2. Zip **the contents of this folder** (so `manifest.json` is at the root of
   the zip, not inside a subfolder)
3. Click **New item**, upload the zip
4. Fill in the store listing — use the text in `STORE_LISTING.md`
5. Screenshots: the store requires at least one 1280×800 or 640×400 screenshot.
   Load the extension, open the popup, and capture each tab.
6. Privacy tab: declare that the extension does **not** collect user data
   (everything is stored locally via chrome.storage) and justify the `storage`
   permission as "saves the user's countdown date and checklist progress".
7. Submit for review — typically approved in 1–3 days.

## Updating after publish

Bump `"version"` in `manifest.json` (e.g. `1.0.1`), re-zip, and upload the new
zip in the developer dashboard. Users get the update automatically.
