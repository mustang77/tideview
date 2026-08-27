# WCA Capture — Screenshot & Screen Recorder Extension

A screenshot + screen recorder Chrome extension (like Awesome Screenshot),
branded WORLD CRUISE ACADEMY. Manifest V3, no server, nothing uploaded —
everything stays on the user's computer.

## Features

- **📸 Capture visible page** — screenshots the current tab
- **✂️ Capture selected area** — drag a rectangle over the page
- **✏️ Annotation editor** — pen, arrow, box, text, color & thickness, undo;
  then Download PNG or Copy to clipboard
- **🎥 Screen recorder** — records screen / window / tab (optional microphone),
  previews the result, saves as `.webm`

## How the pieces fit together

| File | Role |
|---|---|
| `manifest.json` | Declares everything; permissions are just `activeTab`, `scripting`, `storage` |
| `popup.html/js` | The 3-button menu on the toolbar icon |
| `background.js` | Service worker — takes the actual screenshot (`chrome.tabs.captureVisibleTab`) and opens the editor |
| `select.js` | Injected into the page for drag-to-select area capture |
| `editor.html/js` | Annotation editor (canvas drawing, export) |
| `recorder.html/js` | Screen recorder (`getDisplayMedia` + `MediaRecorder`) |

The screenshot travels from background → editor via `chrome.storage.local`
(key `pending`).

## Test locally

`chrome://extensions` → Developer mode → Load unpacked → select this folder.

Notes:
- Capture doesn't work on `chrome://` pages or the Chrome Web Store (Chrome
  forbids it for every extension) — use any normal website.
- For tab/system sound in recordings, tick "Also share audio" in Chrome's
  share dialog.

## Store listing

Name: `WORLD CRUISE ACADEMY Screenshot & Screen Recorder`

Summary: `Capture any page, annotate with arrows and text, record your screen. Free, private — nothing leaves your computer.`

Privacy declarations: no data collected; `activeTab`/`scripting` justified as
"takes the screenshot of the page the user explicitly chose to capture";
`storage` as "hands the captured image to the editor page".

Publishing steps are the same as in `../world_cruise_academy/README.md`.
