// Visualizer musik gaya LUNA: sampul album bundar yang berputar pelan
// seperti piringan hitam, dikelilingi cincin batang spektrum yang
// menari. Mesin gerakannya dibawa dari AudioVisualizer wca_app.
//
// JUJUR SOAL CARA KERJANYA
// Ini bukan FFT sungguhan — video_player tidak membuka akses data
// audio. Tinggi batang datang dari lapisan gelombang sinus yang
// digerakkan posisi lagu: bergerak seperti visualizer, ikut berhenti
// saat lagu dijeda, dan hampir tak ada yang sadar bedanya.
//
// IDENTITAS PER LAGU
// Judul lagu menjadi benih frekuensi, fase, dan paletnya — lagu yang
// sama selalu tampil sama, dua lagu jarang kembar.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class LunaVisualizer extends StatefulWidget {
  const LunaVisualizer({
    super.key,
    required this.seed,
    required this.imageUrl,
    required this.playing,
    required this.position,
    this.size = 300,
  });

  /// Benih identitas visual — judul lagu.
  final String seed;
  final String imageUrl;
  final bool playing;
  final Duration position;

  /// Diameter total termasuk cincin batang.
  final double size;

  @override
  State<LunaVisualizer> createState() => _LunaVisualizerState();
}

class _LunaVisualizerState extends State<LunaVisualizer>
    with TickerProviderStateMixin {
  /// Waktu kontinu untuk gerakan batang (60 fps).
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  /// Putaran piringan: satu putaran tiap 14 detik saat lagu berbunyi.
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  /// Seberapa "hidup" batangnya; melandai ke 0 saat dijeda supaya
  /// turun pelan, bukan mati mendadak.
  double _energy = 0;

  @override
  void initState() {
    super.initState();
    if (widget.playing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant LunaVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _time.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.size * 0.60;
    return AnimatedBuilder(
      animation: _time,
      builder: (context, _) {
        final target = widget.playing ? 1.0 : 0.0;
        _energy += (target - _energy) * 0.08;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _RingPainter(
                  seed: widget.seed,
                  t: widget.position.inMilliseconds / 1000.0 +
                      _time.value,
                  energy: _energy,
                  artRadius: art / 2,
                ),
              ),
              RotationTransition(
                turns: _spin,
                child: Container(
                  width: art,
                  height: art,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 2),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.imageUrl.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF1B4E77),
                                  Color(0xFF0A1A2F)
                                ],
                              ),
                            ),
                            child: const Icon(Icons.music_note,
                                size: 64, color: Colors.white38),
                          )
                        : Image.network(
                            widget.imageUrl,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFF1B4E77),
                              child: const Icon(Icons.music_note,
                                  size: 64, color: Colors.white38),
                            ),
                          ),
                  ),
                ),
              ),
              // Lubang tengah kecil ala piringan hitam.
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF060E18),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.seed,
    required this.t,
    required this.energy,
    required this.artRadius,
  });

  final String seed;
  final double t;
  final double energy;
  final double artRadius;

  /// Palet tiga warna, sengaja pekat — duduk di atas latar gelap.
  static const _palettes = <List<Color>>[
    [Color(0xFF00E5FF), Color(0xFF2979FF), Color(0xFF651FFF)], // es
    [Color(0xFFF6C445), Color(0xFFFF8A3D), Color(0xFFE4572E)], // kuningan
    [Color(0xFF00E676), Color(0xFF00BFA5), Color(0xFF1DE9B6)], // laut
    [Color(0xFFFF4081), Color(0xFFE040FB), Color(0xFF7C4DFF)], // anggrek
    [Color(0xFF64FFDA), Color(0xFF18FFFF), Color(0xFF40C4FF)], // laguna
    [Color(0xFFFFD54F), Color(0xFFFFF176), Color(0xFFAEEA00)], // surya
  ];

  int get _hash {
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    return h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = _hash;
    final palette = _palettes[h % _palettes.length];
    // Tiga kecepatan gelombang per lagu, seperti wca_app.
    final f1 = 1.1 + (h % 17) / 12.0;
    final f2 = 2.3 + ((h >> 5) % 23) / 9.0;
    final f3 = 0.6 + ((h >> 9) % 11) / 14.0;
    final phase = (h % 360) * math.pi / 180;

    final center = Offset(size.width / 2, size.height / 2);
    const count = 72;
    final inner = artRadius + 8;
    final maxLen = size.width / 2 - inner - 4;

    for (var i = 0; i < count; i++) {
      final theta = (i / count) * 2 * math.pi - math.pi / 2;
      // Harmonik bilangan bulat terhadap sudut supaya batang pertama
      // dan terakhir menyambung mulus (tanpa "jahitan").
      var v = 0.5 * math.sin(theta * 3 + t * f1 + phase) +
          0.32 * math.sin(theta * 5 - t * f2 + phase * 0.7) +
          0.18 * math.sin(theta * 8 + t * f3);
      v = (v + 1) / 2;
      final len =
          (maxLen * (0.08 + 0.92 * v * energy)).clamp(3.0, maxLen);

      final shade = Color.lerp(
        palette[0],
        i / count < 0.5 ? palette[1] : palette[2],
        i / count,
      )!;

      final dir = Offset(math.cos(theta), math.sin(theta));
      final p1 = center + dir * inner;
      final p2 = center + dir * (inner + len);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = shade.withValues(alpha: 0.35 + 0.65 * energy),
      );
    }

    // Cincin tipis pemisah antara sampul dan batang.
    canvas.drawCircle(
      center,
      inner - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.18 + 0.2 * energy),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.t != t || old.energy != energy || old.seed != seed;
}
