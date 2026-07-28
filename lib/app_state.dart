import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "models.dart";
import "quran_data.dart";

/// App-wide user state: display settings, bookmarks and reading position.
/// Persisted with SharedPreferences and exposed as a [ChangeNotifier].
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _themeMode = ThemeMode
        .values[_prefs.getInt(_kTheme)?.clamp(0, 2) ?? ThemeMode.system.index];
    _translationId = _prefs.getString(_kTranslation) ?? "en.sahih";
    if (!translationEditions.any((e) => e.id == _translationId)) {
      _translationId = "en.sahih";
    }
    _translation2Id = _prefs.getString(_kTranslation2) ?? "id.indonesian";
    if (_translation2Id.isNotEmpty &&
        !translationEditions.any((e) => e.id == _translation2Id)) {
      _translation2Id = "id.indonesian";
    }
    _reciterId = _prefs.getString(_kReciter) ?? "ar.alafasy";
    if (!reciters.any((r) => r.id == _reciterId)) {
      _reciterId = "ar.alafasy";
    }
    _showTransliteration = _prefs.getBool(_kTranslit) ?? false;
    _arabicFontSize = _prefs.getDouble(_kArabicSize) ?? 28;
    _lastRead = VerseRef.parse(_prefs.getString(_kLastRead) ?? "");
    _bookmarks
      ..clear()
      ..addAll((_prefs.getStringList(_kBookmarks) ?? const [])
          .map(VerseRef.parse)
          .whereType<VerseRef>());
    _prayerCity = _prefs.getString(_kPrayerCity) ?? "";
    _prayerCountry = _prefs.getString(_kPrayerCountry) ?? "";
  }

  static const _kTheme = "themeMode";
  static const _kTranslation = "translationId";
  static const _kTranslation2 = "translation2Id";
  static const _kReciter = "reciterId";
  static const _kTranslit = "showTransliteration";
  static const _kArabicSize = "arabicFontSize";
  static const _kLastRead = "lastRead";
  static const _kBookmarks = "bookmarks";
  static const _kPrayerCity = "prayerCity";
  static const _kPrayerCountry = "prayerCountry";

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late String _translationId;
  late String _translation2Id;
  late String _reciterId;
  late bool _showTransliteration;
  late double _arabicFontSize;
  VerseRef? _lastRead;
  final List<VerseRef> _bookmarks = [];
  late String _prayerCity;
  late String _prayerCountry;

  static Future<AppState> load() async =>
      AppState(await SharedPreferences.getInstance());

  ThemeMode get themeMode => _themeMode;
  String get translationId => _translationId;

  /// Edition id of the second translation, or "" when disabled.
  String get translation2Id => _translation2Id;
  String get reciterId => _reciterId;
  bool get showTransliteration => _showTransliteration;
  double get arabicFontSize => _arabicFontSize;
  VerseRef? get lastRead => _lastRead;
  List<VerseRef> get bookmarks => List.unmodifiable(_bookmarks);
  String get prayerCity => _prayerCity;
  String get prayerCountry => _prayerCountry;

  String get translationLabel => translationEditions
      .firstWhere((e) => e.id == _translationId)
      .label;

  String get translation2Label => _translation2Id.isEmpty
      ? "None"
      : translationEditions.firstWhere((e) => e.id == _translation2Id).label;

  String get reciterName =>
      reciters.firstWhere((r) => r.id == _reciterId).name;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs.setInt(_kTheme, mode.index);
    notifyListeners();
  }

  void setTranslation(String id) {
    _translationId = id;
    _prefs.setString(_kTranslation, id);
    notifyListeners();
  }

  void setTranslation2(String id) {
    _translation2Id = id;
    _prefs.setString(_kTranslation2, id);
    notifyListeners();
  }

  void setReciter(String id) {
    _reciterId = id;
    _prefs.setString(_kReciter, id);
    notifyListeners();
  }

  void setShowTransliteration(bool value) {
    _showTransliteration = value;
    _prefs.setBool(_kTranslit, value);
    notifyListeners();
  }

  void setArabicFontSize(double size) {
    _arabicFontSize = size;
    _prefs.setDouble(_kArabicSize, size);
    notifyListeners();
  }

  void setLastRead(VerseRef ref) {
    _lastRead = ref;
    _prefs.setString(_kLastRead, ref.key);
    notifyListeners();
  }

  bool isBookmarked(VerseRef ref) => _bookmarks.contains(ref);

  void toggleBookmark(VerseRef ref) {
    if (!_bookmarks.remove(ref)) _bookmarks.insert(0, ref);
    _prefs.setStringList(_kBookmarks, _bookmarks.map((b) => b.key).toList());
    notifyListeners();
  }

  void setPrayerLocation(String city, String country) {
    _prayerCity = city;
    _prayerCountry = country;
    _prefs.setString(_kPrayerCity, city);
    _prefs.setString(_kPrayerCountry, country);
    notifyListeners();
  }
}

/// Simple inherited access to the single [AppState] instance.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppScope>()!
      .notifier!;
}
