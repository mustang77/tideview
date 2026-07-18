import "package:flutter/material.dart";
import "package:video_player/video_player.dart";

import "../src/edit_controller.dart";
import "../src/filters.dart";
import "../src/model.dart";

/// The composited preview: the base video (color-filtered) with text and
/// sticker overlays stacked and positioned on top, all clipped to the project
/// canvas. Reads everything it needs off the [EditController] at the current
/// playhead.
class PreviewStage extends StatelessWidget {
  final EditController controller;
  final VideoPlayerController? videoController;
  final bool videoReady;

  const PreviewStage({
    super.key,
    required this.controller,
    required this.videoController,
    required this.videoReady,
  });

  /// Fade-in/out multiplier for a clip at the current playhead, times opacity.
  double _alpha(Clip c, int ms) {
    double a = c.opacity;
    if (c.transitionIn != TransitionType.none) {
      final int into = ms - c.startMs;
      if (into < c.transitionMs) a *= (into / c.transitionMs).clamp(0.0, 1.0);
    }
    if (c.transitionOut != TransitionType.none) {
      final int left = c.endMs - ms;
      if (left < c.transitionMs) a *= (left / c.transitionMs).clamp(0.0, 1.0);
    }
    return a.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final Project project = controller.project;
    return Center(
      child: AspectRatio(
        aspectRatio: project.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double scale = constraints.maxHeight / project.height;
            final int ms = controller.playheadMs;
            final Clip? base = controller.videoClipAt(ms);
            final List<Clip> overlays = controller
                .visualStackAt(ms)
                .where((c) =>
                    c.type == ClipType.text || c.type == ClipType.sticker)
                .toList();

            return ClipRect(
              child: Container(
                color: project.background,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildBase(base, ms),
                    for (final Clip c in overlays)
                      _buildOverlay(c, ms, scale, constraints.biggest),
                    if (base == null && !videoReady)
                      const Center(
                        child: Icon(Icons.movie_creation_outlined,
                            color: Colors.white24, size: 48),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBase(Clip? base, int ms) {
    if (base == null) return const SizedBox.shrink();
    Widget video;
    if (videoReady && videoController != null) {
      final Size s = videoController!.value.size;
      video = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: s.width == 0 ? 16 : s.width,
          height: s.height == 0 ? 9 : s.height,
          child: VideoPlayer(videoController!),
        ),
      );
    } else {
      video = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF1E2A44), Color(0xFF0A0E17)],
          ),
        ),
      );
    }

    final ColorFilter? filter = EditorFilters.colorFilterFor(base.filterId);
    if (filter != null) {
      video = ColorFiltered(colorFilter: filter, child: video);
    }
    return Opacity(opacity: _alpha(base, ms), child: video);
  }

  Widget _buildOverlay(Clip c, int ms, double scale, Size canvas) {
    final double a = _alpha(c, ms);
    Widget child;
    if (c.type == ClipType.text && c.text != null) {
      final TextStyleSpec spec = c.text!;
      child = Container(
        padding: EdgeInsets.symmetric(
            horizontal: 10 * scale * c.transform.scale,
            vertical: 4 * scale * c.transform.scale),
        color: spec.background,
        child: Text(
          spec.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: spec.color,
            fontSize: spec.fontSize * scale * c.transform.scale,
            fontWeight: spec.bold ? FontWeight.w800 : FontWeight.w400,
            fontStyle: spec.italic ? FontStyle.italic : FontStyle.normal,
            height: 1.1,
            shadows: const <Shadow>[
              Shadow(color: Colors.black54, blurRadius: 6),
            ],
          ),
        ),
      );
    } else if (c.type == ClipType.sticker && c.stickerCodePoint != null) {
      child = Text(
        String.fromCharCode(c.stickerCodePoint!),
        style: TextStyle(fontSize: 96 * scale * c.transform.scale),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment(
        (c.transform.x * 2 - 1).clamp(-1.0, 1.0),
        (c.transform.y * 2 - 1).clamp(-1.0, 1.0),
      ),
      child: Opacity(
        opacity: a,
        child: Transform.rotate(angle: c.transform.rotation, child: child),
      ),
    );
  }
}
