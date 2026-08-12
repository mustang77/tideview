# Push notifications setup (Firebase) — ~10 minutes

Real push (arrives even when the app is closed) needs a free Firebase project.
Only you can create it — it's tied to your Google account. Once you finish the
steps below and send me the two files, I wire the app + server and we're live.

The app and server **already work without this** — notifications just stay off
until it's done.

---

## Part 1 — Create the Firebase project (you)

1. Go to <https://console.firebase.google.com> → **Add project**.
   - Name it e.g. `Paramall`. You can skip Google Analytics.
2. In the project, click the **Android** icon ("Add app").
   - **Android package name:** `com.paramall.app`  ← must be exactly this.
   - App nickname: `Paramall` (optional). SHA-1: skip for now.
   - Click **Register app**.
3. **Download `google-services.json`.** Keep this file — I'll add it to the app.
4. Skip the "add SDK" gradle steps it shows (I do those in code). Click through
   to finish.

## Part 2 — Service account key for the server (you)

1. Firebase console → gear icon → **Project settings** → **Service accounts** tab.
2. Click **Generate new private key** → confirm → a `.json` downloads.
3. Rename it to `fcm-service-account.json`.
4. Note your **Project ID** (top of Project settings, e.g. `paramall-1234`).

## Part 3 — Put the secret files on your server (you)

1. Upload `fcm-service-account.json` into the `api/` folder on your host (next to
   `index.php`), so it sits at `paramall/api/fcm-service-account.json`.
2. Edit `api/config.php` and set `'fcm_project_id' => 'your-project-id',`.
3. Make sure the `device_tokens` table exists (re-import `schema.sql`, or run just
   that one `CREATE TABLE`).

> Both secret files are already git-ignored — never commit them.

## Part 4 — Send me `google-services.json` (you → me)

Paste or attach the contents of **`google-services.json`**. That's the only file
I need to finish the app side. (Do **not** send the service-account key or config
in chat — those stay on your server.)

---

## What I do once you send `google-services.json`

- Add `firebase_core` + `firebase_messaging` + the local-notification channel to
  the Flutter app.
- Add the Google Services Gradle plugin to the Android build.
- On login, the app asks for notification permission and registers its device
  token via `register_token` (already built on the server).
- Drivers/admins subscribe to the `staff` topic to get "new order" alerts.

Then: customers get a push when their order status changes, and your delivery
team gets a push the moment a new order comes in.
