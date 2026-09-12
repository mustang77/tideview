import "dart:math";

import "package:flutter/material.dart";

/// Nebula backdrop: deep-space gradient, soft glowing gas clouds in the
/// app's green/gold palette, and a seeded starfield so the sky is the
/// same on every build.
class NebulaBackground extends StatelessWidget {
  const NebulaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _NebulaPainter(), size: Size.infinite);
  }
}

class _NebulaPainter extends CustomPainter {
  const _NebulaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Deep-space base, still recognisably the app's green.
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF071A15), Color(0xFF0D3B2F), Color(0xFF0B4437)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    // Nebula clouds: blurred glows layered over the base.
    void cloud(double dx, double dy, double r, Color color, double alpha) {
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55);
      canvas.drawCircle(Offset(w * dx, h * dy), r, paint);
    }

    cloud(0.22, 0.18, w * 0.34, const Color(0xFF2BAF87), 0.32);
    cloud(0.80, 0.10, w * 0.30, const Color(0xFF5B4B8A), 0.28);
    cloud(0.62, 0.45, w * 0.42, const Color(0xFF17957A), 0.22);
    cloud(0.10, 0.62, w * 0.26, const Color(0xFF3E6B5C), 0.25);
    cloud(0.88, 0.66, w * 0.22, const Color(0xFFE8C36A), 0.10);

    // Starfield — fixed seed keeps the constellation stable.
    final rng = Random(7);
    for (var i = 0; i < 110; i++) {
      final pos = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      final radius = 0.4 + rng.nextDouble() * 1.3;
      final alpha = 0.25 + rng.nextDouble() * 0.65;
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // A few brighter gold stars with a soft halo.
    for (var i = 0; i < 7; i++) {
      final pos = Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.8);
      canvas.drawCircle(
        pos,
        3.2,
        Paint()
          ..color = const Color(0xFFF2D488).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        pos,
        1.2,
        Paint()..color = const Color(0xFFF7E7B8).withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
