import "package:shared_preferences/shared_preferences.dart";

/// Saved progress for the cooking game (stars per level, lifetime coins).
class GameStorage {
  static const _starsPrefix = "ck_stars_";
  static const _coinsKey = "ck_total_coins";
  static const _servedKey = "ck_total_served";

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  int starsFor(int levelId) => _prefs?.getInt("$_starsPrefix$levelId") ?? 0;

  int get totalCoins => _prefs?.getInt(_coinsKey) ?? 0;

  int get totalServed => _prefs?.getInt(_servedKey) ?? 0;

  int get totalStars {
    var sum = 0;
    for (var id = 1; id <= 50; id++) {
      sum += starsFor(id);
    }
    return sum;
  }

  /// Highest unlocked level id (level 1 is always unlocked; each win
  /// unlocks the next).
  int get unlockedLevel {
    var unlocked = 1;
    var id = 1;
    while (starsFor(id) > 0) {
      unlocked = id + 1;
      id++;
    }
    return unlocked;
  }

  Future<void> recordResult({
    required int levelId,
    required int stars,
    required int coins,
    required int served,
  }) async {
    final p = _prefs;
    if (p == null) return;
    if (stars > starsFor(levelId)) {
      await p.setInt("$_starsPrefix$levelId", stars);
    }
    await p.setInt(_coinsKey, totalCoins + coins);
    await p.setInt(_servedKey, totalServed + served);
  }
}
