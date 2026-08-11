import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';

/// ════════════════════════════════════════════════════════════════════════
/// Ular Tangga — kamu vs 1 AI. Papan 10×10, dadu, ular & tangga, token
/// beranimasi. Bahasa Indonesia, suara sintetis (tanpa file aset).
/// Self-contained: satu file, hanya butuh audioplayers.
/// ════════════════════════════════════════════════════════════════════════

// ── Suara sintetis (WAV di memori) ────────────────────────────────────────
class _SnakeSfx {
  final AudioPlayer _dice = AudioPlayer();
  final AudioPlayer _step = AudioPlayer();
  final AudioPlayer _slide = AudioPlayer(); // ular (turun)
  final AudioPlayer _climb = AudioPlayer(); // tangga (naik)
  final AudioPlayer _win = AudioPlayer();
  Uint8List? _diceW, _stepW, _slideW, _climbW, _winW;
  bool _ready = false;

  void init() {
    if (_ready) return;
    _diceW = _tone(freq: 220, ms: 90, decay: 40, vol: 0.7, second: 330);
    _stepW = _tone(freq: 600, ms: 40, decay: 16, vol: 0.5, second: 900);
    _slideW = _tone(freq: 500, ms: 260, decay: 150, vol: 0.7, slideDown: true);
    _climbW = _tone(freq: 300, ms: 260, decay: 150, vol: 0.7, slideUp: true);
    _winW = _tone(freq: 523, ms: 300, decay: 180, vol: 0.8, second: 784);
    _ready = true;
  }

  Future<void> _play(AudioPlayer p, Uint8List? w, double v) async {
    if (w == null) return;
    try {
      await p.stop();
      await p.setVolume(v.clamp(0.0, 1.0));
      await p.play(BytesSource(w));
    } catch (_) {}
  }

  void dice() => _play(_dice, _diceW, 0.8);
  void step() => _play(_step, _stepW, 0.5);
  void slide() => _play(_slide, _slideW, 0.8);
  void climb() => _play(_climb, _climbW, 0.8);
  void win() => _play(_win, _winW, 0.9);

  void dispose() {
    _dice.dispose();
    _step.dispose();
    _slide.dispose();
    _climb.dispose();
    _win.dispose();
  }

  Uint8List _tone({
    required double freq,
    required int ms,
    required int decay,
    required double vol,
    double? second,
    bool slideUp = false,
    bool slideDown = false,
  }) {
    const sr = 22050;
    final n = (sr * ms / 1000).round();
    final data = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final prog = i / n;
      final env = exp(-i / (sr * decay / 1000));
      var f = freq;
      if (slideUp) f = freq * (1 + prog * 0.8);
      if (slideDown) f = freq * (1 - prog * 0.5);
      var s = sin(2 * pi * f * t);
      if (second != null) s = (s + sin(2 * pi * second * t)) / 2;
      data[i] = (s * env * vol * 32767).clamp(-32768, 32767).toInt();
    }
    final bytes = data.buffer.asUint8List();
    final b = BytesBuilder();
    void str(String x) => b.add(x.codeUnits);
    void u32(int v) =>
        b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
    str('RIFF');
    u32(36 + bytes.length);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(sr);
    u32(sr * 2);
    u16(2);
    u16(16);
    str('data');
    u32(bytes.length);
    b.add(bytes);
    return b.toBytes();
  }
}

// Snakes (ular): head -> tail (turun). Ladders (tangga): bottom -> top (naik).
const Map<int, int> _snakes = {
  16: 6,
  47: 26,
  49: 11,
  56: 53,
  62: 19,
  64: 60,
  87: 24,
  93: 73,
  95: 75,
  98: 78,
};
const Map<int, int> _ladders = {
  1: 38,
  4: 14,
  9: 31,
  21: 42,
  28: 84,
  36: 44,
  51: 67,
  71: 91,
  80: 100,
};

class UlarTanggaScreen extends StatefulWidget {
  const UlarTanggaScreen({super.key});
  @override
  State<UlarTanggaScreen> createState() => _UlarTanggaScreenState();
}

class _UlarTanggaScreenState extends State<UlarTanggaScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  final _SnakeSfx _sfx = _SnakeSfx();
  late Ticker _ticker;

  // Posisi pemain (1..100). 0 = belum masuk papan (mulai dari luar).
  int _playerPos = 0;
  int _aiPos = 0;
  bool _playerTurn = true;
  int _dice = 1;
  bool _rolling = false; // animasi dadu
  bool _moving = false; // token sedang bergerak
  bool _gameOver = false;
  String _status = 'Giliranmu — lempar dadu!';
  // ignore: unused_field
  String? _winner;

  // Animasi langkah token.
  int _movingWho = 0; // 1 = player, 2 = ai
  final List<int> _pathQueue = []; // sisa kotak yang harus dilewati
  double _diceSpinT = 0;

  @override
  void initState() {
    super.initState();
    _sfx.init();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sfx.dispose();
    super.dispose();
  }

  double _stepAccum = 0;
  void _onTick(Duration elapsed) {
    if (_rolling) {
      _diceSpinT += 0.016;
      if (_diceSpinT < 0.6) {
        // Ganti angka dadu tiap frame untuk efek berputar.
        setState(() => _dice = 1 + _rng.nextInt(6));
      } else {
        _rolling = false;
        _diceSpinT = 0;
        _finishRoll();
      }
      return;
    }
    if (_moving) {
      _stepAccum += 0.016;
      if (_stepAccum >= 0.18) {
        _stepAccum = 0;
        _advanceOneStep();
      }
    }
  }

  void _rollDice() {
    if (_rolling || _moving || _gameOver || !_playerTurn) return;
    _startRoll();
  }

  void _startRoll() {
    _sfx.dice();
    setState(() {
      _rolling = true;
      _diceSpinT = 0;
    });
  }

  void _finishRoll() {
    final value = 1 + _rng.nextInt(6);
    setState(() => _dice = value);
    _beginMove(value);
  }

  void _beginMove(int steps) {
    final who = _playerTurn ? 1 : 2;
    _movingWho = who;
    final from = who == 1 ? _playerPos : _aiPos;
    var target = from + steps;
    // Harus mendarat tepat di 100; jika lebih, pantul mundur.
    if (target > 100) {
      final over = target - 100;
      target = 100 - over;
    }
    _pathQueue.clear();
    if (target >= from) {
      for (var p = from + 1; p <= target; p++) {
        _pathQueue.add(p);
      }
    } else {
      // Pantulan mundur dari 100.
      for (var p = from + 1; p <= 100; p++) {
        _pathQueue.add(p);
      }
      for (var p = 99; p >= target; p--) {
        _pathQueue.add(p);
      }
    }
    setState(() {
      _moving = true;
      _stepAccum = 0;
      _status = who == 1 ? 'Kamu melangkah...' : 'AI melangkah...';
    });
  }

  void _advanceOneStep() {
    if (_pathQueue.isEmpty) {
      _finishMove();
      return;
    }
    final next = _pathQueue.removeAt(0);
    _sfx.step();
    setState(() {
      if (_movingWho == 1) {
        _playerPos = next;
      } else {
        _aiPos = next;
      }
    });
  }

  void _finishMove() {
    _moving = false;
    final who = _movingWho;
    var pos = who == 1 ? _playerPos : _aiPos;
    final name = who == 1 ? 'Kamu' : 'AI';

    // Cek ular / tangga.
    if (_ladders.containsKey(pos)) {
      final top = _ladders[pos]!;
      _sfx.climb();
      pos = top;
      if (who == 1) {
        _playerPos = pos;
      } else {
        _aiPos = pos;
      }
      _status = '$name naik tangga ke $pos! 🪜';
    } else if (_snakes.containsKey(pos)) {
      final tail = _snakes[pos]!;
      _sfx.slide();
      pos = tail;
      if (who == 1) {
        _playerPos = pos;
      } else {
        _aiPos = pos;
      }
      _status = '$name kena ular, turun ke $pos! 🐍';
    }

    // Menang?
    if (pos == 100) {
      _sfx.win();
      setState(() {
        _gameOver = true;
        _winner = name;
        _status = who == 1 ? '🎉 Kamu Menang!' : '😔 AI Menang';
      });
      return;
    }

    // Lempar 6 = jalan lagi. Kalau tidak, giliran berganti.
    final rolledSix = _dice == 6;
    final wasPlayer = who == 1;
    setState(() {
      if (rolledSix) {
        _playerTurn = wasPlayer; // pemain yang sama jalan lagi
        _status = '$name dapat 6, jalan lagi!';
      } else {
        _playerTurn = !wasPlayer;
        _status = _playerTurn ? 'Giliranmu — lempar dadu!' : 'Giliran AI...';
      }
    });

    // Kalau sekarang giliran AI (baik karena berganti, atau AI dapat 6), jalankan AI.
    if (!_gameOver && !_playerTurn) {
      Future.delayed(const Duration(milliseconds: 800), _aiRoll);
    }
  }

  void _aiRoll() {
    if (_gameOver || _playerTurn) return;
    _sfx.dice();
    setState(() {
      _rolling = true;
      _diceSpinT = 0;
    });
  }

  void _reset() {
    setState(() {
      _playerPos = 0;
      _aiPos = 0;
      _playerTurn = true;
      _dice = 1;
      _rolling = false;
      _moving = false;
      _gameOver = false;
      _winner = null;
      _pathQueue.clear();
      _status = 'Giliranmu — lempar dadu!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102027),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A181D),
        foregroundColor: Colors.white,
        title: const Text('Ular Tangga'),
        actions: [
          IconButton(
            tooltip: 'Ulangi',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black.withValues(alpha: 0.3),
              child: Text(_status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            // Board.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _BoardPainter(
                      playerPos: _playerPos,
                      aiPos: _aiPos,
                    ),
                  ),
                ),
              ),
            ),
            // Bottom: player chips + dice + roll button.
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _playerBadge('Kamu', const Color(0xFF2196F3), _playerPos,
                  active: _playerTurn && !_gameOver),
              _diceWidget(),
              _playerBadge('AI', const Color(0xFFE53935), _aiPos,
                  active: !_playerTurn && !_gameOver),
            ],
          ),
          const SizedBox(height: 12),
          if (_gameOver)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.replay),
                label: const Text('Main Lagi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_playerTurn && !_rolling && !_moving)
                    ? _rollDice
                    : null,
                icon: const Icon(Icons.casino),
                label: Text(
                  _playerTurn
                      ? (_rolling
                          ? 'Melempar...'
                          : (_moving ? 'Bergerak...' : 'LEMPAR DADU'))
                      : 'Giliran AI...',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playerBadge(String name, Color color, int pos, {required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active ? color : Colors.white24, width: active ? 2 : 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(pos == 0 ? 'Start' : 'Kotak $pos',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _diceWidget() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(1, 2)),
        ],
      ),
      child: CustomPaint(painter: _DicePainter(_dice)),
    );
  }
}

// ── Papan ──────────────────────────────────────────────────────────────────
class _BoardPainter extends CustomPainter {
  final int playerPos;
  final int aiPos;
  _BoardPainter({required this.playerPos, required this.aiPos});

  // Kotak 1..100 dalam pola boustrophedon (zig-zag), 1 di kiri-bawah.
  Offset _cellCenter(int n, double cell) {
    final idx = n - 1;
    final row = idx ~/ 10; // 0 di bawah
    var col = idx % 10;
    if (row % 2 == 1) col = 9 - col; // baris ganjil dibalik
    final x = col * cell + cell / 2;
    final yFromBottom = row * cell + cell / 2;
    return Offset(x, yFromBottom); // y dari bawah; dibalik saat menggambar
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 10;
    final h = size.height;

    // Kotak papan warna selang-seling.
    for (var n = 1; n <= 100; n++) {
      final c = _cellCenter(n, cell);
      final rect = Rect.fromCenter(
        center: Offset(c.dx, h - c.dy),
        width: cell,
        height: cell,
      );
      final even = (n % 2 == 0);
      canvas.drawRect(
          rect,
          Paint()
            ..color = even
                ? const Color(0xFF1B4B52)
                : const Color(0xFF226068));
      canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5
            ..color = Colors.white24);
      // Nomor kotak.
      final tp = TextPainter(
        text: TextSpan(
            text: '$n',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: cell * 0.22,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(rect.left + 3, rect.top + 2));
    }

    // Tangga (garis hijau tebal dengan anak tangga).
    _ladders.forEach((bottom, top) {
      final a = _cellCenter(bottom, cell);
      final b = _cellCenter(top, cell);
      _drawLadder(canvas, Offset(a.dx, h - a.dy), Offset(b.dx, h - b.dy),
          cell);
    });

    // Ular (garis melengkung merah/oranye dengan kepala).
    _snakes.forEach((head, tail) {
      final a = _cellCenter(head, cell);
      final b = _cellCenter(tail, cell);
      _drawSnake(canvas, Offset(a.dx, h - a.dy), Offset(b.dx, h - b.dy),
          cell);
    });

    // Token pemain.
    _drawToken(canvas, playerPos, cell, h, const Color(0xFF2196F3), -0.22);
    _drawToken(canvas, aiPos, cell, h, const Color(0xFFE53935), 0.22);
  }

  void _drawLadder(Canvas canvas, Offset a, Offset b, double cell) {
    final dir = (b - a);
    final len = dir.distance;
    if (len == 0) return;
    final norm = Offset(-dir.dy / len, dir.dx / len);
    final railGap = cell * 0.16;
    final r1a = a + norm * railGap;
    final r1b = b + norm * railGap;
    final r2a = a - norm * railGap;
    final r2b = b - norm * railGap;
    final rail = Paint()
      ..color = const Color(0xFF6D4C1B)
      ..strokeWidth = cell * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(r1a, r1b, rail);
    canvas.drawLine(r2a, r2b, rail);
    // Anak tangga.
    final rungs = (len / (cell * 0.5)).round().clamp(2, 20);
    final rungPaint = Paint()
      ..color = const Color(0xFF9C6B2E)
      ..strokeWidth = cell * 0.05;
    for (var i = 1; i < rungs; i++) {
      final t = i / rungs;
      final p1 = Offset.lerp(r1a, r1b, t)!;
      final p2 = Offset.lerp(r2a, r2b, t)!;
      canvas.drawLine(p1, p2, rungPaint);
    }
  }

  void _drawSnake(Canvas canvas, Offset head, Offset tail, double cell) {
    final paint = Paint()
      ..color = const Color(0xFFEF5350)
      ..strokeWidth = cell * 0.22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Kurva sinus antara head & tail agar terlihat berkelok.
    final path = Path()..moveTo(head.dx, head.dy);
    final dir = tail - head;
    final len = dir.distance;
    final norm = len == 0 ? const Offset(0, 0) : Offset(-dir.dy / len, dir.dx / len);
    const seg = 12;
    for (var i = 1; i <= seg; i++) {
      final t = i / seg;
      final base = Offset.lerp(head, tail, t)!;
      final wave = sin(t * pi * 2) * cell * 0.28;
      final p = base + norm * wave;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
    // Kepala ular.
    canvas.drawCircle(head, cell * 0.16, Paint()..color = const Color(0xFFC62828));
    // Mata.
    canvas.drawCircle(head.translate(-cell * 0.05, -cell * 0.04),
        cell * 0.035, Paint()..color = Colors.white);
    canvas.drawCircle(head.translate(cell * 0.05, -cell * 0.04),
        cell * 0.035, Paint()..color = Colors.white);
  }

  void _drawToken(Canvas canvas, int pos, double cell, double h, Color color,
      double offsetFrac) {
    if (pos < 1) {
      // Belum masuk papan (posisi 0) — token belum digambar.
      return;
    }
    final center0 = _cellCenter(pos, cell);
    final center = Offset(center0.dx + cell * offsetFrac, h - center0.dy);
    // Bayangan.
    canvas.drawCircle(center.translate(1, 2), cell * 0.24,
        Paint()..color = Colors.black.withValues(alpha: 0.4));
    // Token.
    canvas.drawCircle(center, cell * 0.24,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [
              Color.lerp(color, Colors.white, 0.5)!,
              color,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: cell * 0.24)));
    canvas.drawCircle(center, cell * 0.24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.playerPos != playerPos || old.aiPos != aiPos;
}

// ── Dadu ─────────────────────────────────────────────────────────────────
class _DicePainter extends CustomPainter {
  final int value;
  _DicePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dot = Paint()..color = const Color(0xFF102027);
    final r = w * 0.09;
    Offset p(double fx, double fy) => Offset(w * fx, h * fy);
    void d(double fx, double fy) => canvas.drawCircle(p(fx, fy), r, dot);

    switch (value) {
      case 1:
        d(0.5, 0.5);
        break;
      case 2:
        d(0.3, 0.3);
        d(0.7, 0.7);
        break;
      case 3:
        d(0.28, 0.28);
        d(0.5, 0.5);
        d(0.72, 0.72);
        break;
      case 4:
        d(0.3, 0.3);
        d(0.7, 0.3);
        d(0.3, 0.7);
        d(0.7, 0.7);
        break;
      case 5:
        d(0.3, 0.3);
        d(0.7, 0.3);
        d(0.5, 0.5);
        d(0.3, 0.7);
        d(0.7, 0.7);
        break;
      case 6:
        d(0.32, 0.28);
        d(0.68, 0.28);
        d(0.32, 0.5);
        d(0.68, 0.5);
        d(0.32, 0.72);
        d(0.68, 0.72);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter old) => old.value != value;
}
