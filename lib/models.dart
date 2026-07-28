/// Core data models for the Al-Quran app.
library;

class SurahInfo {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final String meaning;
  final int ayahCount;
  final bool isMeccan;

  const SurahInfo(this.number, this.nameArabic, this.nameEnglish, this.meaning,
      this.ayahCount, this.isMeccan);

  String get revelation => isMeccan ? "Meccan" : "Medinan";
}

class Ayah {
  /// Global ayah number across the whole Quran (1..6236), used for audio.
  final int globalNumber;
  final int numberInSurah;
  final String arabic;
  final String translation;
  final String transliteration;
  final int juz;

  const Ayah({
    required this.globalNumber,
    required this.numberInSurah,
    required this.arabic,
    required this.translation,
    required this.transliteration,
    required this.juz,
  });
}

class SurahContent {
  final SurahInfo info;
  final List<Ayah> ayahs;
  const SurahContent({required this.info, required this.ayahs});
}

class JuzInfo {
  final int number;
  final int startSurah;
  final int startAyah;
  const JuzInfo(this.number, this.startSurah, this.startAyah);
}

class VerseRef {
  final int surah;
  final int ayah;
  const VerseRef(this.surah, this.ayah);

  String get key => "$surah:$ayah";

  static VerseRef? parse(String s) {
    final parts = s.split(":");
    if (parts.length != 2) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return null;
    return VerseRef(a, b);
  }

  @override
  bool operator ==(Object other) =>
      other is VerseRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => surah * 1000 + ayah;
}

class SearchMatch {
  final int surah;
  final int ayahInSurah;
  final String text;
  const SearchMatch(
      {required this.surah, required this.ayahInSurah, required this.text});
}

class TranslationEdition {
  final String id;
  final String label;
  const TranslationEdition(this.id, this.label);
}

class Reciter {
  final String id;
  final String name;
  const Reciter(this.id, this.name);
}
