# JARVIS

A personal assistant in your browser, powered by Claude:

- **Voice both ways.** Talk to it with the microphone and it answers out loud. Uses the browser's built-in speech recognition and speech synthesis, no extra services.
- **Eyes.** Turn on the webcam and a frame is sent with your question, so it can describe what it sees.
- **Second brain.** Your Markdown notes become a 3D galaxy. Every answer cites the notes it came from, and the camera flies to the cited note.
- **Self-check.** `npm run check` tests every feature and tells you what is broken.

The API key stays in a local file on your computer. The browser never sees it.

## Setup (5 minutes)

1. Install [Node.js](https://nodejs.org) 18 or newer.
2. In this folder:

   ```bash
   npm install
   cp .env.example .env      # on Windows: copy .env.example .env
   ```

3. Open `.env` and paste your key from https://console.anthropic.com after `ANTHROPIC_API_KEY=`.
4. Start it:

   ```bash
   npm start
   ```

5. Open http://localhost:3131 in Chrome. Allow the microphone and camera when asked.

Without a key the app runs in **demo mode**: the interface, galaxy, voice, and search all work, and answers are canned so you can try everything before spending anything.

## Your notes

Put `.md` files in the `notes` folder, or point `NOTES_DIR` in `.env` at an existing folder such as an Obsidian vault. The index rebuilds automatically when files change.

Links in the galaxy come from three things:
- `[[Wikilinks]]` between notes
- shared `#tags`
- similar content

## Using it

| Control | What it does |
|---|---|
| Mic button, or hold **Space** | Listen for one question, then answer aloud |
| **Eyes** | Attach a webcam frame to every question |
| **Voice** | Toggle spoken answers on or off |
| Text box | Type a question instead of speaking |
| Galaxy | Drag to orbit, scroll to zoom, click a star to open the note |

## Settings

All in `.env`:

| Setting | Default | Notes |
|---|---|---|
| `JARVIS_MODEL` | `claude-opus-5` | Set `claude-fable-5-1` for the most capable model at about twice the price |
| `JARVIS_EFFORT` | `medium` | `low` is fastest, `high` thinks harder |
| `NOTES_DIR` | `./notes` | Your notes folder |
| `PORT` | `3131` | Local port |

Refusal fallbacks are enabled by default: if the model declines a request on safety grounds, the API re-runs it on a fallback model inside the same call. Remove the `fallbacks` line in `server.mjs` if you prefer a plain refusal.

## Costs

Each question sends the five most relevant notes, so a typical text question costs well under one cent. Attaching a webcam frame adds roughly the same again. The system prompt is cached, which reduces repeat costs.

## Troubleshooting

- **No microphone button response.** Speech recognition needs Chrome or Edge and an internet connection.
- **"The API key was rejected".** Check `.env`, then restart with `npm start`.
- **Galaxy is empty.** Add `.md` files to `notes` and refresh.
- Run `npm run check` to test everything and see exactly which step fails.
