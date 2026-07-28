import "dart:convert";

import "package:http/http.dart" as http;

import "models.dart";
import "quran_data.dart";

/// Fetches Quran text, translations and search results from api.alquran.cloud.
/// Loaded surahs are cached in memory for the session.
class QuranService {
  static const String _base = "https://api.alquran.cloud/v1";
  static const String audioBase = "https://cdn.islamic.network/quran/audio/64";

  final Map<String, SurahContent> _cache = {};

  static String audioUrl(String reciterId, int globalAyahNumber) =>
      "$audioBase/$reciterId/$globalAyahNumber.mp3";

  /// Loads a surah with Arabic text, the chosen translation and a Latin
  /// transliteration in a single request.
  Future<SurahContent> loadSurah(int surahNumber, String translationId) async {
    final cacheKey = "$surahNumber|$translationId";
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final editions = "quran-uthmani,$translationId,en.transliteration";
    final uri = Uri.parse("$_base/surah/$surahNumber/editions/$editions");
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception("Failed to load surah (HTTP ${res.statusCode})");
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final data = body["data"] as List<dynamic>;
    if (data.length < 3) throw Exception("Unexpected API response");

    final arabicAyahs = (data[0] as Map<String, dynamic>)["ayahs"] as List;
    final translationAyahs = (data[1] as Map<String, dynamic>)["ayahs"] as List;
    final translitAyahs = (data[2] as Map<String, dynamic>)["ayahs"] as List;

    final ayahs = <Ayah>[];
    for (var i = 0; i < arabicAyahs.length; i++) {
      final a = arabicAyahs[i] as Map<String, dynamic>;
      final numberInSurah = a["numberInSurah"] as int;
      var arabic = (a["text"] as String).trim();
      if (surahNumber != 1 && surahNumber != 9 && numberInSurah == 1) {
        arabic = _stripBismillah(arabic);
      }
      ayahs.add(Ayah(
        globalNumber: a["number"] as int,
        numberInSurah: numberInSurah,
        arabic: arabic,
        translation:
            ((translationAyahs[i] as Map<String, dynamic>)["text"] as String)
                .trim(),
        transliteration:
            ((translitAyahs[i] as Map<String, dynamic>)["text"] as String)
                .trim(),
        juz: a["juz"] as int? ?? 0,
      ));
    }

    final content =
        SurahContent(info: surahByNumber(surahNumber), ayahs: ayahs);
    _cache[cacheKey] = content;
    return content;
  }

  /// The Uthmani text of the first ayah of every surah (except Al-Fatihah and
  /// At-Tawbah) is prefixed with the Bismillah; strip it so it can be shown
  /// once as a header instead.
  static final RegExp _bismillahEnd = RegExp(
      "ح[\\u064B-\\u065F\\u0670]*ي[\\u064B-\\u065F\\u0670]*م[\\u064B-\\u065F\\u0670]*");

  static String _stripBismillah(String text) {
    // The Bismillah always ends with the word الرحيم; cut just past its first
    // occurrence (allowing any combining diacritics between the letters)
    // rather than matching one exact spelling.
    final match = _bismillahEnd.firstMatch(text);
    if (match == null) return text;
    final rest = text.substring(match.end).trim();
    return rest.isEmpty ? text : rest;
  }

  /// Full-text search within the given translation edition.
  Future<List<SearchMatch>> search(String query, String translationId) async {
    final q = Uri.encodeComponent(query.trim());
    final uri = Uri.parse("$_base/search/$q/all/$translationId");
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) {
      throw Exception("Search failed (HTTP ${res.statusCode})");
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final data = body["data"] as Map<String, dynamic>?;
    final matches = data?["matches"] as List<dynamic>? ?? const [];
    return matches.map((m) {
      final map = m as Map<String, dynamic>;
      final surah = (map["surah"] as Map<String, dynamic>)["number"] as int;
      return SearchMatch(
        surah: surah,
        ayahInSurah: map["numberInSurah"] as int,
        text: map["text"] as String,
      );
    }).toList();
  }
}

/// Fetches prayer times from api.aladhan.com by city name.
class PrayerTimesService {
  Future<PrayerTimesResult> byCity(String city, String country) async {
    final uri = Uri.parse(
        "https://api.aladhan.com/v1/timingsByCity?city=${Uri.encodeComponent(city)}&country=${Uri.encodeComponent(country)}");
    final res = await http.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception("Could not fetch prayer times (HTTP ${res.statusCode})");
    }
    final body = json.decode(res.body) as Map<String, dynamic>;
    final data = body["data"] as Map<String, dynamic>;
    final timings = (data["timings"] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v.toString()));
    final date = data["date"] as Map<String, dynamic>;
    final readable = date["readable"] as String? ?? "";
    final hijri = date["hijri"] as Map<String, dynamic>?;
    final hijriText = hijri == null
        ? ""
        : "${hijri["day"]} ${(hijri["month"] as Map<String, dynamic>)["en"]} ${hijri["year"]} AH";
    return PrayerTimesResult(
        timings: timings, gregorianDate: readable, hijriDate: hijriText);
  }
}

class PrayerTimesResult {
  final Map<String, String> timings;
  final String gregorianDate;
  final String hijriDate;
  const PrayerTimesResult(
      {required this.timings,
      required this.gregorianDate,
      required this.hijriDate});
}
