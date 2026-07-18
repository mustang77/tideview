import "package:flutter/material.dart";

import "../src/edit_controller.dart";
import "../src/filters.dart";
import "../src/model.dart";

/// The scrollable, zoomable multi-track timeline. Tap the ruler to seek, tap a
/// clip to select, drag a selected clip to move it, and drag its edge handles
/// to trim. Pinch anywhere to zoom.
class TimelineView extends StatefulWidget {
  final EditController controller;
  const TimelineView({super.key, required this.controller});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final ScrollController _scroll = ScrollController();
  bool _lockScroll = false;
  double _zoomAtGestureStart = 0;
  static const double _trackHeight = 56;
  static const double _rulerHeight = 26;
  static const double _leftPad = 12;

  EditController get c => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double get _pxPerMs => c.pxPerMs;
  double _xForMs(int ms) => _leftPad + ms * _pxPerMs;
  int _msForX(double x) => ((x - _leftPad) / _pxPerMs).round().clamp(0, 1 << 31);

  double get _contentWidth {
    final double base = _leftPad * 2 + c.durationMs * _pxPerMs;
    return base < 800 ? 800 : base;
  }

  void _lock(bool v) {
    if (_lockScroll == v) return;
    setState(() => _lockScroll = v);
  }

  @override
  Widget build(BuildContext context) {
    final Project p = c.project;
    final double height =
        _rulerHeight + p.tracks.length * (_trackHeight + 6) + 24;
    return GestureDetector(
      onScaleStart: (_) => _zoomAtGestureStart = _pxPerMs,
      onScaleUpdate: (d) {
        if (d.scale != 1.0) c.setZoom(_zoomAtGestureStart * d.scale);
      },
      child: Container(
        height: height,
        color: const Color(0xFF121212),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: _lockScroll
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          child: SizedBox(
            width: _contentWidth,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _ruler(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: _rulerHeight,
                  child: Column(
                    children: <Widget>[
                      for (final Track t in p.tracks) _trackRow(t),
                    ],
                  ),
                ),
                // Playhead.
                Positioned(
                  left: _xForMs(c.playheadMs) - 1,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(width: 2, color: const Color(0xFFFF3B6B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ruler() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => c.seek(_msForX(d.localPosition.dx)),
      onHorizontalDragStart: (_) => _lock(true),
      onHorizontalDragUpdate: (d) => c.seek(_msForX(d.localPosition.dx)),
      onHorizontalDragEnd: (_) => _lock(false),
      onHorizontalDragCancel: () => _lock(false),
      child: SizedBox(
        height: _rulerHeight,
        child: CustomPaint(
          size: Size(_contentWidth, _rulerHeight),
          painter: _RulerPainter(
            pxPerMs: _pxPerMs,
            leftPad: _leftPad,
            durationMs: c.durationMs,
          ),
        ),
      ),
    );
  }

  Widget _trackRow(Track t) {
    return Container(
      height: _trackHeight,
      margin: const EdgeInsets.only(bottom: 6),
      child: Stack(
        children: <Widget>[
          for (final Clip clip in t.clips) _clipWidget(t, clip),
        ],
      ),
    );
  }

  Widget _clipWidget(Track t, Clip clip) {
    final bool selected = clip.id == c.selectedClipId;
    final double left = _xForMs(clip.startMs);
    final double width = (clip.durationMs * _pxPerMs).clamp(18.0, double.infinity);
    return Positioned(
      left: left,
      width: width,
      top: 0,
      height: _trackHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => c.select(clip.id),
        onHorizontalDragStart: (_) {
          if (t.locked) return;
          c.select(clip.id);
          _lock(true);
          c.beginInteraction();
        },
        onHorizontalDragUpdate: (d) {
          if (t.locked) return;
          final int deltaMs = (d.primaryDelta! / _pxPerMs).round();
          c.moveClipLive(clip.id, clip.startMs + deltaMs);
        },
        onHorizontalDragEnd: (_) => _lock(false),
        onHorizontalDragCancel: () => _lock(false),
        child: Stack(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: _clipColor(clip.type),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? Colors.white : Colors.white24,
                  width: selected ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.centerLeft,
              child: _clipLabel(clip),
            ),
            if (selected && !t.locked) ..._trimHandles(clip, width),
          ],
        ),
      ),
    );
  }

  List<Widget> _trimHandles(Clip clip, double width) {
    Widget handle(bool left) => Container(
          width: 14,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(left ? 8 : 0),
              right: Radius.circular(left ? 0 : 8),
            ),
          ),
          child: const Icon(Icons.drag_indicator, size: 12, color: Colors.black54),
        );
    return <Widget>[
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _lock(true);
            c.beginInteraction();
          },
          onHorizontalDragUpdate: (d) {
            final int deltaMs = (d.primaryDelta! / _pxPerMs).round();
            c.trimStartLive(clip.id, clip.startMs + deltaMs);
          },
          onHorizontalDragEnd: (_) => _lock(false),
          onHorizontalDragCancel: () => _lock(false),
          child: handle(true),
        ),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _lock(true);
            c.beginInteraction();
          },
          onHorizontalDragUpdate: (d) {
            final int deltaMs = (d.primaryDelta! / _pxPerMs).round();
            c.trimEndLive(clip.id, clip.endMs + deltaMs);
          },
          onHorizontalDragEnd: (_) => _lock(false),
          onHorizontalDragCancel: () => _lock(false),
          child: handle(false),
        ),
      ),
    ];
  }

  Widget _clipLabel(Clip clip) {
    IconData icon;
    String text;
    switch (clip.type) {
      case ClipType.video:
        icon = Icons.videocam;
        text = clip.filterId != null
            ? EditorFilters.labelFor(clip.filterId)
            : "Video";
        break;
      case ClipType.image:
        icon = Icons.image;
        text = "Image";
        break;
      case ClipType.audio:
        icon = Icons.music_note;
        text = "Audio";
        break;
      case ClipType.text:
        icon = Icons.title;
        text = clip.text?.text ?? "Text";
        break;
      case ClipType.sticker:
        icon = Icons.emoji_emotions;
        text = clip.stickerCodePoint == null
            ? "Sticker"
            : String.fromCharCode(clip.stickerCodePoint!);
        break;
    }
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Color _clipColor(ClipType t) {
    switch (t) {
      case ClipType.video:
        return const Color(0xFF3B5BA5);
      case ClipType.image:
        return const Color(0xFF4B7A5A);
      case ClipType.audio:
        return const Color(0xFF7A5AA5);
      case ClipType.text:
        return const Color(0xFFA5763B);
      case ClipType.sticker:
        return const Color(0xFFA53B6B);
    }
  }
}

class _RulerPainter extends CustomPainter {
  final double pxPerMs;
  final double leftPad;
  final int durationMs;

  _RulerPainter({
    required this.pxPerMs,
    required this.leftPad,
    required this.durationMs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint tick = Paint()..color = Colors.white24;
    final int totalSec = (durationMs ~/ 1000) + 2;
    // Choose a label step that keeps ticks readable as you zoom.
    final double pxPerSec = pxPerMs * 1000;
    int step = 1;
    if (pxPerSec < 24) step = 5;
    if (pxPerSec < 10) step = 10;
    for (int s = 0; s <= totalSec; s++) {
      final double x = leftPad + s * pxPerSec;
      final bool major = s % step == 0;
      canvas.drawLine(
        Offset(x, major ? 4 : 10),
        Offset(x, size.height),
        tick,
      );
      if (major) {
        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: _label(s),
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      }
    }
  }

  String _label(int sec) {
    final int m = sec ~/ 60;
    final int s = sec % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.pxPerMs != pxPerMs || old.durationMs != durationMs;
}
