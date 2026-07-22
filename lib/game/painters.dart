import "dart:math";

import "package:flutter/material.dart";

import "controller.dart";
import "models.dart";

// ---------------------------------------------------------------- helpers

Shader _vGrad(Rect r, List<Color> colors, [List<double>? stops]) =>
    LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(r);

Shader _rGrad(Rect r, List<Color> colors,
        {Alignment center = const Alignment(-0.3, -0.4),
        List<double>? stops}) =>
    RadialGradient(center: center, radius: 1.0, colors: colors, stops: stops)
        .createShader(r);

void _softShadow(Canvas canvas, Offset center, double w, double h,
    [double alpha = 0.22]) {
  canvas.drawOval(
    Rect.fromCenter(center: center, width: w, height: h),
    Paint()
      ..color = Colors.black.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
}

void _steam(Canvas canvas, Offset base, double s, double alpha) {
  final p = Paint()
    ..color = Colors.white.withValues(alpha: alpha)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  final path = Path()
    ..moveTo(base.dx, base.dy)
    ..cubicTo(base.dx - s * 0.5, base.dy - s * 0.7, base.dx + s * 0.5,
        base.dy - s * 1.3, base.dx, base.dy - s * 2.0);
  canvas.drawPath(
      path,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.22
        ..strokeCap = StrokeCap.round);
}

void _smoke(Canvas canvas, Offset base, double s) {
  final p = Paint()
    ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.6)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  canvas.drawCircle(base.translate(-s * 0.4, -s * 0.4), s * 0.35, p);
  canvas.drawCircle(base.translate(s * 0.15, -s * 0.95), s * 0.45, p);
  canvas.drawCircle(base.translate(s * 0.55, -s * 1.55), s * 0.3, p);
}

// ---------------------------------------------------------------- burgers

/// Side-view burger stack (possibly partial) with soft shading.
class BurgerPainter extends CustomPainter {
  final List<Ingredient> stack;
  const BurgerPainter(this.stack);

  @override
  void paint(Canvas canvas, Size size) {
    if (stack.isEmpty) return;
    final w = size.width;
    final layerH = min(size.height / (stack.length + 1.6), w * 0.20);
    final totalH = stack.length * layerH;
    _softShadow(canvas, Offset(w / 2, size.height / 2 + totalH / 2 + 3),
        w * 0.7, layerH * 0.7);
    var y = size.height / 2 + totalH / 2 - layerH / 2;
    for (final ing in stack) {
      _drawLayer(canvas, ing, Offset(w / 2, y), w * 0.82, layerH);
      y -= layerH;
    }
  }

  void _drawLayer(
      Canvas canvas, Ingredient ing, Offset c, double w, double h) {
    switch (ing) {
      case Ingredient.bunBottom:
        final rect =
            Rect.fromCenter(center: c, width: w, height: h * 1.25);
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect,
              bottomLeft: Radius.circular(h * 0.85),
              bottomRight: Radius.circular(h * 0.85),
              topLeft: Radius.circular(h * 0.3),
              topRight: Radius.circular(h * 0.3)),
          Paint()
            ..shader = _vGrad(rect,
                [const Color(0xFFF0B664), const Color(0xFFC88A3C)]),
        );
      case Ingredient.bunTop:
        final dome = Rect.fromCenter(
            center: c.translate(0, h * 0.35), width: w, height: h * 2.6);
        canvas.drawArc(
            dome,
            pi,
            pi,
            true,
            Paint()
              ..shader = _rGrad(dome, [
                const Color(0xFFF6C878),
                const Color(0xFFE8A952),
                const Color(0xFFC8853A)
              ], stops: const [
                0.0,
                0.65,
                1.0
              ]));
        // Glossy highlight.
        canvas.drawArc(
            Rect.fromCenter(
                center: c.translate(-w * 0.08, h * 0.42),
                width: w * 0.72,
                height: h * 2.1),
            pi * 1.15,
            pi * 0.4,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = h * 0.22
              ..strokeCap = StrokeCap.round);
        // Sesame seeds.
        final seed = Paint()..color = const Color(0xFFFFF3D6);
        for (final s in [
          [-0.28, -0.35, 0.5],
          [-0.10, -0.62, -0.3],
          [0.10, -0.55, 0.4],
          [0.28, -0.30, -0.4],
          [0.0, -0.28, 0.1],
        ]) {
          canvas.save();
          canvas.translate(c.dx + w * s[0], c.dy + h * s[1]);
          canvas.rotate(s[2]);
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset.zero, width: w * 0.07, height: w * 0.04),
              seed);
          canvas.restore();
        }
      case Ingredient.patty:
        final rect =
            Rect.fromCenter(center: c, width: w * 0.96, height: h * 1.05);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(h * 0.55)),
          Paint()
            ..shader = _vGrad(rect, [
              const Color(0xFF8A5432),
              const Color(0xFF5E3520),
              const Color(0xFF4A2A18)
            ]),
        );
        // Sear dimples + juicy highlight.
        final dark = Paint()..color = const Color(0xFF3A2012);
        for (final dx in [-0.32, -0.08, 0.18, 0.36]) {
          canvas.drawCircle(c.translate(w * dx, h * 0.08), h * 0.10, dark);
        }
        canvas.drawLine(
            c.translate(-w * 0.35, -h * 0.3),
            c.translate(w * 0.25, -h * 0.3),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.18)
              ..strokeWidth = h * 0.16
              ..strokeCap = StrokeCap.round);
      case Ingredient.cheese:
        // Melted slice with drips.
        final base = c.translate(0, -h * 0.1);
        final path = Path()
          ..moveTo(base.dx - w * 0.5, base.dy - h * 0.18)
          ..lineTo(base.dx + w * 0.5, base.dy - h * 0.18)
          ..lineTo(base.dx + w * 0.44, base.dy + h * 0.28)
          ..quadraticBezierTo(base.dx + w * 0.36, base.dy + h * 0.75,
              base.dx + w * 0.28, base.dy + h * 0.28)
          ..lineTo(base.dx + w * 0.10, base.dy + h * 0.30)
          ..quadraticBezierTo(base.dx + w * 0.02, base.dy + h * 0.9,
              base.dx - w * 0.06, base.dy + h * 0.30)
          ..lineTo(base.dx - w * 0.26, base.dy + h * 0.28)
          ..quadraticBezierTo(base.dx - w * 0.34, base.dy + h * 0.7,
              base.dx - w * 0.42, base.dy + h * 0.26)
          ..close();
        final r = Rect.fromCenter(center: base, width: w, height: h * 1.6);
        canvas.drawPath(
            path,
            Paint()
              ..shader = _vGrad(r,
                  [const Color(0xFFFFD95E), const Color(0xFFF2B02C)]));
      case Ingredient.tomato:
        final rect =
            Rect.fromCenter(center: c, width: w * 0.9, height: h * 0.8);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(h * 0.4)),
            Paint()
              ..shader = _vGrad(rect,
                  [const Color(0xFFEF5350), const Color(0xFFC62828)]));
        // Inner flesh hint.
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: c, width: w * 0.78, height: h * 0.45),
                Radius.circular(h * 0.25)),
            Paint()..color = const Color(0xFFE57373).withValues(alpha: 0.7));
      case Ingredient.lettuce:
        final light = Paint()..color = const Color(0xFF81C784);
        final darkG = Paint()..color = const Color(0xFF56A05B);
        for (final layer in [
          [darkG, 0.10],
          [light, 0.0],
        ]) {
          final paint = layer[0] as Paint;
          final dy = h * (layer[1] as double);
          final path = Path()..moveTo(c.dx - w * 0.5, c.dy + dy);
          const waves = 7;
          for (var i = 0; i < waves; i++) {
            final x0 = c.dx - w * 0.5 + w * i / waves;
            path.quadraticBezierTo(
                x0 + w / (waves * 2),
                c.dy + dy + (i.isEven ? h * 0.62 : -h * 0.28),
                x0 + w / waves,
                c.dy + dy);
          }
          path
            ..lineTo(c.dx + w * 0.5, c.dy + dy - h * 0.38)
            ..lineTo(c.dx - w * 0.5, c.dy + dy - h * 0.38)
            ..close();
          canvas.drawPath(path, paint);
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(BurgerPainter old) =>
      old.stack.length != stack.length || !identical(old.stack, stack);
}

// ------------------------------------------------------------------ pizza

/// Top-view pizza. [state] empty/raw uses pale dough; cooking blends to a
/// golden crust; burnt chars it.
class PizzaPainter extends CustomPainter {
  final List<Ingredient> stack;
  final CookState state;
  final double progress; // cooking progress 0..1
  const PizzaPainter(this.stack,
      {this.state = CookState.empty, this.progress = 0});

  @override
  void paint(Canvas canvas, Size size) {
    if (stack.isEmpty) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = min(size.width, size.height) * 0.44;
    final cookT = switch (state) {
      CookState.empty => 0.0,
      CookState.cooking => progress,
      CookState.done => 1.0,
      CookState.burnt => 1.0,
    };
    final burnt = state == CookState.burnt;

    _softShadow(canvas, c.translate(0, r * 0.85), r * 1.9, r * 0.5);

    // Crust.
    final crustCold = const Color(0xFFEFD9A7);
    final crustHot = const Color(0xFFD9A254);
    final crust = burnt
        ? const Color(0xFF4A3218)
        : Color.lerp(crustCold, crustHot, cookT)!;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = _rGrad(Rect.fromCircle(center: c, radius: r), [
            crust,
            Color.lerp(crust, Colors.black, 0.18)!,
          ]));

    // Sauce.
    if (stack.contains(Ingredient.pizzaSauce)) {
      final sauce = burnt
          ? const Color(0xFF38251A)
          : Color.lerp(const Color(0xFFD84B36), const Color(0xFFB03A28), cookT)!;
      canvas.drawCircle(c, r * 0.82, Paint()..color = sauce);
    }

    // Cheese: irregular blobby circle.
    if (stack.contains(Ingredient.mozzarella)) {
      final cheeseCold = const Color(0xFFF7EFC9);
      final cheeseHot = const Color(0xFFF2CE6B);
      final cheese = burnt
          ? const Color(0xFF54401E)
          : Color.lerp(cheeseCold, cheeseHot, cookT)!;
      final path = Path();
      const lobes = 9;
      for (var i = 0; i <= lobes; i++) {
        final ang = 2 * pi * i / lobes;
        final rr = r * (0.72 + 0.055 * ((i * 37) % 3 - 1));
        final p = c + Offset(cos(ang), sin(ang)) * rr;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          final mid = c +
              Offset(cos(ang - pi / lobes), sin(ang - pi / lobes)) *
                  (rr * 1.06);
          path.quadraticBezierTo(mid.dx, mid.dy, p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = cheese);
      // Browned bubble spots once cooked.
      if (cookT > 0.6 && !burnt) {
        final spot = Paint()
          ..color = const Color(0xFFCB8A3E).withValues(alpha: 0.8);
        for (final s in [
          [-0.30, -0.15],
          [0.22, -0.32],
          [0.05, 0.3],
          [-0.15, 0.38],
          [0.4, 0.1],
        ]) {
          canvas.drawCircle(
              c.translate(r * s[0], r * s[1]), r * 0.055, spot);
        }
      }
    }

    // Toppings.
    final rng = Random(7);
    for (final ing in stack) {
      switch (ing) {
        case Ingredient.pepperoni:
          final pep = burnt
              ? const Color(0xFF3A2014)
              : Color.lerp(const Color(0xFFD05038), const Color(0xFFA83424),
                  cookT)!;
          final edge = Paint()
            ..color = Color.lerp(pep, Colors.black, 0.25)!;
          for (var i = 0; i < 5; i++) {
            final ang = 2 * pi * i / 5 + 0.5;
            final p = c + Offset(cos(ang), sin(ang)) * r * 0.42;
            canvas.drawCircle(p, r * 0.14, edge);
            canvas.drawCircle(p, r * 0.115, Paint()..color = pep);
            canvas.drawCircle(p.translate(-r * 0.03, -r * 0.03), r * 0.03,
                Paint()..color = Colors.white.withValues(alpha: 0.25));
          }
        case Ingredient.mushroom:
          final cap = burnt
              ? const Color(0xFF33261A)
              : const Color(0xFFD9C4A3);
          final shade = Color.lerp(cap, Colors.black, 0.25)!;
          for (var i = 0; i < 4; i++) {
            final ang = 2 * pi * i / 4 + 1.4;
            final p = c + Offset(cos(ang), sin(ang)) * r * 0.30;
            canvas.save();
            canvas.translate(p.dx, p.dy);
            canvas.rotate(rng.nextDouble() * pi);
            // Sliced mushroom: cap arc + stem.
            canvas.drawArc(
                Rect.fromCenter(
                    center: Offset(0, -r * 0.02),
                    width: r * 0.22,
                    height: r * 0.20),
                pi,
                pi,
                true,
                Paint()..color = shade);
            canvas.drawRect(
                Rect.fromCenter(
                    center: Offset(0, r * 0.045),
                    width: r * 0.07,
                    height: r * 0.11),
                Paint()..color = cap);
            canvas.restore();
          }
        case Ingredient.olive:
          final oliveP = Paint()..color = const Color(0xFF2F3325);
          final hole = Paint()..color = const Color(0xFF5A6147);
          for (var i = 0; i < 6; i++) {
            final ang = 2 * pi * i / 6 + 0.2;
            final p = c + Offset(cos(ang), sin(ang)) * r * 0.55;
            canvas.drawCircle(p, r * 0.065, oliveP);
            canvas.drawCircle(p, r * 0.028, hole);
          }
        default:
          break;
      }
    }

    if (burnt) _smoke(canvas, c.translate(0, -r * 0.6), r * 0.5);
  }

  @override
  bool shouldRepaint(PizzaPainter old) =>
      old.state != state ||
      old.progress != progress ||
      old.stack.length != stack.length;
}

// ------------------------------------------------------------------ sushi

/// Unrolled sushi on the bamboo mat: nori sheet, rice layer, filling strips.
class SushiAssemblyPainter extends CustomPainter {
  final List<Ingredient> stack;
  const SushiAssemblyPainter(this.stack);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Bamboo mat.
    final mat = Rect.fromLTWH(w * 0.06, h * 0.18, w * 0.88, h * 0.68);
    canvas.drawRRect(
        RRect.fromRectAndRadius(mat, const Radius.circular(4)),
        Paint()..color = const Color(0xFFC9A86A));
    final slat = Paint()
      ..color = const Color(0xFFA9884C)
      ..strokeWidth = 1.5;
    for (var i = 1; i < 8; i++) {
      final x = mat.left + mat.width * i / 8;
      canvas.drawLine(Offset(x, mat.top + 2), Offset(x, mat.bottom - 2), slat);
    }
    if (stack.isEmpty) return;

    // Nori sheet.
    final nori = Rect.fromLTWH(w * 0.14, h * 0.26, w * 0.72, h * 0.52);
    canvas.drawRRect(
        RRect.fromRectAndRadius(nori, const Radius.circular(3)),
        Paint()
          ..shader = _vGrad(nori,
              [const Color(0xFF25482F), const Color(0xFF16301E)]));

    // Rice layer.
    if (stack.contains(Ingredient.rice)) {
      final riceR = Rect.fromLTWH(w * 0.18, h * 0.32, w * 0.64, h * 0.40);
      canvas.drawRRect(
          RRect.fromRectAndRadius(riceR, const Radius.circular(5)),
          Paint()..color = const Color(0xFFF5F2E8));
      final grain = Paint()..color = const Color(0xFFDAD4C2);
      final rng = Random(3);
      for (var i = 0; i < 26; i++) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(
                    riceR.left + rng.nextDouble() * riceR.width,
                    riceR.top + rng.nextDouble() * riceR.height),
                width: w * 0.035,
                height: w * 0.016),
            grain);
      }
    }

    // Filling strips down the middle.
    final fillings = stack
        .where((i) =>
            i == Ingredient.salmon ||
            i == Ingredient.tuna ||
            i == Ingredient.shrimp ||
            i == Ingredient.cucumber)
        .toList();
    for (var i = 0; i < fillings.length; i++) {
      final rect = Rect.fromLTWH(
          w * 0.20,
          h * (0.46 + 0.11 * (i - (fillings.length - 1) / 2)),
          w * 0.60,
          h * 0.085);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = fillings[i].color);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.4),
              const Radius.circular(4)),
          Paint()..color = Colors.white.withValues(alpha: 0.18));
    }
  }

  @override
  bool shouldRepaint(SushiAssemblyPainter old) =>
      old.stack.length != stack.length;
}

/// Finished roll: plate with three cross-section pieces.
class SushiPlatePainter extends CustomPainter {
  final List<Ingredient> stack;
  const SushiPlatePainter(this.stack);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Plate.
    final plate = Rect.fromCenter(
        center: Offset(w / 2, h * 0.62), width: w * 0.92, height: h * 0.42);
    canvas.drawOval(plate.translate(0, 3),
        Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawOval(
        plate,
        Paint()
          ..shader = _vGrad(plate,
              [const Color(0xFFFAFAFA), const Color(0xFFD9DDE0)]));

    final fillings = stack
        .where((i) =>
            i == Ingredient.salmon ||
            i == Ingredient.tuna ||
            i == Ingredient.shrimp ||
            i == Ingredient.cucumber)
        .toList();

    final pieceR = min(w, h) * 0.17;
    final centers = [
      Offset(w * 0.30, h * 0.48),
      Offset(w * 0.52, h * 0.40),
      Offset(w * 0.72, h * 0.50),
    ];
    for (final pc in centers) {
      // Nori ring.
      canvas.drawCircle(pc, pieceR, Paint()..color = const Color(0xFF1B3A25));
      // Rice.
      canvas.drawCircle(
          pc, pieceR * 0.82, Paint()..color = const Color(0xFFF5F2E8));
      final grain = Paint()..color = const Color(0xFFDAD4C2);
      final rng = Random(pc.dx.toInt());
      for (var i = 0; i < 8; i++) {
        final ang = rng.nextDouble() * 2 * pi;
        final rr = pieceR * (0.45 + rng.nextDouble() * 0.3);
        canvas.drawOval(
            Rect.fromCenter(
                center: pc + Offset(cos(ang), sin(ang)) * rr,
                width: pieceR * 0.18,
                height: pieceR * 0.09),
            grain);
      }
      // Filling core (1-2 wedges).
      if (fillings.isEmpty) {
        canvas.drawCircle(
            pc, pieceR * 0.34, Paint()..color = const Color(0xFFE8E2D2));
      } else if (fillings.length == 1) {
        canvas.drawCircle(pc, pieceR * 0.36,
            Paint()..color = fillings[0].color);
      } else {
        canvas.drawArc(Rect.fromCircle(center: pc, radius: pieceR * 0.38),
            -pi / 2, pi, true, Paint()..color = fillings[0].color);
        canvas.drawArc(Rect.fromCircle(center: pc, radius: pieceR * 0.38),
            pi / 2, pi, true, Paint()..color = fillings[1].color);
      }
      // Gloss.
      canvas.drawArc(
          Rect.fromCircle(center: pc, radius: pieceR * 0.9),
          -pi * 0.8,
          pi * 0.35,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = pieceR * 0.14
            ..strokeCap = StrokeCap.round);
    }
    // Garnish: gari + wasabi.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.86, h * 0.68),
            width: w * 0.10,
            height: h * 0.06),
        Paint()..color = const Color(0xFFF2B8B0));
    canvas.drawCircle(Offset(w * 0.14, h * 0.68), w * 0.035,
        Paint()..color = const Color(0xFF86A63C));
  }

  @override
  bool shouldRepaint(SushiPlatePainter old) =>
      old.stack.length != stack.length;
}

/// Rolling animation: the mat curls around the roll.
class SushiRollingPainter extends CustomPainter {
  final double progress; // 0..1
  const SushiRollingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h * 0.55);
    final rollR = min(w, h) * (0.16 + 0.10 * progress);
    // Mat wrapping.
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: rollR * 1.35),
        pi * (1.0 - progress * 0.9),
        pi * (0.8 + progress),
        false,
        Paint()
          ..color = const Color(0xFFC9A86A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = rollR * 0.35
          ..strokeCap = StrokeCap.round);
    // The roll itself.
    canvas.drawCircle(c, rollR, Paint()..color = const Color(0xFF1B3A25));
    canvas.drawCircle(
        c, rollR * 0.8, Paint()..color = const Color(0xFFF5F2E8));
    canvas.drawCircle(
        c, rollR * 0.33, Paint()..color = const Color(0xFFFA8A6B));
    // Motion lines.
    final ml = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-rollR * 2.0, -rollR * 0.6),
        c.translate(-rollR * 1.4, -rollR * 0.6), ml);
    canvas.drawLine(c.translate(rollR * 1.4, rollR * 0.4),
        c.translate(rollR * 2.0, rollR * 0.4), ml);
  }

  @override
  bool shouldRepaint(SushiRollingPainter old) => old.progress != progress;
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
    final r = size.width * 0.36;
    final raw = const Color(0xFFD98873);
    final cooked = const Color(0xFF5E3520);
    final color = switch (state) {
      CookState.cooking => Color.lerp(raw, cooked, progress)!,
      CookState.done => cooked,
      CookState.burnt => const Color(0xFF241209),
      CookState.empty => Colors.transparent,
    };
    _softShadow(canvas, c.translate(0, r * 0.9), r * 2.0, r * 0.5);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = _rGrad(rect, [
            Color.lerp(color, Colors.white, 0.18)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!,
          ], stops: const [
            0.0,
            0.6,
            1.0
          ]));
    // Grill sear marks.
    final sear = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round;
    for (final dy in [-0.45, 0.0, 0.45]) {
      final half = sqrt(max(0.0, 1 - dy * dy)) * 0.82;
      canvas.drawLine(c.translate(-r * half, r * dy),
          c.translate(r * half, r * dy), sear);
    }
    if (state == CookState.done) {
      _steam(canvas, c.translate(-r * 0.3, -r * 1.05), r * 0.45, 0.7);
      _steam(canvas, c.translate(r * 0.35, -r * 1.0), r * 0.38, 0.6);
    }
    if (state == CookState.burnt) _smoke(canvas, c.translate(0, -r), r * 0.5);
  }

  @override
  bool shouldRepaint(PattyPainter old) =>
      old.state != state || old.progress != progress;
}

// ------------------------------------------------------------------ sides

/// Venue side dish: fries carton / garlic bread board / miso soup bowl.
class SidePainter extends CustomPainter {
  final VenueId venueId;
  final CookState state;
  final double progress;
  const SidePainter(this.venueId, this.state, {this.progress = 1});

  @override
  void paint(Canvas canvas, Size size) {
    switch (venueId) {
      case VenueId.burger:
        _fries(canvas, size);
      case VenueId.pizza:
        _garlicBread(canvas, size);
      case VenueId.sushi:
        _misoSoup(canvas, size);
    }
  }

  void _fries(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final burnt = state == CookState.burnt;
    final friesColor = burnt
        ? const Color(0xFF4A3218)
        : Color.lerp(const Color(0xFFF7E8B0), const Color(0xFFEFB93C),
            state == CookState.cooking ? progress : 1)!;
    _softShadow(canvas, Offset(w / 2, h * 0.9), w * 0.6, h * 0.1);
    final fry = Paint()..color = friesColor;
    final fryHi = Paint()
      ..color = Colors.white.withValues(alpha: burnt ? 0.05 : 0.3);
    for (final f in [
      [-0.24, 0.24, -0.14],
      [-0.10, 0.14, 0.06],
      [0.04, 0.26, -0.04],
      [0.17, 0.18, 0.12],
      [-0.03, 0.33, 0.0],
      [0.26, 0.24, -0.1],
    ]) {
      canvas.save();
      canvas.translate(w / 2 + w * f[0], h * 0.52);
      canvas.rotate(f[2]);
      final rect = Rect.fromCenter(
          center: Offset(0, -h * f[1]),
          width: w * 0.085,
          height: h * (0.3 + f[1]));
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)), fry);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left, rect.top, rect.width * 0.4,
                  rect.height),
              const Radius.circular(3)),
          fryHi);
      canvas.restore();
    }
    // Carton with stripe and dot logo.
    final box = Path()
      ..moveTo(w * 0.2, h * 0.45)
      ..lineTo(w * 0.8, h * 0.45)
      ..lineTo(w * 0.72, h * 0.92)
      ..lineTo(w * 0.28, h * 0.92)
      ..close();
    canvas.drawPath(
        box,
        Paint()
          ..shader = _vGrad(Rect.fromLTRB(0, h * 0.45, w, h * 0.92),
              [const Color(0xFFE05A4E), const Color(0xFFB93A31)]));
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.2, h * 0.45)
          ..lineTo(w * 0.8, h * 0.45)
          ..lineTo(w * 0.78, h * 0.56)
          ..lineTo(w * 0.22, h * 0.56)
          ..close(),
        Paint()..color = const Color(0xFF992E27));
    canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.07,
        Paint()..color = const Color(0xFFF7D046));
    if (burnt) _smoke(canvas, Offset(w * 0.5, h * 0.2), w * 0.16);
  }

  void _garlicBread(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final burnt = state == CookState.burnt;
    final cookT = state == CookState.cooking ? progress : 1.0;
    final bread = burnt
        ? const Color(0xFF3E2A14)
        : Color.lerp(const Color(0xFFF2E3BC), const Color(0xFFE0A857), cookT)!;
    // Wooden board.
    final board = Rect.fromCenter(
        center: Offset(w / 2, h * 0.66), width: w * 0.9, height: h * 0.4);
    canvas.drawOval(board.translate(0, 3),
        Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawOval(
        board,
        Paint()
          ..shader = _vGrad(board,
              [const Color(0xFFB08652), const Color(0xFF8A653B)]));
    // Three slices leaning.
    for (var i = 0; i < 3; i++) {
      final cx = w * (0.30 + 0.20 * i);
      final cy = h * (0.44 - 0.04 * (i % 2));
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(-0.18 + 0.14 * i);
      final slice = Rect.fromCenter(
          center: Offset.zero, width: w * 0.24, height: h * 0.34);
      canvas.drawRRect(
          RRect.fromRectAndRadius(slice, Radius.circular(w * 0.07)),
          Paint()..color = Color.lerp(bread, Colors.black, 0.15)!);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              slice.deflate(w * 0.025), Radius.circular(w * 0.055)),
          Paint()..color = bread);
      // Garlic butter + herbs.
      if (!burnt) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(0, -h * 0.02),
                width: w * 0.15,
                height: h * 0.18),
            Paint()
              ..color = const Color(0xFFF7E9A0)
                  .withValues(alpha: 0.4 + 0.5 * cookT));
        final herb = Paint()..color = const Color(0xFF5A7A3A);
        canvas.drawCircle(Offset(-w * 0.03, -h * 0.06), w * 0.012, herb);
        canvas.drawCircle(Offset(w * 0.04, 0), w * 0.012, herb);
        canvas.drawCircle(Offset(-w * 0.01, h * 0.06), w * 0.012, herb);
      }
      canvas.restore();
    }
    if (burnt) _smoke(canvas, Offset(w * 0.5, h * 0.2), w * 0.16);
  }

  void _misoSoup(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final burnt = state == CookState.burnt;
    final cookT = state == CookState.cooking ? progress : 1.0;
    // Bowl.
    final bowl = Path()
      ..moveTo(w * 0.16, h * 0.45)
      ..lineTo(w * 0.84, h * 0.45)
      ..quadraticBezierTo(w * 0.82, h * 0.92, w * 0.5, h * 0.92)
      ..quadraticBezierTo(w * 0.18, h * 0.92, w * 0.16, h * 0.45)
      ..close();
    _softShadow(canvas, Offset(w / 2, h * 0.92), w * 0.55, h * 0.08);
    canvas.drawPath(
        bowl,
        Paint()
          ..shader = _vGrad(Rect.fromLTRB(0, h * 0.45, w, h * 0.92),
              [const Color(0xFFB3402E), const Color(0xFF7A2A1E)]));
    // Soup surface.
    final soup = burnt
        ? const Color(0xFF3A2A16)
        : Color.lerp(const Color(0xFFCBB98E), const Color(0xFFB59A64), cookT)!;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.45), width: w * 0.68, height: h * 0.16),
        Paint()..color = soup);
    if (!burnt) {
      // Tofu cubes + wakame.
      final tofu = Paint()..color = const Color(0xFFF5F2E8);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(w * 0.42, h * 0.44),
              width: w * 0.09,
              height: h * 0.05),
          tofu);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(w * 0.58, h * 0.47),
              width: w * 0.08,
              height: h * 0.045),
          tofu);
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.44),
              width: w * 0.2,
              height: h * 0.08),
          0.4,
          1.6,
          false,
          Paint()
            ..color = const Color(0xFF2A4A32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      if (cookT > 0.5) {
        _steam(canvas, Offset(w * 0.42, h * 0.36), w * 0.10, 0.6);
        _steam(canvas, Offset(w * 0.6, h * 0.34), w * 0.09, 0.5);
      }
    } else {
      _smoke(canvas, Offset(w * 0.5, h * 0.3), w * 0.14);
    }
    // Bowl foot.
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.93), width: w * 0.22, height: h * 0.04),
        Paint()..color = const Color(0xFF5E2016));
  }

  @override
  bool shouldRepaint(SidePainter old) =>
      old.state != state || old.progress != progress || old.venueId != venueId;
}

// ------------------------------------------------------------------ drinks

/// Venue drink: soda cup with ice / green tea cup.
class DrinkPainter extends CustomPainter {
  final VenueId venueId;
  final double fill; // 0..1
  const DrinkPainter(this.venueId, {this.fill = 1});

  @override
  void paint(Canvas canvas, Size size) {
    if (venueId == VenueId.sushi) {
      _tea(canvas, size);
    } else {
      _soda(canvas, size);
    }
  }

  void _soda(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    _softShadow(canvas, Offset(w / 2, h * 0.93), w * 0.4, h * 0.06);
    final cup = Path()
      ..moveTo(w * 0.28, h * 0.22)
      ..lineTo(w * 0.72, h * 0.22)
      ..lineTo(w * 0.64, h * 0.92)
      ..lineTo(w * 0.36, h * 0.92)
      ..close();
    canvas.drawPath(
        cup,
        Paint()
          ..shader = _vGrad(Rect.fromLTRB(0, h * 0.2, w, h * 0.92),
              [const Color(0xFFF4F8FB), const Color(0xFFD9E2E8)]));
    // Soda fill with ice + bubbles (clipped to cup).
    canvas.save();
    canvas.clipPath(cup);
    final top = h * (0.92 - 0.64 * fill);
    canvas.drawRect(
        Rect.fromLTRB(0, top, w, h),
        Paint()
          ..shader = _vGrad(Rect.fromLTRB(0, top, w, h),
              [const Color(0xFF9A5A34), const Color(0xFF6E3A1E)]));
    if (fill > 0.35) {
      final ice = Paint()..color = Colors.white.withValues(alpha: 0.35);
      canvas.save();
      canvas.translate(w * 0.42, top + h * 0.10);
      canvas.rotate(0.4);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: w * 0.16, height: w * 0.16),
              const Radius.circular(3)),
          ice);
      canvas.restore();
      canvas.save();
      canvas.translate(w * 0.58, top + h * 0.20);
      canvas.rotate(-0.3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: w * 0.14, height: w * 0.14),
              const Radius.circular(3)),
          ice);
      canvas.restore();
      final bubble = Paint()..color = Colors.white.withValues(alpha: 0.4);
      canvas.drawCircle(Offset(w * 0.45, top + h * 0.32), w * 0.02, bubble);
      canvas.drawCircle(Offset(w * 0.55, top + h * 0.42), w * 0.016, bubble);
      canvas.drawCircle(Offset(w * 0.48, top + h * 0.5), w * 0.013, bubble);
    }
    canvas.restore();
    // Lid + straw.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(w * 0.24, h * 0.16, w * 0.76, h * 0.24),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF3D7FBF));
    canvas.drawLine(
        Offset(w * 0.55, h * 0.18),
        Offset(w * 0.63, h * 0.03),
        Paint()
          ..color = const Color(0xFFD64545)
          ..strokeWidth = w * 0.06
          ..strokeCap = StrokeCap.round);
    // Cup gloss.
    canvas.drawLine(
        Offset(w * 0.34, h * 0.30),
        Offset(w * 0.38, h * 0.82),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round);
  }

  void _tea(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Saucer.
    final saucer = Rect.fromCenter(
        center: Offset(w / 2, h * 0.84), width: w * 0.78, height: h * 0.14);
    canvas.drawOval(saucer.translate(0, 2),
        Paint()..color = Colors.black.withValues(alpha: 0.15));
    canvas.drawOval(saucer, Paint()..color = const Color(0xFF8FA893));
    // Ceramic cup.
    final cup = Path()
      ..moveTo(w * 0.30, h * 0.38)
      ..lineTo(w * 0.70, h * 0.38)
      ..quadraticBezierTo(w * 0.70, h * 0.80, w * 0.5, h * 0.80)
      ..quadraticBezierTo(w * 0.30, h * 0.80, w * 0.30, h * 0.38)
      ..close();
    canvas.drawPath(
        cup,
        Paint()
          ..shader = _vGrad(Rect.fromLTRB(0, h * 0.38, w, h * 0.8),
              [const Color(0xFFEFF2EA), const Color(0xFFC5CFC0)]));
    // Speckle glaze.
    final speck = Paint()..color = const Color(0xFF9FB29A);
    canvas.drawCircle(Offset(w * 0.42, h * 0.55), w * 0.015, speck);
    canvas.drawCircle(Offset(w * 0.56, h * 0.62), w * 0.012, speck);
    canvas.drawCircle(Offset(w * 0.48, h * 0.70), w * 0.013, speck);
    // Tea surface.
    final teaLevel = 0.38 + (1 - fill) * 0.2;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, h * teaLevel),
            width: w * 0.36,
            height: h * 0.09),
        Paint()..color = const Color(0xFF9FBF4E));
    if (fill >= 1) {
      _steam(canvas, Offset(w * 0.44, h * 0.30), w * 0.10, 0.55);
      _steam(canvas, Offset(w * 0.58, h * 0.28), w * 0.09, 0.45);
    }
  }

  @override
  bool shouldRepaint(DrinkPainter old) =>
      old.fill != fill || old.venueId != venueId;
}

// -------------------------------------------------------------- customers

/// Procedural cartoon customer with shaded shirt, arms, hair styles,
/// accessories and mood-driven face. The seed picks the look.
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
    Color(0xFF23201E),
    Color(0xFF4E3220),
    Color(0xFFB0722E),
    Color(0xFFD8D8D8),
    Color(0xFF8A3324),
    Color(0xFF2E2E52),
  ];
  static const _shirts = [
    Color(0xFF4A90D9),
    Color(0xFFE07B39),
    Color(0xFF5FA05A),
    Color(0xFF9C5BB0),
    Color(0xFFD64560),
    Color(0xFF3E7C8A),
    Color(0xFFB0A23E),
    Color(0xFF7A6858),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final skin = _skins[rng.nextInt(_skins.length)];
    final skinShade = Color.lerp(skin, Colors.black, 0.12)!;
    final hair = _hairs[rng.nextInt(_hairs.length)];
    final shirt = _shirts[rng.nextInt(_shirts.length)];
    final hairStyle = rng.nextInt(6); // crop, side, long, bun, cap, bald
    final hasGlasses = rng.nextInt(4) == 0;
    final glassStyle = rng.nextInt(2);
    final hasFreckles = rng.nextInt(4) == 0;
    final hasEarring = rng.nextInt(5) == 0;

    final w = size.width;
    final h = size.height;
    final headR = w * 0.27;
    final headC = Offset(w / 2, h * 0.30);

    // ---- torso with shoulders and short arms.
    final bodyTop = h * 0.56;
    final body = Path()
      ..moveTo(w * 0.16, h)
      ..lineTo(w * 0.16, h * 0.82)
      ..quadraticBezierTo(w * 0.15, bodyTop, w * 0.32, bodyTop - h * 0.02)
      ..quadraticBezierTo(w * 0.5, bodyTop - h * 0.055, w * 0.68,
          bodyTop - h * 0.02)
      ..quadraticBezierTo(w * 0.85, bodyTop, w * 0.84, h * 0.82)
      ..lineTo(w * 0.84, h)
      ..close();
    canvas.drawPath(
        body,
        Paint()
          ..shader = _vGrad(Rect.fromLTRB(0, bodyTop, w, h), [
            Color.lerp(shirt, Colors.white, 0.12)!,
            shirt,
            Color.lerp(shirt, Colors.black, 0.15)!,
          ]));
    // Collar V.
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.42, bodyTop - h * 0.025)
          ..lineTo(w * 0.5, bodyTop + h * 0.05)
          ..lineTo(w * 0.58, bodyTop - h * 0.025)
          ..close(),
        Paint()..color = skinShade);
    // Arms hanging at the sides.
    final arm = Paint()..color = Color.lerp(shirt, Colors.black, 0.08)!;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.10, h * 0.62, w * 0.10, h * 0.3),
            Radius.circular(w * 0.05)),
        arm);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.80, h * 0.62, w * 0.10, h * 0.3),
            Radius.circular(w * 0.05)),
        arm);
    // Hands.
    canvas.drawCircle(Offset(w * 0.15, h * 0.93), w * 0.05,
        Paint()..color = skin);
    canvas.drawCircle(Offset(w * 0.85, h * 0.93), w * 0.05,
        Paint()..color = skin);

    // ---- neck + head.
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w / 2, h * 0.55),
            width: headR * 0.55,
            height: h * 0.07),
        Paint()..color = skinShade);
    // Ears.
    canvas.drawCircle(
        headC.translate(-headR * 0.98, headR * 0.08), headR * 0.16,
        Paint()..color = skin);
    canvas.drawCircle(
        headC.translate(headR * 0.98, headR * 0.08), headR * 0.16,
        Paint()..color = skin);
    if (hasEarring) {
      canvas.drawCircle(headC.translate(headR * 1.02, headR * 0.24),
          headR * 0.06, Paint()..color = const Color(0xFFF7D046));
    }
    // Face with subtle radial shading.
    final faceRect = Rect.fromCircle(center: headC, radius: headR);
    canvas.drawCircle(
        headC,
        headR,
        Paint()
          ..shader = _rGrad(faceRect, [
            Color.lerp(skin, Colors.white, 0.10)!,
            skin,
            skinShade,
          ], stops: const [
            0.0,
            0.72,
            1.0
          ]));

    // ---- hair / hat.
    final hairPaint = Paint()..color = hair;
    final hairHi = Paint()
      ..color = Color.lerp(hair, Colors.white, 0.25)!
      ..strokeWidth = headR * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (hairStyle) {
      case 0: // short crop
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.03),
            pi * 1.02, pi * 0.96, true, hairPaint);
        canvas.drawArc(
            Rect.fromCircle(
                center: headC.translate(0, headR * 0.06),
                radius: headR * 0.85),
            pi * 1.25,
            pi * 0.35,
            false,
            hairHi);
      case 1: // side part
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.04),
            pi * 0.95, pi * 1.0, true, hairPaint);
        canvas.drawPath(
            Path()
              ..moveTo(headC.dx - headR * 0.9, headC.dy - headR * 0.1)
              ..quadraticBezierTo(
                  headC.dx - headR * 0.3,
                  headC.dy - headR * 0.75,
                  headC.dx + headR * 0.85,
                  headC.dy - headR * 0.35)
              ..lineTo(headC.dx + headR * 0.9, headC.dy - headR * 0.05)
              ..quadraticBezierTo(headC.dx, headC.dy - headR * 1.2,
                  headC.dx - headR * 0.9, headC.dy - headR * 0.1)
              ..close(),
            hairPaint);
      case 2: // long hair
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.06),
            pi, pi, true, hairPaint);
        for (final side in [-1, 1]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: headC.translate(
                          headR * 0.92 * side, headR * 0.5),
                      width: headR * 0.45,
                      height: headR * 1.6),
                  Radius.circular(headR * 0.22)),
              hairPaint);
        }
      case 3: // bun
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.03),
            pi * 1.02, pi * 0.96, true, hairPaint);
        canvas.drawCircle(
            headC.translate(0, -headR * 1.05), headR * 0.32, hairPaint);
      case 4: // baseball cap
        final capColor = _shirts[(seed >> 3) % _shirts.length];
        final capPaint = Paint()..color = capColor;
        canvas.drawArc(Rect.fromCircle(center: headC, radius: headR * 1.06),
            pi, pi, true, capPaint);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: headC.translate(headR * 0.6, -headR * 0.30),
                    width: headR * 1.15,
                    height: headR * 0.26),
                Radius.circular(headR * 0.13)),
            Paint()..color = Color.lerp(capColor, Colors.black, 0.2)!);
        canvas.drawCircle(headC.translate(0, -headR * 1.02), headR * 0.09,
            Paint()..color = Color.lerp(capColor, Colors.black, 0.3)!);
      case 5: // bald with side tufts
        canvas.drawCircle(headC.translate(-headR * 0.88, headR * 0.05),
            headR * 0.18, hairPaint);
        canvas.drawCircle(headC.translate(headR * 0.88, headR * 0.05),
            headR * 0.18, hairPaint);
        canvas.drawArc(
            Rect.fromCircle(
                center: headC.translate(-headR * 0.2, -headR * 0.4),
                radius: headR * 0.5),
            pi * 1.2,
            pi * 0.3,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.25)
              ..strokeWidth = headR * 0.08
              ..strokeCap = StrokeCap.round
              ..style = PaintingStyle.stroke);
    }

    // ---- face.
    final eyeY = headC.dy + headR * 0.02;
    final eyeDx = headR * 0.38;
    final inkColor = const Color(0xFF2A2320);
    final ink = Paint()..color = inkColor;

    // Eyes: whites + pupils (X-eyes handled by angry brows instead).
    for (final side in [-1, 1]) {
      final ec = Offset(headC.dx + eyeDx * side, eyeY);
      canvas.drawOval(
          Rect.fromCenter(
              center: ec, width: headR * 0.30, height: headR * 0.34),
          Paint()..color = Colors.white);
      canvas.drawCircle(ec.translate(0, headR * 0.02), headR * 0.09, ink);
      canvas.drawCircle(ec.translate(-headR * 0.03, -headR * 0.02),
          headR * 0.03, Paint()..color = Colors.white);
      if (mood == CustomerMood.impatient || mood == CustomerMood.angry) {
        // Heavy eyelid.
        canvas.drawRect(
            Rect.fromLTWH(ec.dx - headR * 0.16, ec.dy - headR * 0.18,
                headR * 0.32, headR * 0.12),
            Paint()..color = skin);
      }
    }

    // Brows.
    final brow = Paint()
      ..color = Color.lerp(hair, inkColor, 0.5)!
      ..strokeWidth = headR * 0.10
      ..strokeCap = StrokeCap.round;
    final browY = eyeY - headR * 0.28;
    final browTilt = switch (mood) {
      CustomerMood.happy => -0.04,
      CustomerMood.neutral => 0.0,
      CustomerMood.impatient => 0.10,
      CustomerMood.angry => 0.22,
    };
    for (final side in [-1, 1]) {
      canvas.drawLine(
          Offset(headC.dx + (eyeDx - headR * 0.16) * side,
              browY + headR * browTilt * 1.4),
          Offset(headC.dx + (eyeDx + headR * 0.16) * side,
              browY - headR * browTilt),
          brow);
    }

    if (hasGlasses) {
      final gp = Paint()
        ..color = const Color(0xFF33302E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.06;
      if (glassStyle == 0) {
        for (final side in [-1, 1]) {
          canvas.drawCircle(
              Offset(headC.dx + eyeDx * side, eyeY), headR * 0.22, gp);
        }
      } else {
        for (final side in [-1, 1]) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset(headC.dx + eyeDx * side, eyeY),
                      width: headR * 0.42,
                      height: headR * 0.34),
                  Radius.circular(headR * 0.08)),
              gp);
        }
      }
      canvas.drawLine(Offset(headC.dx - eyeDx + headR * 0.22, eyeY),
          Offset(headC.dx + eyeDx - headR * 0.22, eyeY), gp);
    }

    if (hasFreckles) {
      final fr = Paint()..color = skinShade;
      for (final side in [-1, 1]) {
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
              headC.translate(
                  (headR * 0.5 + i * headR * 0.09) * side, headR * 0.28),
              headR * 0.025,
              fr);
        }
      }
    }

    // Blush for happy.
    if (mood == CustomerMood.happy) {
      final blush = Paint()
        ..color = const Color(0xFFE58A8A).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      for (final side in [-1, 1]) {
        canvas.drawOval(
            Rect.fromCenter(
                center: headC.translate(headR * 0.58 * side, headR * 0.3),
                width: headR * 0.28,
                height: headR * 0.16),
            blush);
      }
    }

    // Mouth by mood.
    final mouthStroke = Paint()
      ..color = inkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = headR * 0.08
      ..strokeCap = StrokeCap.round;
    final mouthC = headC.translate(0, headR * 0.48);
    switch (mood) {
      case CustomerMood.happy:
        // Open smile with teeth.
        final smile = Path()
          ..moveTo(mouthC.dx - headR * 0.28, mouthC.dy - headR * 0.06)
          ..quadraticBezierTo(mouthC.dx, mouthC.dy + headR * 0.34,
              mouthC.dx + headR * 0.28, mouthC.dy - headR * 0.06)
          ..close();
        canvas.drawPath(smile, Paint()..color = const Color(0xFF7A3B3B));
        canvas.drawRect(
            Rect.fromLTWH(mouthC.dx - headR * 0.2,
                mouthC.dy - headR * 0.06, headR * 0.4, headR * 0.08),
            Paint()..color = Colors.white);
      case CustomerMood.neutral:
        canvas.drawLine(mouthC.translate(-headR * 0.18, 0),
            mouthC.translate(headR * 0.18, 0), mouthStroke);
      case CustomerMood.impatient:
        canvas.drawArc(
            Rect.fromCircle(
                center: mouthC.translate(0, headR * 0.16),
                radius: headR * 0.22),
            pi * 1.15,
            pi * 0.7,
            false,
            mouthStroke);
      case CustomerMood.angry:
        // Gritted teeth.
        final grit = Rect.fromCenter(
            center: mouthC.translate(0, headR * 0.02),
            width: headR * 0.5,
            height: headR * 0.18);
        canvas.drawRRect(
            RRect.fromRectAndRadius(grit, Radius.circular(headR * 0.06)),
            Paint()..color = Colors.white);
        canvas.drawRRect(
            RRect.fromRectAndRadius(grit, Radius.circular(headR * 0.06)),
            mouthStroke..strokeWidth = headR * 0.05);
        for (var i = 1; i < 4; i++) {
          final x = grit.left + grit.width * i / 4;
          canvas.drawLine(Offset(x, grit.top), Offset(x, grit.bottom),
              mouthStroke..strokeWidth = headR * 0.04);
        }
        // Steam mark.
        final steam = Paint()
          ..color = const Color(0xFFD64545)
          ..strokeWidth = headR * 0.08
          ..strokeCap = StrokeCap.round;
        final sBase = headC.translate(headR * 0.95, -headR * 0.85);
        canvas.drawLine(
            sBase, sBase.translate(headR * 0.22, -headR * 0.22), steam);
        canvas.drawLine(sBase.translate(headR * 0.3, 0.0),
            sBase.translate(headR * 0.52, -headR * 0.22), steam);
    }
  }

  @override
  bool shouldRepaint(CustomerPainter old) =>
      old.seed != seed || old.mood != mood;
}

// ---------------------------------------------------------- venue emblems

/// Big dish emblem for venue cards: burger / pizza slice / sushi piece.
class VenueEmblemPainter extends CustomPainter {
  final VenueId venueId;
  const VenueEmblemPainter(this.venueId);

  @override
  void paint(Canvas canvas, Size size) {
    switch (venueId) {
      case VenueId.burger:
        const BurgerPainter([
          Ingredient.bunBottom,
          Ingredient.patty,
          Ingredient.cheese,
          Ingredient.tomato,
          Ingredient.lettuce,
          Ingredient.bunTop,
        ]).paint(canvas, size);
      case VenueId.pizza:
        const PizzaPainter(
          [
            Ingredient.dough,
            Ingredient.pizzaSauce,
            Ingredient.mozzarella,
            Ingredient.pepperoni,
            Ingredient.olive,
          ],
          state: CookState.done,
        ).paint(canvas, size);
      case VenueId.sushi:
        const SushiPlatePainter([
          Ingredient.nori,
          Ingredient.rice,
          Ingredient.salmon,
          Ingredient.cucumber,
        ]).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(VenueEmblemPainter old) => old.venueId != venueId;
}

// ------------------------------------------------------------- chef logo

/// Chef hat emblem for the menu header.
class ChefLogoPainter extends CustomPainter {
  final Color accent;
  const ChefLogoPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h * 0.42);
    _softShadow(canvas, c.translate(0, h * 0.34), w * 0.6, h * 0.12);
    final hat = Paint()
      ..shader = _vGrad(Rect.fromLTWH(0, 0, w, h),
          [Colors.white, const Color(0xFFDDE2E8)]);
    canvas.drawCircle(c.translate(-w * 0.2, -h * 0.05), w * 0.16, hat);
    canvas.drawCircle(c.translate(0, -h * 0.12), w * 0.19, hat);
    canvas.drawCircle(c.translate(w * 0.2, -h * 0.05), w * 0.16, hat);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, h * 0.1),
                width: w * 0.52,
                height: h * 0.3),
            const Radius.circular(6)),
        hat);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, h * 0.28),
                width: w * 0.52,
                height: h * 0.09),
            const Radius.circular(4)),
        Paint()..color = accent);
  }

  @override
  bool shouldRepaint(ChefLogoPainter old) => old.accent != accent;
}

// --------------------------------------------------------- dining backdrop

/// The venue's back wall: window scene, shelf decor, tiles, string lights.
class DiningBackdropPainter extends CustomPainter {
  final VenueDef venue;
  const DiningBackdropPainter(this.venue);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Wall gradient.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader =
              _vGrad(Offset.zero & size, [venue.wallTop, venue.wallBottom]));

    // Lower-wall tile wainscot.
    final tileTop = h * 0.52;
    final tile = Paint()
      ..color = Colors.white.withValues(alpha: 0.16);
    final tileLine = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTRB(0, tileTop, w, h * 0.78), tile);
    for (var x = 0.0; x < w; x += w / 9) {
      canvas.drawLine(Offset(x, tileTop), Offset(x, h * 0.78), tileLine);
    }
    canvas.drawLine(Offset(0, (tileTop + h * 0.78) / 2),
        Offset(w, (tileTop + h * 0.78) / 2), tileLine);

    // Window with venue scene.
    final win = Rect.fromLTWH(w * 0.05, h * 0.06, w * 0.26, h * 0.42);
    final frame = Paint()..color = Colors.black.withValues(alpha: 0.28);
    canvas.drawRRect(
        RRect.fromRectAndRadius(win.inflate(4), const Radius.circular(8)),
        frame);
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(win, const Radius.circular(6)));
    switch (venue.id) {
      case VenueId.burger: // day sky, sun, clouds
        canvas.drawRect(
            win,
            Paint()
              ..shader = _vGrad(win,
                  [const Color(0xFF6EB6E8), const Color(0xFFBDE0F2)]));
        canvas.drawCircle(Offset(win.right - win.width * 0.25, win.top + win.height * 0.22),
            win.width * 0.13, Paint()..color = const Color(0xFFFFE082));
        final cloud = Paint()..color = Colors.white.withValues(alpha: 0.9);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(win.left + win.width * 0.3,
                    win.top + win.height * 0.4),
                width: win.width * 0.4,
                height: win.height * 0.12),
            cloud);
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(win.left + win.width * 0.6,
                    win.top + win.height * 0.62),
                width: win.width * 0.5,
                height: win.height * 0.14),
            cloud);
      case VenueId.pizza: // warm evening, rooftops
        canvas.drawRect(
            win,
            Paint()
              ..shader = _vGrad(win,
                  [const Color(0xFFF2B75C), const Color(0xFFE28A4E)]));
        canvas.drawCircle(
            Offset(win.left + win.width * 0.3, win.top + win.height * 0.3),
            win.width * 0.11,
            Paint()..color = const Color(0xFFFBE3A3));
        final roof = Paint()..color = const Color(0xFF8A5238);
        canvas.drawRect(
            Rect.fromLTWH(win.left, win.bottom - win.height * 0.28,
                win.width * 0.45, win.height * 0.28),
            roof);
        canvas.drawRect(
            Rect.fromLTWH(win.left + win.width * 0.55,
                win.bottom - win.height * 0.38, win.width * 0.45,
                win.height * 0.38),
            Paint()..color = const Color(0xFF74452C));
        canvas.drawRect(
            Rect.fromLTWH(win.left + win.width * 0.62,
                win.bottom - win.height * 0.30, win.width * 0.10,
                win.height * 0.10),
            Paint()..color = const Color(0xFFFBE3A3));
      case VenueId.sushi: // harbour: sea, boat, gull
        canvas.drawRect(
            win,
            Paint()
              ..shader = _vGrad(win,
                  [const Color(0xFF9FD4E0), const Color(0xFFCBEAF0)]));
        canvas.drawRect(
            Rect.fromLTWH(win.left, win.bottom - win.height * 0.35,
                win.width, win.height * 0.35),
            Paint()..color = const Color(0xFF4E8FA8));
        final wave = Paint()
          ..color = Colors.white.withValues(alpha: 0.4)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
              Rect.fromCenter(
                  center: Offset(win.left + win.width * (0.25 + 0.25 * i),
                      win.bottom - win.height * (0.18 + 0.05 * (i % 2))),
                  width: win.width * 0.16,
                  height: win.height * 0.05),
              pi,
              pi,
              false,
              wave);
        }
        // Little boat.
        final boatY = win.bottom - win.height * 0.33;
        canvas.drawPath(
            Path()
              ..moveTo(win.left + win.width * 0.55, boatY)
              ..lineTo(win.left + win.width * 0.85, boatY)
              ..lineTo(win.left + win.width * 0.78, boatY + win.height * 0.08)
              ..lineTo(win.left + win.width * 0.62, boatY + win.height * 0.08)
              ..close(),
            Paint()..color = const Color(0xFF8A4B2D));
        canvas.drawLine(
            Offset(win.left + win.width * 0.7, boatY),
            Offset(win.left + win.width * 0.7, boatY - win.height * 0.14),
            Paint()
              ..color = const Color(0xFF5E4030)
              ..strokeWidth = 2);
        canvas.drawPath(
            Path()
              ..moveTo(win.left + win.width * 0.7, boatY - win.height * 0.14)
              ..lineTo(win.left + win.width * 0.82, boatY - win.height * 0.04)
              ..lineTo(win.left + win.width * 0.7, boatY - win.height * 0.04)
              ..close(),
            Paint()..color = Colors.white);
    }
    canvas.restore();
    // Window cross bars.
    canvas.drawLine(Offset(win.center.dx, win.top), Offset(win.center.dx, win.bottom),
        Paint()..color = Colors.black.withValues(alpha: 0.22)..strokeWidth = 3);
    canvas.drawLine(Offset(win.left, win.center.dy), Offset(win.right, win.center.dy),
        Paint()..color = Colors.black.withValues(alpha: 0.22)..strokeWidth = 3);

    // Shelf with plant + jar on the right.
    final shelfY = h * 0.20;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.72, shelfY, w * 0.22, h * 0.025),
            const Radius.circular(3)),
        Paint()..color = Colors.black.withValues(alpha: 0.30));
    // Plant pot.
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.755, shelfY)
          ..lineTo(w * 0.795, shelfY)
          ..lineTo(w * 0.787, shelfY - h * 0.045)
          ..lineTo(w * 0.763, shelfY - h * 0.045)
          ..close(),
        Paint()..color = const Color(0xFFB3603C));
    final leaf = Paint()..color = const Color(0xFF5FA05A);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.775, shelfY - h * 0.075),
            width: w * 0.02,
            height: h * 0.055),
        leaf);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.762, shelfY - h * 0.062),
            width: w * 0.018,
            height: h * 0.045),
        leaf);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.788, shelfY - h * 0.062),
            width: w * 0.018,
            height: h * 0.045),
        leaf);
    // Jar.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.86, shelfY - h * 0.05, w * 0.035, h * 0.05),
            const Radius.circular(3)),
        Paint()..color = venue.accent.withValues(alpha: 0.75));

    // Menu board between window and shelf.
    final board = Rect.fromLTWH(w * 0.40, h * 0.08, w * 0.22, h * 0.20);
    canvas.drawRRect(
        RRect.fromRectAndRadius(board.inflate(3), const Radius.circular(6)),
        Paint()..color = const Color(0xFF5E4030));
    canvas.drawRRect(
        RRect.fromRectAndRadius(board, const Radius.circular(4)),
        Paint()..color = const Color(0xFF2E3830));
    final chalk = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(board.left + board.width * 0.15,
              board.top + board.height * (0.3 + 0.22 * i)),
          Offset(board.right - board.width * (0.15 + 0.1 * (i % 2)),
              board.top + board.height * (0.3 + 0.22 * i)),
          chalk);
    }
    canvas.drawCircle(
        Offset(board.left + board.width * 0.5, board.top + board.height * 0.14),
        3,
        Paint()..color = venue.accent);

    // String lights across the top.
    final wirePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final wire = Path()
      ..moveTo(0, h * 0.015)
      ..quadraticBezierTo(w * 0.25, h * 0.07, w * 0.5, h * 0.03)
      ..quadraticBezierTo(w * 0.75, h * 0.075, w, h * 0.02);
    canvas.drawPath(wire, wirePaint);
    final bulbColors = [
      const Color(0xFFF7D046),
      venue.accent,
      const Color(0xFFF7D046),
      venue.accent,
      const Color(0xFFF7D046),
      venue.accent,
      const Color(0xFFF7D046),
    ];
    for (var i = 0; i < bulbColors.length; i++) {
      final t = (i + 0.75) / (bulbColors.length + 0.5);
      // Approximate the wire's y at t.
      final y = h * (0.02 + 0.045 * (0.5 - (t - 0.5).abs()) * 2) + h * 0.012;
      canvas.drawCircle(
          Offset(w * t, y + h * 0.012),
          w * 0.008,
          Paint()
            ..color = bulbColors[i]
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    }
  }

  @override
  bool shouldRepaint(DiningBackdropPainter old) => old.venue.id != venue.id;
}

// -------------------------------------------------------------- factories

/// The right painter for a main dish given its stack and where it sits.
CustomPainter mainDishPainter(
  VenueDef venue,
  List<Ingredient> stack, {
  bool finished = false,
  CookState state = CookState.done,
  double progress = 1,
}) {
  switch (venue.flow) {
    case VenueFlow.cookThenAssemble:
      return BurgerPainter(stack);
    case VenueFlow.assembleThenCook:
      return PizzaPainter(stack,
          state: finished ? CookState.done : state, progress: progress);
    case VenueFlow.assembleThenRoll:
      return finished
          ? SushiPlatePainter(stack)
          : SushiAssemblyPainter(stack);
  }
}

/// Small tray icon for one ingredient (drawn as a heap/slice on a tray).
class TrayIconPainter extends CustomPainter {
  final Ingredient ingredient;
  const TrayIconPainter(this.ingredient);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    switch (ingredient) {
      case Ingredient.bunBottom:
      case Ingredient.bunTop:
      case Ingredient.patty:
      case Ingredient.cheese:
      case Ingredient.tomato:
      case Ingredient.lettuce:
        BurgerPainter([ingredient]).paint(canvas, size);
      case Ingredient.dough:
        canvas.drawCircle(
            c,
            w * 0.36,
            Paint()
              ..shader = _rGrad(Rect.fromCircle(center: c, radius: w * 0.36),
                  [const Color(0xFFF5E7C0), const Color(0xFFE0C890)]));
        canvas.drawCircle(c, w * 0.26,
            Paint()..color = const Color(0xFFEFD9A7));
      case Ingredient.pizzaSauce:
        // Sauce ladle blob.
        canvas.drawCircle(c, w * 0.3,
            Paint()..color = const Color(0xFFC63D2F));
        canvas.drawCircle(c.translate(-w * 0.08, -w * 0.08), w * 0.08,
            Paint()..color = const Color(0xFFE05B4A));
      case Ingredient.mozzarella:
        // Shredded cheese heap.
        final p = Paint()
          ..color = const Color(0xFFF7E8B0)
          ..strokeWidth = w * 0.05
          ..strokeCap = StrokeCap.round;
        final rng = Random(5);
        for (var i = 0; i < 9; i++) {
          final a = rng.nextDouble() * pi;
          final off = Offset((rng.nextDouble() - 0.5) * w * 0.5,
              (rng.nextDouble() - 0.5) * h * 0.4);
          canvas.drawLine(c + off,
              c + off + Offset(cos(a), sin(a)) * w * 0.16, p);
        }
      case Ingredient.pepperoni:
        for (final o in [
          Offset(-w * 0.14, -h * 0.08),
          Offset(w * 0.14, -h * 0.02),
          Offset(0, h * 0.14),
        ]) {
          canvas.drawCircle(c + o, w * 0.15,
              Paint()..color = const Color(0xFF8A2A1C));
          canvas.drawCircle(c + o, w * 0.125,
              Paint()..color = const Color(0xFFC24936));
        }
      case Ingredient.mushroom:
        canvas.drawArc(
            Rect.fromCenter(
                center: c.translate(0, -h * 0.04),
                width: w * 0.5,
                height: h * 0.42),
            pi,
            pi,
            true,
            Paint()..color = const Color(0xFFAE9576));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: c.translate(0, h * 0.14),
                    width: w * 0.16,
                    height: h * 0.24),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFFD9C4A3));
      case Ingredient.olive:
        for (final o in [
          Offset(-w * 0.12, -h * 0.06),
          Offset(w * 0.12, 0),
          Offset(-w * 0.02, h * 0.14),
        ]) {
          canvas.drawCircle(c + o, w * 0.11,
              Paint()..color = const Color(0xFF2F3325));
          canvas.drawCircle(c + o, w * 0.045,
              Paint()..color = const Color(0xFF5A6147));
        }
      case Ingredient.nori:
        final r = Rect.fromCenter(
            center: c, width: w * 0.6, height: h * 0.55);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(3)),
            Paint()
              ..shader = _vGrad(r,
                  [const Color(0xFF25482F), const Color(0xFF16301E)]));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                r.translate(-w * 0.06, -h * 0.06), const Radius.circular(3)),
            Paint()..color = const Color(0xFF1E3B2A));
      case Ingredient.rice:
        // Rice mound in a bowl.
        canvas.drawArc(
            Rect.fromCenter(
                center: c.translate(0, h * 0.1),
                width: w * 0.6,
                height: h * 0.5),
            0,
            pi,
            true,
            Paint()..color = const Color(0xFF7A4B3A));
        canvas.drawOval(
            Rect.fromCenter(
                center: c.translate(0, -h * 0.02),
                width: w * 0.52,
                height: h * 0.3),
            Paint()..color = const Color(0xFFF5F2E8));
        final grain = Paint()..color = const Color(0xFFDAD4C2);
        canvas.drawOval(
            Rect.fromCenter(
                center: c.translate(-w * 0.1, -h * 0.05),
                width: w * 0.06,
                height: h * 0.025),
            grain);
        canvas.drawOval(
            Rect.fromCenter(
                center: c.translate(w * 0.08, -h * 0.01),
                width: w * 0.06,
                height: h * 0.025),
            grain);
      case Ingredient.salmon:
      case Ingredient.tuna:
        // Fish slab with sinew lines.
        final r = Rect.fromCenter(
            center: c, width: w * 0.62, height: h * 0.4);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(w * 0.1)),
            Paint()..color = ingredient.color);
        final sinew = Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final x = r.left + r.width * (0.25 + 0.25 * i);
          canvas.drawLine(Offset(x, r.top + r.height * 0.15),
              Offset(x - w * 0.08, r.bottom - r.height * 0.15), sinew);
        }
      case Ingredient.shrimp:
        // Curled shrimp.
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: w * 0.24),
            -pi * 0.2,
            pi * 1.2,
            false,
            Paint()
              ..color = ingredient.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = w * 0.16
              ..strokeCap = StrokeCap.round);
        final stripe = Paint()
          ..color = const Color(0xFFD9755A)
          ..strokeWidth = w * 0.03;
        for (var i = 0; i < 3; i++) {
          final a = pi * (0.15 + 0.3 * i);
          canvas.drawLine(
              c + Offset(cos(a), sin(a)) * w * 0.16,
              c + Offset(cos(a), sin(a)) * w * 0.32,
              stripe);
        }
      case Ingredient.cucumber:
        final r = Rect.fromCenter(
            center: c, width: w * 0.56, height: h * 0.34);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(w * 0.12)),
            Paint()..color = const Color(0xFF3E7C3A));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                r.deflate(w * 0.05), Radius.circular(w * 0.09)),
            Paint()..color = const Color(0xFFA8D89A));
        canvas.drawCircle(c, w * 0.05,
            Paint()..color = const Color(0xFFD5EFC8));
    }
  }

  @override
  bool shouldRepaint(TrayIconPainter old) => old.ingredient != ingredient;
}
