import "package:shared_preferences/shared_preferences.dart";

import "models.dart";

/// Saved progress and settings for the cooking game.
class GameStorage {
  static const _coinsKey = "ck_total_coins";
  static const _servedKey = "ck_total_served";
  static const _soundKey = "ck_sound";
  static const _hapticsKey = "ck_haptics";

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String _starsKey(VenueId venue, int levelId) =>
      "ck_stars_${venue.name}_$levelId";

  String _bestKey(VenueId venue) => "ck_best_${venue.name}";

  int starsFor(VenueId venue, int levelId) =>
      _prefs?.getInt(_starsKey(venue, levelId)) ?? 0;

  int endlessBest(VenueId venue) => _prefs?.getInt(_bestKey(venue)) ?? 0;

  int get totalCoins => _prefs?.getInt(_coinsKey) ?? 0;

  int get totalServed => _prefs?.getInt(_servedKey) ?? 0;

  bool get soundOn => _prefs?.getBool(_soundKey) ?? true;

  bool get hapticsOn => _prefs?.getBool(_hapticsKey) ?? true;

  Future<void> setSoundOn(bool v) async => _prefs?.setBool(_soundKey, v);

  Future<void> setHapticsOn(bool v) async => _prefs?.setBool(_hapticsKey, v);

  int venueStars(VenueId venue) {
    var sum = 0;
    for (final level in levelsFor(venue)) {
      sum += starsFor(venue, level.id);
    }
    return sum;
  }

  int get totalStars =>
      kVenues.fold(0, (sum, v) => sum + venueStars(v.id));

  /// Highest unlocked level id in a venue (level 1 is always unlocked;
  /// each win unlocks the next).
  int unlockedLevel(VenueId venue) {
    var unlocked = 1;
    var id = 1;
    while (starsFor(venue, id) > 0) {
      unlocked = id + 1;
      id++;
    }
    return unlocked;
  }

  /// Endless mode opens once the venue's first four levels are beaten.
  bool endlessUnlocked(VenueId venue) => unlockedLevel(venue) > 4;

  Future<void> recordResult({
    required VenueId venue,
    required int levelId,
    required int stars,
    required int coins,
    required int served,
    bool endless = false,
  }) async {
    final p = _prefs;
    if (p == null) return;
    if (endless) {
      if (coins > endlessBest(venue)) {
        await p.setInt(_bestKey(venue), coins);
      }
    } else if (stars > starsFor(venue, levelId)) {
      await p.setInt(_starsKey(venue, levelId), stars);
    }
    await p.setInt(_coinsKey, totalCoins + coins);
    await p.setInt(_servedKey, totalServed + served);
  }
}
