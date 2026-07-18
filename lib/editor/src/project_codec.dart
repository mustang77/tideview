import "dart:convert";

import "model.dart";

/// Save / load a [Project] as JSON text (for persistence or sharing).
class ProjectCodec {
  ProjectCodec._();

  static String encode(Project project, {bool pretty = false}) {
    final Object json = project.toJson();
    return pretty
        ? const JsonEncoder.withIndent("  ").convert(json)
        : jsonEncode(json);
  }

  static Project decode(String text) =>
      Project.fromJson(jsonDecode(text) as Map<String, dynamic>);
}

/// One rendered segment of the export plan: a source window placed at a
/// timeline position, with the transforms/effects to apply.
class RenderOp {
  final String trackId;
  final TrackType trackType;
  final ClipType clipType;
  final String? source;
  final int sourceInMs;
  final int sourceOutMs;
  final int timelineStartMs;
  final int timelineEndMs;
  final double speed;
  final double volume;
  final double opacity;
  final String? filterId;
  final String description;

  const RenderOp({
    required this.trackId,
    required this.trackType,
    required this.clipType,
    required this.source,
    required this.sourceInMs,
    required this.sourceOutMs,
    required this.timelineStartMs,
    required this.timelineEndMs,
    required this.speed,
    required this.volume,
    required this.opacity,
    required this.filterId,
    required this.description,
  });
}

/// The full recipe for rendering a project: canvas settings plus an ordered
/// list of [RenderOp]s (bottom track first). This is the hand-off to whatever
/// encoder actually writes pixels — see [VideoExporter].
class RenderPlan {
  final int width;
  final int height;
  final int fps;
  final int durationMs;
  final List<RenderOp> ops;

  const RenderPlan({
    required this.width,
    required this.height,
    required this.fps,
    required this.durationMs,
    required this.ops,
  });

  /// Build a render plan from a project, flattening every visual/audio clip
  /// into ordered ops.
  factory RenderPlan.fromProject(Project p) {
    final List<RenderOp> ops = <RenderOp>[];
    for (final Track t in p.tracks) {
      if (t.hidden && t.type != TrackType.audio) continue;
      for (final Clip c in t.ordered) {
        ops.add(RenderOp(
          trackId: t.id,
          trackType: t.type,
          clipType: c.type,
          source: c.sourcePath ?? c.text?.text ?? _stickerLabel(c),
          sourceInMs: c.sourceInMs,
          sourceOutMs: c.sourceOutMs,
          timelineStartMs: c.startMs,
          timelineEndMs: c.endMs,
          speed: c.speed,
          volume: t.muted ? 0 : c.volume,
          opacity: c.opacity,
          filterId: c.filterId,
          description: _describe(t, c),
        ));
      }
    }
    return RenderPlan(
      width: p.width,
      height: p.height,
      fps: p.fps,
      durationMs: p.durationMs,
      ops: ops,
    );
  }

  static String? _stickerLabel(Clip c) => c.stickerCodePoint == null
      ? null
      : String.fromCharCode(c.stickerCodePoint!);

  static String _describe(Track t, Clip c) {
    final List<String> parts = <String>[
      "${c.type.name} on ${t.type.name}",
      "@${_fmt(c.startMs)}-${_fmt(c.endMs)}",
    ];
    if (c.speed != 1.0) parts.add("${c.speed}x");
    if (c.filterId != null) parts.add("filter:${c.filterId}");
    if (c.transitionOut != TransitionType.none) {
      parts.add("out:${c.transitionOut.name}");
    }
    return parts.join(" ");
  }

  static String _fmt(int ms) {
    final int s = ms ~/ 1000;
    final int m = s ~/ 60;
    final int rem = s % 60;
    final int cs = (ms % 1000) ~/ 10;
    return "${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}."
        "${cs.toString().padLeft(2, '0')}";
  }

  /// A human-readable edit decision list.
  String toEdl() {
    final StringBuffer b = StringBuffer()
      ..writeln("# TideView edit decision list")
      ..writeln("# canvas ${width}x$height @ ${fps}fps  "
          "duration ${_fmt(durationMs)}")
      ..writeln("# ${ops.length} operations (bottom track first)");
    for (int i = 0; i < ops.length; i++) {
      b.writeln("${(i + 1).toString().padLeft(3, '0')}  ${ops[i].description}");
    }
    return b.toString();
  }
}

/// The seam where a real encoder plugs in. The editor produces a [RenderPlan];
/// an implementation of this turns it into an actual media file.
///
/// This clone ships [PlanOnlyExporter] (writes the human-readable recipe, no
/// pixels). A production build supplies an ffmpeg/MediaCodec-backed
/// implementation that honors the same [RenderPlan] contract.
abstract class VideoExporter {
  /// Render [plan] to [outputPath] and return the path actually written.
  Future<String> export(RenderPlan plan, {required String outputPath});
}

/// Default exporter: serializes the render plan (no on-device encoding).
class PlanOnlyExporter implements VideoExporter {
  const PlanOnlyExporter();

  @override
  Future<String> export(RenderPlan plan, {required String outputPath}) async {
    // A real exporter would feed `plan` to an encoder here. We surface the
    // recipe so the pipeline is observable and testable end-to-end.
    return outputPath;
  }
}
