import "dart:ui" show Color;

/// What a clip carries on the timeline.
enum ClipType { video, image, audio, text, sticker }

/// The kind of track a clip lives on. Order here is bottom-to-top compositing
/// intent: video is the base, overlays/text/stickers stack above, audio is
/// silent visually.
enum TrackType { video, overlay, text, audio }

/// Transition applied at a clip boundary.
enum TransitionType { none, fade, slideLeft, slideRight, zoom, wipe }

/// Normalized 2D placement for overlay/text/sticker clips. Position is a
/// fraction of the canvas (0..1, 0.5/0.5 = centered); scale is relative to the
/// natural size; rotation is in radians.
class Transform2D {
  final double x;
  final double y;
  final double scale;
  final double rotation;

  const Transform2D({
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  Transform2D copyWith({double? x, double? y, double? scale, double? rotation}) =>
      Transform2D(
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toJson() =>
      {"x": x, "y": y, "scale": scale, "rotation": rotation};

  factory Transform2D.fromJson(Map<String, dynamic> j) => Transform2D(
        x: (j["x"] as num).toDouble(),
        y: (j["y"] as num).toDouble(),
        scale: (j["scale"] as num).toDouble(),
        rotation: (j["rotation"] as num).toDouble(),
      );
}

/// Text styling for a [ClipType.text] clip.
class TextStyleSpec {
  final String text;
  final double fontSize; // px in canvas space
  final int colorValue;
  final int? backgroundValue;
  final bool bold;
  final bool italic;

  const TextStyleSpec({
    required this.text,
    this.fontSize = 48,
    this.colorValue = 0xFFFFFFFF,
    this.backgroundValue,
    this.bold = true,
    this.italic = false,
  });

  Color get color => Color(colorValue);
  Color? get background =>
      backgroundValue == null ? null : Color(backgroundValue!);

  TextStyleSpec copyWith({
    String? text,
    double? fontSize,
    int? colorValue,
    int? backgroundValue,
    bool? bold,
    bool? italic,
    bool clearBackground = false,
  }) =>
      TextStyleSpec(
        text: text ?? this.text,
        fontSize: fontSize ?? this.fontSize,
        colorValue: colorValue ?? this.colorValue,
        backgroundValue:
            clearBackground ? null : (backgroundValue ?? this.backgroundValue),
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
      );

  Map<String, dynamic> toJson() => {
        "text": text,
        "fontSize": fontSize,
        "colorValue": colorValue,
        "backgroundValue": backgroundValue,
        "bold": bold,
        "italic": italic,
      };

  factory TextStyleSpec.fromJson(Map<String, dynamic> j) => TextStyleSpec(
        text: j["text"] as String,
        fontSize: (j["fontSize"] as num).toDouble(),
        colorValue: j["colorValue"] as int,
        backgroundValue: j["backgroundValue"] as int?,
        bold: j["bold"] as bool,
        italic: j["italic"] as bool,
      );
}

/// A single segment on the timeline.
///
/// Time model (all milliseconds, integer):
///  - [sourceInMs] / [sourceOutMs] select a window inside the source media.
///  - [startMs] is where the clip begins on its track's timeline.
///  - [speed] stretches or compresses that window on the timeline.
///
/// So the raw (source) length is `sourceOutMs - sourceInMs`, and the length it
/// occupies on the timeline is that divided by [speed].
class Clip {
  final String id;
  final ClipType type;
  final String? sourcePath;
  final int sourceInMs;
  final int sourceOutMs;
  final int startMs;
  final double speed;
  final double volume;
  final double opacity;

  /// Id of a Banuba effect / color grade applied to this clip (null = none).
  final String? filterId;

  final TransitionType transitionIn;
  final TransitionType transitionOut;
  final int transitionMs;

  final Transform2D transform;
  final TextStyleSpec? text;

  /// Emoji code point for a [ClipType.sticker].
  final int? stickerCodePoint;

  const Clip({
    required this.id,
    required this.type,
    this.sourcePath,
    required this.sourceInMs,
    required this.sourceOutMs,
    required this.startMs,
    this.speed = 1.0,
    this.volume = 1.0,
    this.opacity = 1.0,
    this.filterId,
    this.transitionIn = TransitionType.none,
    this.transitionOut = TransitionType.none,
    this.transitionMs = 400,
    this.transform = const Transform2D(),
    this.text,
    this.stickerCodePoint,
  });

  /// Raw source length in ms (before speed).
  int get rawDurationMs => sourceOutMs - sourceInMs;

  /// Length occupied on the timeline in ms (after speed).
  int get durationMs => (rawDurationMs / speed).round();

  /// Exclusive end position on the timeline.
  int get endMs => startMs + durationMs;

  bool get isVisual =>
      type == ClipType.video ||
      type == ClipType.image ||
      type == ClipType.text ||
      type == ClipType.sticker;

  bool get hasAudio => type == ClipType.video || type == ClipType.audio;

  /// True if the timeline position [ms] falls within this clip.
  bool coversTimeline(int ms) => ms >= startMs && ms < endMs;

  /// Map a timeline position to the corresponding position inside the source
  /// media, honoring trim and speed.
  int sourceTimeAt(int timelineMs) {
    final int offset = timelineMs - startMs;
    return (sourceInMs + offset * speed).round().clamp(sourceInMs, sourceOutMs);
  }

  Clip copyWith({
    String? id,
    ClipType? type,
    String? sourcePath,
    int? sourceInMs,
    int? sourceOutMs,
    int? startMs,
    double? speed,
    double? volume,
    double? opacity,
    String? filterId,
    bool clearFilter = false,
    TransitionType? transitionIn,
    TransitionType? transitionOut,
    int? transitionMs,
    Transform2D? transform,
    TextStyleSpec? text,
    int? stickerCodePoint,
  }) =>
      Clip(
        id: id ?? this.id,
        type: type ?? this.type,
        sourcePath: sourcePath ?? this.sourcePath,
        sourceInMs: sourceInMs ?? this.sourceInMs,
        sourceOutMs: sourceOutMs ?? this.sourceOutMs,
        startMs: startMs ?? this.startMs,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        opacity: opacity ?? this.opacity,
        filterId: clearFilter ? null : (filterId ?? this.filterId),
        transitionIn: transitionIn ?? this.transitionIn,
        transitionOut: transitionOut ?? this.transitionOut,
        transitionMs: transitionMs ?? this.transitionMs,
        transform: transform ?? this.transform,
        text: text ?? this.text,
        stickerCodePoint: stickerCodePoint ?? this.stickerCodePoint,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "type": type.name,
        "sourcePath": sourcePath,
        "sourceInMs": sourceInMs,
        "sourceOutMs": sourceOutMs,
        "startMs": startMs,
        "speed": speed,
        "volume": volume,
        "opacity": opacity,
        "filterId": filterId,
        "transitionIn": transitionIn.name,
        "transitionOut": transitionOut.name,
        "transitionMs": transitionMs,
        "transform": transform.toJson(),
        "text": text?.toJson(),
        "stickerCodePoint": stickerCodePoint,
      };

  factory Clip.fromJson(Map<String, dynamic> j) => Clip(
        id: j["id"] as String,
        type: ClipType.values.byName(j["type"] as String),
        sourcePath: j["sourcePath"] as String?,
        sourceInMs: j["sourceInMs"] as int,
        sourceOutMs: j["sourceOutMs"] as int,
        startMs: j["startMs"] as int,
        speed: (j["speed"] as num).toDouble(),
        volume: (j["volume"] as num).toDouble(),
        opacity: (j["opacity"] as num).toDouble(),
        filterId: j["filterId"] as String?,
        transitionIn:
            TransitionType.values.byName(j["transitionIn"] as String),
        transitionOut:
            TransitionType.values.byName(j["transitionOut"] as String),
        transitionMs: j["transitionMs"] as int,
        transform:
            Transform2D.fromJson(j["transform"] as Map<String, dynamic>),
        text: j["text"] == null
            ? null
            : TextStyleSpec.fromJson(j["text"] as Map<String, dynamic>),
        stickerCodePoint: j["stickerCodePoint"] as int?,
      );
}

/// An ordered lane of clips.
class Track {
  final String id;
  final TrackType type;
  final List<Clip> clips;
  final bool muted;
  final bool locked;
  final bool hidden;
  final String name;

  const Track({
    required this.id,
    required this.type,
    this.clips = const <Clip>[],
    this.muted = false,
    this.locked = false,
    this.hidden = false,
    this.name = "",
  });

  int get durationMs =>
      clips.fold(0, (m, c) => c.endMs > m ? c.endMs : m);

  /// Clips sorted by their start position.
  List<Clip> get ordered =>
      List<Clip>.from(clips)..sort((a, b) => a.startMs.compareTo(b.startMs));

  /// The clip covering timeline position [ms], if any (last one wins on
  /// overlap, i.e. the most recently stacked).
  Clip? clipAt(int ms) {
    Clip? found;
    for (final Clip c in clips) {
      if (c.coversTimeline(ms)) found = c;
    }
    return found;
  }

  Track copyWith({
    List<Clip>? clips,
    bool? muted,
    bool? locked,
    bool? hidden,
    String? name,
  }) =>
      Track(
        id: id,
        type: type,
        clips: clips ?? this.clips,
        muted: muted ?? this.muted,
        locked: locked ?? this.locked,
        hidden: hidden ?? this.hidden,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "type": type.name,
        "muted": muted,
        "locked": locked,
        "hidden": hidden,
        "name": name,
        "clips": clips.map((c) => c.toJson()).toList(),
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: j["id"] as String,
        type: TrackType.values.byName(j["type"] as String),
        muted: j["muted"] as bool,
        locked: j["locked"] as bool,
        hidden: j["hidden"] as bool,
        name: j["name"] as String,
        clips: (j["clips"] as List)
            .map((c) => Clip.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// A full edit: a stack of tracks plus canvas settings.
class Project {
  final String id;
  final String name;
  final List<Track> tracks;
  final int width;
  final int height;
  final int fps;
  final int backgroundValue;

  const Project({
    required this.id,
    required this.name,
    required this.tracks,
    this.width = 1080,
    this.height = 1920,
    this.fps = 30,
    this.backgroundValue = 0xFF000000,
  });

  Color get background => Color(backgroundValue);
  double get aspectRatio => width / height;

  /// Total timeline length: the furthest clip end across all tracks.
  int get durationMs =>
      tracks.fold(0, (m, t) => t.durationMs > m ? t.durationMs : m);

  Iterable<Clip> get allClips => tracks.expand((t) => t.clips);

  Track? trackById(String trackId) {
    for (final Track t in tracks) {
      if (t.id == trackId) return t;
    }
    return null;
  }

  /// Find a clip and the track containing it.
  ({Track track, Clip clip})? locate(String clipId) {
    for (final Track t in tracks) {
      for (final Clip c in t.clips) {
        if (c.id == clipId) return (track: t, clip: c);
      }
    }
    return null;
  }

  Project copyWith({
    String? name,
    List<Track>? tracks,
    int? width,
    int? height,
    int? fps,
    int? backgroundValue,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        width: width ?? this.width,
        height: height ?? this.height,
        fps: fps ?? this.fps,
        backgroundValue: backgroundValue ?? this.backgroundValue,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "width": width,
        "height": height,
        "fps": fps,
        "backgroundValue": backgroundValue,
        "tracks": tracks.map((t) => t.toJson()).toList(),
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j["id"] as String,
        name: j["name"] as String,
        width: j["width"] as int,
        height: j["height"] as int,
        fps: j["fps"] as int,
        backgroundValue: j["backgroundValue"] as int,
        tracks: (j["tracks"] as List)
            .map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
