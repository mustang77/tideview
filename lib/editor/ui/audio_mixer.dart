import "package:audioplayers/audioplayers.dart";

import "../src/edit_controller.dart";
import "../src/model.dart";

/// One audio player bound to a single audio track.
class _Voice {
  final AudioPlayer player = AudioPlayer();
  String? loadedPath;
  String? clipId;
  bool started = false;

  Future<void> dispose() async {
    try {
      await player.dispose();
    } catch (_) {}
  }
}

/// Drives audio-track playback in step with the editor's master clock. For each
/// audio track it keeps one [AudioPlayer], loads the active clip's source,
/// seeks it to the timeline-mapped position on scrub/boundary crossing, applies
/// per-clip volume + track mute, and resumes/pauses with the transport.
///
/// Everything is wrapped defensively: if the audio backend misbehaves the
/// editor keeps working visually.
class AudioMixer {
  final EditController controller;
  final Map<String, _Voice> _voices = <String, _Voice>{};
  bool _disposed = false;

  AudioMixer(this.controller);

  static Source sourceFor(String path) {
    final Uri? uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == "http" || uri.scheme == "https")) {
      return UrlSource(path);
    }
    return DeviceFileSource(path);
  }

  /// Reconcile every audio track's player with the current playhead + state.
  Future<void> sync({required bool playing}) async {
    if (_disposed) return;
    final int ms = controller.playheadMs;
    final Set<String> live = <String>{};
    for (final Track t in controller.project.tracks) {
      if (t.type != TrackType.audio) continue;
      live.add(t.id);
      final _Voice voice = _voices.putIfAbsent(t.id, () => _Voice());
      final Clip? clip = t.clipAt(ms);
      if (clip == null || t.muted) {
        await _silence(voice);
      } else {
        await _drive(voice, clip, ms, playing);
      }
    }
    // Drop players for tracks that were removed.
    final List<String> gone =
        _voices.keys.where((k) => !live.contains(k)).toList();
    for (final String k in gone) {
      await _voices.remove(k)!.dispose();
    }
  }

  Future<void> _silence(_Voice v) async {
    if (!v.started) return;
    try {
      await v.player.pause();
    } catch (_) {}
    v.started = false;
    v.clipId = null;
  }

  Future<void> _drive(_Voice v, Clip clip, int ms, bool playing) async {
    final String? path = clip.sourcePath;
    if (path == null) return;
    try {
      final bool crossed = v.clipId != clip.id;
      if (v.loadedPath != path) {
        await v.player.setReleaseMode(ReleaseMode.stop);
        await v.player.setSource(sourceFor(path));
        v.loadedPath = path;
        v.started = false;
      }
      v.clipId = clip.id;
      await v.player.setVolume(clip.volume.clamp(0.0, 1.0));
      if (crossed || !playing) {
        await v.player.seek(Duration(milliseconds: clip.sourceTimeAt(ms)));
      }
      if (playing && !v.started) {
        await v.player.resume();
        v.started = true;
      } else if (!playing && v.started) {
        await v.player.pause();
        v.started = false;
      }
    } catch (_) {}
  }

  Future<void> pauseAll() async {
    for (final _Voice v in _voices.values) {
      try {
        await v.player.pause();
      } catch (_) {}
      v.started = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final _Voice v in _voices.values) {
      await v.dispose();
    }
    _voices.clear();
  }
}
