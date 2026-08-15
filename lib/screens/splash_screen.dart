import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Splash screen H2O Laundry: logo muncul di atas latar gradien
/// dengan gelembung sabun yang naik.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bubbles = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _bubbles.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final scale = Tween<double>(begin: 0.7, end: 1).animate(
        CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _bubbles,
              builder: (context, _) => CustomPaint(
                painter: _BubblePainter(_bubbles.value),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 168,
                        height: 168,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset('assets/logo.png',
                            fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'PARAKAN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Laundry bersih, wangi, dan rapi',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gelembung sabun naik: posisi/ukuran/kecepatan deterministik per
/// indeks supaya animasinya mulus saat controller mengulang.
class _BubblePainter extends CustomPainter {
  _BubblePainter(this.t);

  final double t;

  static const _count = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var i = 0; i < _count; i++) {
      final fx = (i * 0.381966) % 1.0; // sebaran emas agar merata
      final speed = 0.55 + ((i * 29) % 10) / 14;
      final phase = (i * 0.173) % 1.0;
      final radius = 4.0 + ((i * 17) % 22);

      final progress = (phase + t * speed) % 1.0;
      final y = size.height * (1.08 - 1.2 * progress);
      final wobble =
          math.sin(progress * math.pi * 4 + i) * (6 + radius * 0.4);
      final x = size.width * fx + wobble;

      // Memudar saat mendekati atas.
      final alpha = 0.28 * (1 - progress) + 0.04;
      fill.color = Colors.white.withValues(alpha: alpha * 0.5);
      ring.color = Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), radius, fill);
      canvas.drawCircle(Offset(x, y), radius, ring);
      // Kilau kecil di kiri-atas gelembung.
      fill.color = Colors.white.withValues(alpha: alpha * 1.6);
      canvas.drawCircle(
          Offset(x - radius * 0.35, y - radius * 0.35), radius * 0.18, fill);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => oldDelegate.t != t;
}
