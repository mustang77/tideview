import "dart:math" as math;
import "package:flutter/material.dart";

import "effect.dart";
import "face.dart";

/// Paints AR masks and virtual makeup over a preview, anchored to the tracked
/// [faces]. All assets scale off the inter-ocular distance and rotate with head
/// roll, so they stay locked to the face as it moves — the core job of an AR
/// effect renderer.
class FaceOverlayPainter extends CustomPainter {
  final List<Face> faces;
  final ARMaskConfig? mask;
  final MakeupConfig? makeup;

  /// Mirror horizontally (front-facing camera preview convention).
  final bool mirror;

  /// Draw a subtle landmark debug overlay.
  final bool showLandmarks;

  const FaceOverlayPainter({
    required this.faces,
    this.mask,
    this.makeup,
    this.mirror = false,
    this.showLandmarks = false,
  });

  Offset _p(Offset n, Size size) {
    final double x = mirror ? (1 - n.dx) : n.dx;
    return Offset(x * size.width, n.dy * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final Face face in faces) {
      final Offset leftEye = _p(face.leftEye, size);
      final Offset rightEye = _p(face.rightEye, size);
      // Mirroring flips left/right; keep "left of screen" consistent.
      final Offset eyeA = leftEye.dx <= rightEye.dx ? leftEye : rightEye;
      final Offset eyeB = leftEye.dx <= rightEye.dx ? rightEye : leftEye;
      final double eyeDist = (eyeB - eyeA).distance;
      final double angle = math.atan2(eyeB.dy - eyeA.dy, eyeB.dx - eyeA.dx);
      final Offset eyeCenter = Offset(
        (eyeA.dx + eyeB.dx) / 2,
        (eyeA.dy + eyeB.dy) / 2,
      );

      if (makeup != null) {
        _paintMakeup(canvas, size, face, eyeDist);
      }
      if (mask != null) {
        _paintMask(canvas, mask!, eyeA, eyeB, eyeCenter, eyeDist, angle, size,
            face);
      }
      if (showLandmarks) {
        _paintLandmarks(canvas, size, face);
      }
    }
  }

  void _paintMask(
    Canvas canvas,
    ARMaskConfig cfg,
    Offset eyeA,
    Offset eyeB,
    Offset eyeCenter,
    double eyeDist,
    double angle,
    Size size,
    Face face,
  ) {
    canvas.save();
    canvas.translate(eyeCenter.dx, eyeCenter.dy);
    canvas.rotate(angle);
    // Now drawing in a face-local frame: +x toward the right eye, origin at the
    // eye midpoint. One "unit" ~= eyeDist.
    switch (cfg.shape) {
      case MaskShape.glasses:
        _drawGlasses(canvas, eyeDist, cfg.accent);
        break;
      case MaskShape.dogEars:
        _drawDogEars(canvas, eyeDist, cfg.accent);
        break;
      case MaskShape.crown:
        _drawCrown(canvas, eyeDist, cfg.accent);
        break;
      case MaskShape.mustache:
        _drawMustache(canvas, eyeDist, cfg.accent);
        break;
      case MaskShape.heartEyes:
        _drawHeartEyes(canvas, eyeDist, cfg.accent);
        break;
    }
    canvas.restore();
  }

  void _drawGlasses(Canvas canvas, double d, Color accent) {
    final double lens = d * 0.42;
    final Paint frame = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = d * 0.07
      ..strokeCap = StrokeCap.round;
    final Paint glass = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final Offset l = Offset(-d / 2, 0);
    final Offset r = Offset(d / 2, 0);
    canvas.drawCircle(l, lens, glass);
    canvas.drawCircle(r, lens, glass);
    canvas.drawCircle(l, lens, frame);
    canvas.drawCircle(r, lens, frame);
    // Bridge.
    canvas.drawLine(
        Offset(-d / 2 + lens, -lens * 0.2), Offset(d / 2 - lens, -lens * 0.2), frame);
    // Temples.
    canvas.drawLine(Offset(-d / 2 - lens, -lens * 0.1),
        Offset(-d * 0.95, -lens * 0.5), frame);
    canvas.drawLine(
        Offset(d / 2 + lens, -lens * 0.1), Offset(d * 0.95, -lens * 0.5), frame);
  }

  void _drawDogEars(Canvas canvas, double d, Color accent) {
    final Paint fill = Paint()..color = accent;
    final Paint inner = Paint()..color = const Color(0xFFF2C9A0);
    // Ears above the eyes.
    for (final double sx in <double>[-1, 1]) {
      final double bx = sx * d * 0.95;
      final double by = -d * 1.4;
      final Path ear = Path()
        ..moveTo(bx - d * 0.28, by)
        ..quadraticBezierTo(bx - d * 0.45, by + d * 0.9, bx, by + d * 1.1)
        ..quadraticBezierTo(bx + d * 0.45, by + d * 0.9, bx + d * 0.28, by)
        ..close();
      canvas.drawPath(ear, fill);
      final Path innerEar = Path()
        ..moveTo(bx - d * 0.12, by + d * 0.15)
        ..quadraticBezierTo(bx - d * 0.2, by + d * 0.75, bx, by + d * 0.85)
        ..quadraticBezierTo(bx + d * 0.2, by + d * 0.75, bx + d * 0.12, by + d * 0.15)
        ..close();
      canvas.drawPath(innerEar, inner);
    }
    // Nose.
    canvas.drawCircle(Offset(0, d * 0.95), d * 0.16, Paint()..color = accent);
  }

  void _drawCrown(Canvas canvas, double d, Color accent) {
    final Paint gold = Paint()..color = accent;
    final Paint jewel = Paint()..color = const Color(0xFFE0466A);
    final double baseY = -d * 1.35;
    final double w = d * 1.6;
    final Path crown = Path()
      ..moveTo(-w / 2, baseY)
      ..lineTo(-w / 2, baseY - d * 0.15)
      ..lineTo(-w / 4, baseY - d * 0.55)
      ..lineTo(0, baseY - d * 0.15)
      ..lineTo(w / 4, baseY - d * 0.55)
      ..lineTo(w / 2, baseY - d * 0.15)
      ..lineTo(w / 2, baseY)
      ..close();
    canvas.drawPath(crown, gold);
    canvas.drawCircle(Offset(0, baseY - d * 0.1), d * 0.09, jewel);
  }

  void _drawMustache(Canvas canvas, double d, Color accent) {
    final Paint hair = Paint()..color = accent;
    final double y = d * 1.35; // below the nose, above the mouth
    final Path stache = Path()
      ..moveTo(0, y)
      ..quadraticBezierTo(-d * 0.35, y - d * 0.28, -d * 0.75, y - d * 0.05)
      ..quadraticBezierTo(-d * 0.55, y + d * 0.3, -d * 0.2, y + d * 0.1)
      ..quadraticBezierTo(0, y + d * 0.02, 0, y)
      ..moveTo(0, y)
      ..quadraticBezierTo(d * 0.35, y - d * 0.28, d * 0.75, y - d * 0.05)
      ..quadraticBezierTo(d * 0.55, y + d * 0.3, d * 0.2, y + d * 0.1)
      ..quadraticBezierTo(0, y + d * 0.02, 0, y);
    canvas.drawPath(stache, hair);
  }

  void _drawHeartEyes(Canvas canvas, double d, Color accent) {
    final Paint p = Paint()..color = accent;
    for (final double sx in <double>[-1, 1]) {
      final double cx = sx * d / 2;
      _heart(canvas, Offset(cx, 0), d * 0.5, p);
    }
  }

  void _heart(Canvas canvas, Offset c, double s, Paint p) {
    final Path h = Path();
    h.moveTo(c.dx, c.dy + s * 0.35);
    h.cubicTo(c.dx + s * 0.6, c.dy - s * 0.3, c.dx + s * 0.25, c.dy - s * 0.55,
        c.dx, c.dy - s * 0.2);
    h.cubicTo(c.dx - s * 0.25, c.dy - s * 0.55, c.dx - s * 0.6, c.dy - s * 0.3,
        c.dx, c.dy + s * 0.35);
    h.close();
    canvas.drawPath(h, p);
  }

  void _paintMakeup(Canvas canvas, Size size, Face face, double eyeDist) {
    final MakeupConfig m = makeup!;
    if (m.hasLips) {
      final Offset ml = _p(face.mouthLeft, size);
      final Offset mr = _p(face.mouthRight, size);
      final Offset mc = _p(face.mouthCenter, size);
      final double w = (mr - ml).distance;
      final Paint lip = Paint()
        ..color = m.lipColor!.withValues(alpha: m.lipStrength.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05);
      final Path lips = Path()
        ..moveTo(ml.dx, ml.dy)
        ..quadraticBezierTo(mc.dx, mc.dy - w * 0.18, mr.dx, mr.dy)
        ..quadraticBezierTo(mc.dx, mc.dy + w * 0.28, ml.dx, ml.dy)
        ..close();
      canvas.drawPath(lips, lip);
    }
    if (m.hasBlush) {
      final Offset nose = _p(face.noseTip, size);
      final double r = eyeDist * 0.45;
      final Paint blush = Paint()
        ..color = m.blushColor!.withValues(alpha: m.blushStrength.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6);
      canvas.drawCircle(Offset(nose.dx - eyeDist * 0.75, nose.dy), r, blush);
      canvas.drawCircle(Offset(nose.dx + eyeDist * 0.75, nose.dy), r, blush);
    }
  }

  void _paintLandmarks(Canvas canvas, Size size, Face face) {
    final Paint dot = Paint()..color = const Color(0x8833E0C0);
    for (final Offset n in <Offset>[
      face.leftEye,
      face.rightEye,
      face.noseTip,
      face.mouthLeft,
      face.mouthRight,
      face.mouthCenter,
      face.foreheadTop,
      face.chinBottom,
    ]) {
      canvas.drawCircle(_p(n, size), 3, dot);
    }
    final Rect box = Rect.fromLTRB(
      (mirror ? 1 - face.boundingBox.right : face.boundingBox.left) * size.width,
      face.boundingBox.top * size.height,
      (mirror ? 1 - face.boundingBox.left : face.boundingBox.right) * size.width,
      face.boundingBox.bottom * size.height,
    );
    canvas.drawRect(
      box,
      Paint()
        ..color = const Color(0x5533E0C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter old) =>
      old.faces != faces ||
      old.mask != mask ||
      old.makeup != makeup ||
      old.mirror != mirror ||
      old.showLandmarks != showLandmarks;
}
