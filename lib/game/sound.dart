import "package:audioplayers/audioplayers.dart";
import "package:flutter/foundation.dart";

/// Fire-and-forget sound effects for the cooking game.
///
/// A small pool of players is rotated so overlapping effects don't cut
/// each other off. All failures are swallowed — audio must never break
/// gameplay (e.g. on web before the first user gesture).
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  static const _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool enabled = true;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      for (var i = 0; i < _poolSize; i++) {
        final p = AudioPlayer(playerId: "sfx_$i");
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        _pool.add(p);
      }
      _ready = true;
    } catch (e) {
      debugPrint("Sfx init failed: $e");
    }
  }

  void play(String name, {double volume = 1.0}) {
    if (!enabled || !_ready || _pool.isEmpty) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    // Deliberately not awaited; errors are non-fatal.
    p
        .play(AssetSource("audio/$name.wav"), volume: volume)
        .catchError((Object e) => debugPrint("Sfx $name failed: $e"));
  }

  void tap() => play("tap", volume: 0.5);
  void ding() => play("ding", volume: 0.8);
  void sizzle() => play("sizzle", volume: 0.6);
  void coin() => play("coin", volume: 0.7);
  void serve() => play("serve", volume: 0.8);
  void angry() => play("angry", volume: 0.8);
  void burnt() => play("burnt", volume: 0.8);
  void star() => play("star", volume: 0.8);
  void win() => play("win", volume: 0.9);
  void lose() => play("lose", volume: 0.9);
  void trash() => play("trash", volume: 0.6);
}
