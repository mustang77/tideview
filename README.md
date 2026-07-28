# Al-Quran

A complete Al-Quran mobile app built with Flutter.

## Features

- **All 114 surahs** — instant offline index with Arabic names, meanings,
  revelation place and ayah counts, plus quick surah search.
- **Reading view** — Uthmani Arabic script (Amiri font), your choice of
  translation, optional Latin transliteration, adjustable Arabic text size,
  and Bismillah headers.
- **Audio recitation** — verse-by-verse playback with four reciters
  (Alafasy, Abdul Basit, As-Sudais, Al-Husary), continuous play with
  auto-advance and auto-scroll, and a mini player bar.
- **Juz index** — jump straight to any of the 30 juz.
- **Search** — full-text search across the selected translation.
- **Bookmarks** — save any ayah, swipe to remove, tap to jump back.
- **Last read** — the app remembers where you stopped and offers to resume.
- **Prayer times** — daily salah times for any city (Aladhan API), with
  Hijri date.
- **Translations** — English (Saheeh International), Indonesian (Kemenag),
  Urdu, French and Turkish.
- **Light / dark theme** with a green Islamic palette.

## Data sources

- Quran text, translations, transliteration and search:
  [AlQuran Cloud API](https://alquran.cloud/api)
- Recitation audio: [Islamic Network CDN](https://cdn.islamic.network)
- Prayer times: [Aladhan API](https://aladhan.com/prayer-times-api)

## Running

```sh
flutter pub get
flutter run
```

An internet connection is required for verse text, audio and prayer times;
the surah/juz index works offline.
