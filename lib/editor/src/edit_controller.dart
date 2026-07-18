import "package:flutter/foundation.dart";

import "model.dart";

/// The editing engine an editor screen holds. Wraps a [Project], applies
/// timeline operations (split / trim / move / speed / filters / text / …),
/// tracks selection + playhead + zoom, and keeps a snapshot-based undo/redo
/// history. All mutating operations snapshot first and then [notifyListeners].
class EditController extends ChangeNotifier {
  Project _project;
  final List<Project> _undo = <Project>[];
  final List<Project> _redo = <Project>[];
  int _idCounter = 0;

  String? _selectedClipId;
  int _playheadMs = 0;
  bool _playing = false;

  /// Timeline zoom, in pixels per millisecond.
  double _pxPerMs = 0.06;

  EditController(this._project);

  // ---- read-only state -----------------------------------------------------

  Project get project => _project;
  String? get selectedClipId => _selectedClipId;
  int get playheadMs => _playheadMs;
  bool get isPlaying => _playing;
  double get pxPerMs => _pxPerMs;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get durationMs => _project.durationMs;

  Clip? get selectedClip {
    final String? id = _selectedClipId;
    if (id == null) return null;
    return _project.locate(id)?.clip;
  }

  /// New unique id for a created clip/track.
  String _newId(String prefix) => "${prefix}_${_idCounter++}";

  // ---- history -------------------------------------------------------------

  void _snapshot() {
    _undo.add(_project);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_project);
    _project = _undo.removeLast();
    _clampSelectionAndPlayhead();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_project);
    _project = _redo.removeLast();
    _clampSelectionAndPlayhead();
    notifyListeners();
  }

  // ---- selection / transport ----------------------------------------------

  void select(String? clipId) {
    if (_selectedClipId == clipId) return;
    _selectedClipId = clipId;
    notifyListeners();
  }

  void setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    notifyListeners();
  }

  void seek(int ms) {
    final int clamped = ms.clamp(0, durationMs == 0 ? 0 : durationMs);
    if (_playheadMs == clamped) return;
    _playheadMs = clamped;
    notifyListeners();
  }

  void setZoom(double pxPerMs) {
    _pxPerMs = pxPerMs.clamp(0.008, 0.6);
    notifyListeners();
  }

  void _clampSelectionAndPlayhead() {
    if (_selectedClipId != null && _project.locate(_selectedClipId!) == null) {
      _selectedClipId = null;
    }
    _playheadMs = _playheadMs.clamp(0, durationMs == 0 ? 0 : durationMs);
  }

  // ---- track helpers -------------------------------------------------------

  List<Track> _replaceTrack(Track updated) {
    return _project.tracks
        .map((t) => t.id == updated.id ? updated : t)
        .toList();
  }

  String addTrack(TrackType type, {String name = ""}) {
    _snapshot();
    final String id = _newId("track");
    _project = _project.copyWith(
      tracks: <Track>[
        ..._project.tracks,
        Track(id: id, type: type, name: name),
      ],
    );
    notifyListeners();
    return id;
  }

  // ---- clip operations -----------------------------------------------------

  /// Append [clip] to the given track. If [clip.id] is empty a fresh id is
  /// assigned. Returns the stored clip.
  Clip addClip(String trackId, Clip clip) {
    final Track? track = _project.trackById(trackId);
    if (track == null) return clip;
    _snapshot();
    final Clip stored =
        clip.id.isEmpty ? clip.copyWith(id: _newId("clip")) : clip;
    _project = _project.copyWith(
      tracks: _replaceTrack(
        track.copyWith(clips: <Clip>[...track.clips, stored]),
      ),
    );
    _selectedClipId = stored.id;
    notifyListeners();
    return stored;
  }

  /// Append a clip to the end of a track's current content.
  Clip appendClip(String trackId, Clip clip) {
    final Track? track = _project.trackById(trackId);
    if (track == null) return clip;
    return addClip(trackId, clip.copyWith(startMs: track.durationMs));
  }

  void removeClip(String clipId) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    _snapshot();
    _project = _project.copyWith(
      tracks: _replaceTrack(
        loc.track.copyWith(
          clips: loc.track.clips.where((c) => c.id != clipId).toList(),
        ),
      ),
    );
    if (_selectedClipId == clipId) _selectedClipId = null;
    notifyListeners();
  }

  void duplicateClip(String clipId) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    _snapshot();
    final Clip copy = loc.clip.copyWith(
      id: _newId("clip"),
      startMs: loc.clip.endMs,
    );
    _project = _project.copyWith(
      tracks: _replaceTrack(
        loc.track.copyWith(clips: <Clip>[...loc.track.clips, copy]),
      ),
    );
    _selectedClipId = copy.id;
    notifyListeners();
  }

  /// Split the clip at absolute timeline position [timelineMs]. No-op unless
  /// the split falls strictly inside the clip.
  void splitAt(String clipId, int timelineMs) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    final Clip c = loc.clip;
    if (timelineMs <= c.startMs || timelineMs >= c.endMs) return;
    _snapshot();
    final int sourceCut = c.sourceTimeAt(timelineMs);
    final Clip left = c.copyWith(
      sourceOutMs: sourceCut,
      transitionOut: TransitionType.none,
    );
    final Clip right = c.copyWith(
      id: _newId("clip"),
      sourceInMs: sourceCut,
      startMs: timelineMs,
      transitionIn: TransitionType.none,
    );
    final List<Clip> next = loc.track.clips
        .expand((x) => x.id == clipId ? <Clip>[left, right] : <Clip>[x])
        .toList();
    _project =
        _project.copyWith(tracks: _replaceTrack(loc.track.copyWith(clips: next)));
    _selectedClipId = right.id;
    notifyListeners();
  }

  /// Begin a continuous drag gesture: snapshots history once so the whole
  /// gesture is a single undo step. Follow with the `*Live` mutators.
  void beginInteraction() => _snapshot();

  /// Drag the left edge to a new timeline position, trimming source-in
  /// (snapshots history — for a continuous drag use [trimStartLive]).
  void trimStart(String clipId, int newStartMs) {
    _snapshot();
    trimStartLive(clipId, newStartMs);
  }

  void trimStartLive(String clipId, int newStartMs) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    final Clip c = loc.clip;
    // Keep at least ~50ms of content and stay before the current end.
    final int maxStart = c.endMs - 50;
    final int clampedStart = newStartMs.clamp(0, maxStart);
    final int deltaTimeline = clampedStart - c.startMs;
    final int newSourceIn =
        (c.sourceInMs + deltaTimeline * c.speed).round().clamp(0, c.sourceOutMs - 1);
    final Clip updated =
        c.copyWith(startMs: clampedStart, sourceInMs: newSourceIn);
    _project = _project.copyWith(
      tracks: _replaceTrack(_withClip(loc.track, updated)),
    );
    notifyListeners();
  }

  /// Drag the right edge to a new timeline end position, trimming source-out
  /// (snapshots history — for a continuous drag use [trimEndLive]).
  void trimEnd(String clipId, int newEndMs) {
    _snapshot();
    trimEndLive(clipId, newEndMs);
  }

  void trimEndLive(String clipId, int newEndMs) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    final Clip c = loc.clip;
    final int minEnd = c.startMs + 50;
    final int clampedEnd = newEndMs < minEnd ? minEnd : newEndMs;
    final int newRaw = ((clampedEnd - c.startMs) * c.speed).round();
    final int newSourceOut = (c.sourceInMs + newRaw).clamp(c.sourceInMs + 1, 1 << 31);
    final Clip updated = c.copyWith(sourceOutMs: newSourceOut);
    _project = _project.copyWith(
      tracks: _replaceTrack(_withClip(loc.track, updated)),
    );
    notifyListeners();
  }

  /// Move a clip to a new start position, optionally to another track of a
  /// compatible type (snapshots history — for a continuous drag use
  /// [moveClipLive]).
  void moveClip(String clipId, int newStartMs, {String? toTrackId}) {
    _snapshot();
    moveClipLive(clipId, newStartMs, toTrackId: toTrackId);
  }

  void moveClipLive(String clipId, int newStartMs, {String? toTrackId}) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    final Clip moved = loc.clip.copyWith(startMs: newStartMs < 0 ? 0 : newStartMs);
    if (toTrackId == null || toTrackId == loc.track.id) {
      _project = _project.copyWith(
        tracks: _replaceTrack(_withClip(loc.track, moved)),
      );
    } else {
      final Track? dest = _project.trackById(toTrackId);
      if (dest == null || dest.type != loc.track.type) {
        // Fall back to in-track move if the destination is incompatible.
        _project = _project.copyWith(
          tracks: _replaceTrack(_withClip(loc.track, moved)),
        );
      } else {
        final Track src = loc.track.copyWith(
          clips: loc.track.clips.where((c) => c.id != clipId).toList(),
        );
        final Track withMoved =
            dest.copyWith(clips: <Clip>[...dest.clips, moved]);
        _project = _project.copyWith(
          tracks: _project.tracks.map((t) {
            if (t.id == src.id) return src;
            if (t.id == withMoved.id) return withMoved;
            return t;
          }).toList(),
        );
      }
    }
    notifyListeners();
  }

  Track _withClip(Track track, Clip updated) => track.copyWith(
        clips: track.clips.map((c) => c.id == updated.id ? updated : c).toList(),
      );

  /// Generic per-clip property update that snapshots history.
  void updateClip(String clipId, Clip Function(Clip) transform) {
    final loc = _project.locate(clipId);
    if (loc == null) return;
    _snapshot();
    _project = _project.copyWith(
      tracks: _replaceTrack(_withClip(loc.track, transform(loc.clip))),
    );
    notifyListeners();
  }

  void setSpeed(String clipId, double speed) =>
      updateClip(clipId, (c) => c.copyWith(speed: speed.clamp(0.25, 4.0)));

  void setVolume(String clipId, double volume) =>
      updateClip(clipId, (c) => c.copyWith(volume: volume.clamp(0.0, 2.0)));

  void setOpacity(String clipId, double opacity) =>
      updateClip(clipId, (c) => c.copyWith(opacity: opacity.clamp(0.0, 1.0)));

  void setFilter(String clipId, String? filterId) => updateClip(
      clipId,
      (c) => filterId == null
          ? c.copyWith(clearFilter: true)
          : c.copyWith(filterId: filterId));

  void setTransitionOut(String clipId, TransitionType t) =>
      updateClip(clipId, (c) => c.copyWith(transitionOut: t));

  void setText(String clipId, TextStyleSpec text) =>
      updateClip(clipId, (c) => c.copyWith(text: text));

  void setTransform(String clipId, Transform2D transform) =>
      updateClip(clipId, (c) => c.copyWith(transform: transform));

  // ---- creation helpers ----------------------------------------------------

  /// Insert a text clip at the current playhead on the first text track
  /// (creating one if needed).
  String addTextAtPlayhead(String content, {int durationMs = 3000}) {
    Track? textTrack = _project.tracks
        .cast<Track?>()
        .firstWhere((t) => t!.type == TrackType.text, orElse: () => null);
    textTrack ??= _project.trackById(addTrack(TrackType.text, name: "Text"));
    final Clip clip = Clip(
      id: _newId("clip"),
      type: ClipType.text,
      sourceInMs: 0,
      sourceOutMs: durationMs,
      startMs: _playheadMs,
      text: TextStyleSpec(text: content),
    );
    addClip(textTrack!.id, clip);
    return clip.id;
  }

  /// The id of the first video track, creating one if the project has none.
  String ensureVideoTrack() {
    for (final Track t in _project.tracks) {
      if (t.type == TrackType.video) return t.id;
    }
    return addTrack(TrackType.video, name: "Video");
  }

  /// Import a media clip (video or image) onto the end of the video track.
  /// [durationMs] is the source length for video, or the desired on-screen
  /// duration for a still image.
  Clip importClip({
    required ClipType type,
    required String path,
    required int durationMs,
  }) {
    final String trackId = ensureVideoTrack();
    final Clip clip = Clip(
      id: "",
      type: type,
      sourcePath: path,
      sourceInMs: 0,
      sourceOutMs: durationMs,
      startMs: 0,
    );
    return appendClip(trackId, clip);
  }

  /// Insert a sticker (emoji) clip at the current playhead.
  String addStickerAtPlayhead(int codePoint, {int durationMs = 3000}) {
    Track? overlay = _project.tracks
        .cast<Track?>()
        .firstWhere((t) => t!.type == TrackType.overlay, orElse: () => null);
    overlay ??= _project.trackById(addTrack(TrackType.overlay, name: "Overlay"));
    final Clip clip = Clip(
      id: _newId("clip"),
      type: ClipType.sticker,
      sourceInMs: 0,
      sourceOutMs: durationMs,
      startMs: _playheadMs,
      stickerCodePoint: codePoint,
    );
    addClip(overlay!.id, clip);
    return clip.id;
  }

  // ---- compositing queries -------------------------------------------------

  /// The base video/image clip visible at [ms] (topmost video-track clip).
  Clip? videoClipAt(int ms) {
    for (final Track t in _project.tracks) {
      if (t.type != TrackType.video || t.hidden) continue;
      final Clip? c = t.clipAt(ms);
      if (c != null) return c;
    }
    return null;
  }

  /// Every visual clip active at [ms], ordered bottom track → top track so a
  /// renderer can paint them in order.
  List<Clip> visualStackAt(int ms) {
    final List<Clip> out = <Clip>[];
    for (final Track t in _project.tracks) {
      if (t.hidden) continue;
      final Clip? c = t.clipAt(ms);
      if (c != null && c.isVisual) out.add(c);
    }
    return out;
  }
}
