# Paramall — develop locally & publish to Google Play

The Flutter package name is now **`com.paramall.app`** (Play Store rejects
the old `com.example.*`).

## A. Develop / debug on your PC (hot reload)

You edit the code and see changes instantly on a connected phone or emulator.

1. **Install Flutter** (Windows): https://docs.flutter.dev/get-started/install/windows
   - Also install **Git** and **Android Studio** (Android Studio gives you the
     Android SDK + an emulator + the Flutter/Dart plugin).
2. **Get the project:**
   ```
   git clone https://github.com/mustang77/tideview.git
   cd tideview
   git checkout claude/alfamart-indomaret-api-acpx8f
   flutter pub get
   ```
3. **Check your setup:**
   ```
   flutter doctor
   ```
   Fix anything it flags (usually "accept Android licenses": `flutter doctor --android-licenses`).
4. **Run in debug** (phone plugged in with USB debugging, or an emulator running):
   ```
   flutter run
   ```
   - Edit a file, save → press **r** in the terminal for **hot reload** (instant),
     or **R** for a full restart.
   - `lib/main.dart` is the whole app.

## B. Build a release for Google Play

Play Store needs a **signed App Bundle (.aab)** — not the debug APK.

1. **Create your upload key** (once). In the project folder run:
   ```
   keytool -genkey -v -keystore paramall-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   Keep `paramall-upload.jks` and its passwords **safe and backed up** — losing it
   means you can't update the app again.
2. **Point the project at it:** copy `android/key.properties.example` to
   `android/key.properties` and fill in your passwords, alias (`upload`), and the
   full path to `paramall-upload.jks`. (This file is git-ignored on purpose.)
3. **Build the bundle:**
   ```
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`
4. **Upload** that `.aab` in the [Google Play Console](https://play.google.com/console)
   → create app → Production (or Internal testing first) → upload.

## C. What Google Play also requires (non-code)

- A **Play Console developer account** (one-time US$25).
- **App icon** + feature graphic, screenshots, short/long description.
- A **privacy policy** URL.
- **Content rating** questionnaire, data-safety form, target audience.
- Version bumps for each update (`version:` in `pubspec.yaml`, e.g. `1.0.0+2`).

## ⚠️ Important before publishing publicly

This app currently shows **Alfamart/Indomaret product names and photos** pulled
from their sites. That was fine for your private web store, but the Play Store is
**public, global, and reviewed by Google**. Publishing third-party brand names,
logos, and product photos you don't have rights to can lead to:

- Google Play **rejection** (impersonation / intellectual-property policy), or
- **takedown / trademark complaints** from Alfamart/Indomaret.

Before submitting, strongly consider: use **your own product photos and
descriptions**, present Paramall clearly as an independent personal-shopper /
delivery service (not affiliated with Alfamart/Indomaret), and ideally get the
real backend in place so orders and accounts are first-class. Happy to help
rework the catalog to your own assets when you're ready.
