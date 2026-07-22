import "dart:math";

import "package:flutter/material.dart";

import "controller.dart";
import "models.dart";

// ---------------------------------------------------------------- burgers

/// Draws a burger stack (possibly partial) centred in the box.
class BurgerPainter extends CustomPainter {
  final List<Ingredient> stack;
  const BurgerPainter(this.stack);

  @override
  void paint(Canvas canvas, Size size) {
    if (stack.isEmpty) return;
    final w = size.width;
    final layerH = min(size.height / (stack.length + 1.2), w * 0.22);
    var y = size.height / 2 + (stack.length * layerH) / 2;
    for (final ing in stack) {
      _drawLayer(canvas, ing, Offset(w / 2, y), w * 0.82, layerH);
      y -= layerH;
    }
  }

  void _drawLayer(
      Canvas canvas, Ingredient ing, Offset center, double w, double h) {
    final paint = Paint()..color = ing.color;
    final rect = Rect.fromCenter(center: center, width: w, height: h * 1.15);
    switch (ing) {
      case Ingredient.bunBottom:
        canvas.drawRRect(
            RRect.fromRectAndCorners(rect,
                bottomLeft: Radius.circular(h * 0.8),
                bottomRight: Radius.circular(h * 0.8),
                topLeft: Radius.circular(h * 0.25),
                topRight: Radius.circular(h * 0.25)),
            paint);
      case Ingredient.bunTop:
        final dome = Rect.fromCenter(
            center: center.translate(0, h * 0.18), width: w, height: h * 2.1);
        canvas.drawArc(dome, pi, pi, true, paint);
        // Sesame seeds.
        final seed = Paint()..color = const Color(0xFFFFF3D6);
        for (final dx in [-0.25, 0.0, 0.25]) {
          canvas.drawOval(
              Rect.fromCenter(
                  center: center.translate(w * dx, -h * 0.45),
                  width: w * 0.06,
                  height: w * 0.035),
              seed);
        }
      case Ingredient.patty:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: center, width: w * 0.96, height: h),
                Radius.circular(h * 0.5)),
            paint);
        final dark = Paint()..color = const Color(0xFF4E2B18);
        for (final dx in [-0.3, -0.05, 0.22]) {
          canvas.drawCircle(center.translate(w * dx, 0), h * 0.09, dark);
        }
      case Ingredient.cheese:
        final path = Path()
          ..moveTo(center.dx - w / 2, center.dy - h * 0.25)
          ..lineTo(center.dx + w / 2, center.dy - h * 0.25)
          ..lineTo(center.dx + w * 0.32, center.dy + h * 0.55)
          ..lineTo(center.dx + w * 0.1, center.dy - h * 0.05)
          ..lineTo(center.dx - w * 0.15, center.dy + h * 0.55)
          ..lineTo(center.dx - w * 0.35, center.dy - h * 0.05)
          ..close();
        canvas.drawPath(path, paint);
      case Ingredient.tomato:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: center, width: w * 0.9, height: h * 0.75),
                Radius.circular(h * 0.4)),
            paint);
      case Ingredient.lettuce:
        final path = Path();
        const waves = 6;
        path.moveTo(center.dx - w / 2, center.dy);
        for (var i = 0; i < waves; i++) {
          final x0 = center.dx - w / 2 + w * i / waves;
          path.quadraticBezierTo(x0 + w / (waves * 2),
              center.dy + (i.isEven ? h * 0.6 : -h * 0.35), x0 + w / waves,
              center.dy);
        }
        path.lineTo(center.dx + w / 2, center.dy - h * 0.35);
        path.lineTo(center.dx - w / 2, center.dy - h * 0.35);
        path.close();
        canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(BurgerPainter old) =>
      old.stack.length != stack.length || !identical(old.stack, stack);
}

// ------------------------------------------------------------------ patty

class PattyPainter extends CustomPainter {
  final CookState state;
  final double progress; // 0..1 within current state
  const PattyPainter(this.state, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (state == CookState.empty) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.38;
    final color = switch (state) {
      CookState.cooking => Color.lerp(
          const Color(0xFFCE7B5B), const Color(0xFF6B3E26), progress)!,
      CookState.done => const Color(0xFF6B3E26),
      CookState.burnt => const Color(0xFF2B1B12),
      CookState.empty => Colors.transparent,
    };
    canvas.drawCircle(c.translate(0, 2), r, Paint()..color = Colors.black26);
    canvas.drawCircle(c, r, Paint()..color = color);
    final grillMark = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final dy in [-0.4, 0.0, 0.4]) {
      canvas.drawLine(c.translate(-r * 0.6, r * dy),
          c.translate(r * 0.6, r * dy), grillMark);
    }
    if (state == CookState.burnt) {
      _smoke(canvas, c.translate(0, -r), r * 0.5);
    }
  }

  void _smoke(Canvas canvas, Offset base, double s) {
    final p = Paint()..color = Colors.grey.withValues(alpha: 0.55);
    canvas.drawCircle(base.translate(-s * 0.4, -s * 0.4), s * 0.35, p);
    canvas.drawCircle(base.translate(s * 0.15, -s * 0.9), s * 0.45, p);
    canvas.drawCircle(base.translate(s * 0.6, -s * 1.5), s * 0.3, p);
  }

  @override
  bool shouldRepaint(PattyPainter old) =>
      old.state != state || old.progress != progress;
}

// ------------------------------------------------------------------ fries

class FriesPainter extends CustomPainter {
  final CookState state;
  final double progress;
  const FriesPainter(this.state, {this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final friesColor = switch (state) {
      CookState.cooking => Color.lerp(
          const Color(0xFFF7E8B0), const Color(0xFFF2C94C), progress)!,
      CookState.burnt => const Color(0xFF4A3218),
      _ => const Color(0xFFF2C94C),
    };
    final fry = Paint()..color = friesColor;
    // Fries sticking out of the box.
    for (final f in [
      [-0.22, 0.22, -0.12],
      [-0.08, 0.12, 0.05],
      [0.08, 0.2, -0.08],
      [0.2, 0.16, 0.1],
      [-0.02, 0.3, 0.0],
    ]) {
      canvas.save();
      canvas.translate(w / 2 + w * f[0], h * 0.52);
      canvas.rotate(f[2]);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(0, -h * f[1]),
                  width: w * 0.09,
                  height: h * (0.3 + f[1])),
              const Radius.circular(3)),
          fry);
      canvas.restore();
    }
    // Red carton.
    final box = Path()
      ..moveTo(w * 0.2, h * 0.45)
      ..lineTo(w * 0.8, h * 0.45)
      ..lineTo(w * 0.72, h * 0.92)
      ..lineTo(w * 0.28, h * 0.92)
      ..close();
    canvas.drawPath(box, Paint()..color = const Color(0xFFD64545));
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.2, h * 0.45)
          ..lineTo(w * 0.8, h * 0.45)
          ..lineTo(w * 0.78, h * 0.56)
          ..lineTo(w * 0.22, h * 0.56)
          ..close(),
        Paint()..color = const Color(0xFFB53535));
    if (state == CookState.burnt) {
      final p = Paint()..color = Colors.grey.withValues(alpha: 0.55);
      canvas.drawCircle(Offset(w * 0.4, h * 0.15), w * 0.09, p);
      canvas.drawCircle(Offset(w * 0.58, h * 0.05), w * 0.11, p);
    }
  }

  @override
  bool shouldRepaint(FriesPainter old) =>
      old.state != state || old.progress != progress;
}

// ------------------------------------------------------------------ drink

class DrinkPainter extends CustomPainter {
  final double fill; // 0..1
  const DrinkPainter({this.fill = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cup = Path()
      ..moveTo(w * 0.28, h * 0.22)
      ..lineTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.64, h * 0.92)
      ..lineTo(w * 0.36, h * 0.92)
      ..close();
    canvas.drawPath(cup, Paint()..color = const Color(0xFFEFF4F8));
    // Soda fill (clip to cup).
    canvas.save();
    canvas.clipPath(cup);
    final top = h * (0.92 - 0.62 * fill);
    canvas.drawRect(Rect.fromLTRB(0, top, w, h),
        Paint()..color = const Color(0xFF8A4B2D));
    canvas.restore();
    // Band + lid + straw.
    canvas.drawRect(Rect.fromLTRB(w * 0.3, h * 0.42, w * 0.7, h * 0.55),
        Paint()..color = const Color(0xFF4A90D9));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(w * 0.24, h * 0.16, w * 0.76, h * 0.24),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFF4A90D9));
    canvas.drawLine(
        Offset(w * 0.55, h * 0.18),
        Offset(w * 0.62, h * 0.02),
        Paint()
          ..color = const Color(0xFFD64545)
          ..strokeWidth = w * 0.06
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(DrinkPainter old) => old.fill != fill;
}

// -------------------------------------------------------------- customers

/// Procedural cartoon customer. The seed picks skin/hair/shirt/hat; the
/// mood drives the face.
class CustomerPainter extends CustomPainter {
  final int seed;
  final CustomerMood mood;
  const CustomerPainter(this.seed, this.mood);

  static const _skins = [
    Color(0xFFFFD9B3),
    Color(0xFFF2B98A),
    Color(0xFFC98850),
    Color(0xFF8D5A2B),
    Color(0xFF6B4423),
  ];
  static const _hairs = [
    Color(0xFF2B2B2B),
    Color(0xFF5B3A1E),
    Color(0xFFB0722E),
    Color(0xFFD8D8D8),
    Color(0xFFA53434),
    Color(0xFF3E3E6B),
  ];
  static const _shirts = [
    Color(0xFF4A90D9),
    Color(0xFFE07B39),
    Color(0xFF5FA05A),
    Color(0xFF9C5BB0),
    Color(0xFFD64560),
    Color(0xFF3E7C8A),
    Color(0xFF888844),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final skin = _skins[rng.nextInt(_skins.length)];
    final hair = _hairs[rng.nextInt(_hairs.length)];
    final shirt = _shirts[rng.nextInt(_shirts.length)];
    final hairStyle = rng.nextInt(4); // 0 short 1 long 2 cap 3 bald
    final hasGlasses = rng.nextInt(4) == 0;

    final w = size.width;
    final h = size.height;
    final headR = w * 0.30;
    final headC = Offset(w / 2, h * 0.34);

    // Body.
    final body = Path()
      ..moveTo(w * 0.18, h)
      ..quadraticBezierTo(w * 0.16, h * 0.62, w * 0.5, h * 0.6)
      ..quadraticBezierTo(w * 0.84, h * 0.62, w * 0.82, h)
      ..close();
    canvas.drawPath(body, Paint()..color = shirt);

    // Head.
    canvas.drawCircle(headC, headR, Paint()..color = skin);

    // Hair / hat.
    final hairPaint = Paint()..color = hair;
    switch (hairStyle) {
      case 0: // short crop
        canvas.drawArc(
            Rect.fromCircle(center: headC, radius: headR * 1.02),
            pi * 1.05,
            pi * 0.9,
            true,
            hairPaint);
      case 1: // long hair down the sides
        canvas.drawArc(
            Rect.fromCircle(center: headC, radius: headR * 1.06),
            pi,
            pi,
            true,
            hairPaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: headC.translate(-headR * 0.9, headR * 0.35),
                    width: headR * 0.42,
                    height: headR * 1.3),
                Radius.circular(headR * 0.2)),
            hairPaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: headC.translate(headR * 0.9, headR * 0.35),
                    width: headR * 0.42,
                    height: headR * 1.3),
                Radius.circular(headR * 0.2)),
            hairPaint);
      case 2: // baseball cap
        final capPaint = Paint()
          ..color = _shirts[(seed >> 3) % _shirts.length];
        canvas.drawArc(
            Rect.fromCircle(center: headC, radius: headR * 1.05),
            pi,
            pi,
            true,
            capPaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: headC.translate(headR * 0.55, -headR * 0.28),
                    width: headR * 1.1,
                    height: headR * 0.24),
                Radius.circular(headR * 0.12)),
            capPaint);
      case 3: // bald, tiny ears of hair
        canvas.drawCircle(headC.translate(-headR * 0.85, 0), headR * 0.18,
            hairPaint);
        canvas.drawCircle(
            headC.translate(headR * 0.85, 0), headR * 0.18, hairPaint);
    }

    // Face.
    final eyeY = headC.dy + headR * 0.02;
    final eyeDx = headR * 0.38;
    final eye = Paint()..color = const Color(0xFF222222);
    if (mood == CustomerMood.angry) {
      final brow = Paint()
        ..color = const Color(0xFF222222)
        ..strokeWidth = headR * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(headC.dx - eyeDx - headR * 0.18, eyeY - headR * 0.32),
          Offset(headC.dx - eyeDx + headR * 0.14, eyeY - headR * 0.14),
          brow);
      canvas.drawLine(
          Offset(headC.dx + eyeDx + headR * 0.18, eyeY - headR * 0.32),
          Offset(headC.dx + eyeDx - headR * 0.14, eyeY - headR * 0.14),
          brow);
    }
    canvas.drawCircle(Offset(headC.dx - eyeDx, eyeY), headR * 0.09, eye);
    canvas.drawCircle(Offset(headC.dx + eyeDx, eyeY), headR * 0.09, eye);
    if (hasGlasses) {
      final gp = Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.06;
      canvas.drawCircle(Offset(headC.dx - eyeDx, eyeY), headR * 0.2, gp);
      canvas.drawCircle(Offset(headC.dx + eyeDx, eyeY), headR * 0.2, gp);
      canvas.drawLine(Offset(headC.dx - eyeDx + headR * 0.2, eyeY),
          Offset(headC.dx + eyeDx - headR * 0.2, eyeY), gp);
    }

    // Mouth by mood.
    final mouth = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.09
      ..strokeCap = StrokeCap.round;
    final mouthC = headC.translate(0, headR * 0.45);
    switch (mood) {
      case CustomerMood.happy:
        canvas.drawArc(
            Rect.fromCircle(center: mouthC.translate(0, -headR * 0.1), radius: headR * 0.28),
            pi * 0.15,
            pi * 0.7,
            false,
            mouth);
      case CustomerMood.neutral:
        canvas.drawLine(mouthC.translate(-headR * 0.2, 0),
            mouthC.translate(headR * 0.2, 0), mouth);
      case CustomerMood.impatient:
        canvas.drawArc(
            Rect.fromCircle(center: mouthC.translate(0, headR * 0.14), radius: headR * 0.24),
            pi * 1.15,
            pi * 0.7,
            false,
            mouth);
      case CustomerMood.angry:
        canvas.drawArc(
            Rect.fromCircle(center: mouthC.translate(0, headR * 0.18), radius: headR * 0.26),
            pi * 1.1,
            pi * 0.8,
            false,
            mouth);
        // Angry steam mark.
        final steam = Paint()
          ..color = const Color(0xFFD64545)
          ..strokeWidth = headR * 0.08
          ..strokeCap = StrokeCap.round;
        final sBase = headC.translate(headR * 0.95, -headR * 0.9);
        canvas.drawLine(sBase, sBase.translate(headR * 0.22, -headR * 0.22), steam);
        canvas.drawLine(sBase.translate(headR * 0.3, 0.0),
            sBase.translate(headR * 0.52, -headR * 0.22), steam);
    }
  }

  @override
  bool shouldRepaint(CustomerPainter old) =>
      old.seed != seed || old.mood != mood;
}

// ------------------------------------------------------------- chef logo

/// Chef hat + burger emblem for the menu screen.
class ChefLogoPainter extends CustomPainter {
  final Color accent;
  const ChefLogoPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hat = Paint()..color = Colors.white;
    final c = Offset(w / 2, h * 0.42);
    canvas.drawCircle(c.translate(0, 4), w * 0.34, Paint()..color = Colors.black12);
    canvas.drawCircle(c.translate(-w * 0.2, -h * 0.05), w * 0.16, hat);
    canvas.drawCircle(c.translate(0, -h * 0.12), w * 0.19, hat);
    canvas.drawCircle(c.translate(w * 0.2, -h * 0.05), w * 0.16, hat);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, h * 0.1), width: w * 0.52, height: h * 0.3),
            const Radius.circular(6)),
        hat);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, h * 0.28), width: w * 0.52, height: h * 0.08),
            const Radius.circular(4)),
        Paint()..color = accent);
  }

  @override
  bool shouldRepaint(ChefLogoPainter old) => old.accent != accent;
}
