import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:audioplayers/audioplayers.dart';

/// ────────────────────────────────────────────────────────────────────────
/// Biliar 8-Ball — vs simple AI, full 8-ball rules, aim line + power slider.
/// Pseudo-3D rendering (shaded spheres, beveled rails, shadows) in a
/// CustomPainter, plus synthesized sound (no asset files). Self-contained
/// physics in "world" units scaled to fit the widget.
/// ────────────────────────────────────────────────────────────────────────

/// Generates short WAV tones in memory and plays them via audioplayers.
/// No asset files needed — bytes are built at runtime.
class _SfxEngine {
  final AudioPlayer _cuePlayer = AudioPlayer();
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _pocketPlayer = AudioPlayer();

  Uint8List? _cueWav;
  Uint8List? _clickWav;
  Uint8List? _pocketWav;

  bool _ready = false;

  void init() {
    if (_ready) return;
    // Cue hit: short, punchy low knock.
    _cueWav = _makeTone(freq: 180, ms: 90, decay: 40, volume: 0.9,
        secondFreq: 90);
    // Ball click: brief high tick.
    _clickWav = _makeTone(freq: 900, ms: 45, decay: 18, volume: 0.7,
        secondFreq: 1400);
    // Pocket drop: descending thunk.
    _pocketWav = _makeTone(freq: 320, ms: 220, decay: 120, volume: 0.85,
        secondFreq: 120, slide: true);
    _ready = true;
  }

  Future<void> _play(AudioPlayer p, Uint8List? wav, {double volume = 1}) async {
    if (wav == null) return;
    try {
      await p.stop();
      await p.setVolume(volume.clamp(0.0, 1.0));
      await p.play(BytesSource(wav));
    } catch (_) {}
  }

  void cue({double volume = 1}) => _play(_cuePlayer, _cueWav, volume: volume);
  void click({double volume = 1}) =>
      _play(_clickPlayer, _clickWav, volume: volume);
  void pocket({double volume = 1}) =>
      _play(_pocketPlayer, _pocketWav, volume: volume);

  void dispose() {
    _cuePlayer.dispose();
    _clickPlayer.dispose();
    _pocketPlayer.dispose();
  }

  /// Builds a mono 16-bit PCM WAV as bytes: a decaying sine (optionally two
  /// mixed freqs, optionally sliding downward for the pocket sound).
  Uint8List _makeTone({
    required double freq,
    required int ms,
    required int decay,
    required double volume,
    double? secondFreq,
    bool slide = false,
  }) {
    const sampleRate = 22050;
    final n = (sampleRate * ms / 1000).round();
    final data = Int16List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final progress = i / n;
      // Exponential envelope.
      final env = exp(-i / (sampleRate * decay / 1000));
      var f = freq;
      if (slide) f = freq * (1 - progress * 0.6); // glide down
      var sample = sin(2 * pi * f * t);
      if (secondFreq != null) {
        var f2 = secondFreq;
        if (slide) f2 = secondFreq * (1 - progress * 0.6);
        sample = (sample + sin(2 * pi * f2 * t)) / 2;
      }
      final v = (sample * env * volume * 32767).clamp(-32768, 32767).toInt();
      data[i] = v;
    }
    return _wrapWav(data, sampleRate);
  }

  Uint8List _wrapWav(Int16List samples, int sampleRate) {
    final dataBytes = samples.buffer.asUint8List();
    final byteRate = sampleRate * 2; // mono, 16-bit
    final total = 44 + dataBytes.length;
    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
    void u32(int v) => b.add([
          v & 0xFF,
          (v >> 8) & 0xFF,
          (v >> 16) & 0xFF,
          (v >> 24) & 0xFF,
        ]);
    void u16(int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
    str('RIFF');
    u32(total - 8);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(byteRate);
    u16(2); // block align
    u16(16); // bits per sample
    str('data');
    u32(dataBytes.length);
    b.add(dataBytes);
    return b.toBytes();
  }
}

const double _tableW = 100; // world width  (portrait: narrow)
const double _tableH = 200; // world height (portrait: tall)
const double _ballR = 3.4; // ball radius
const double _pocketR = 5.4; // pocket capture radius
const double _friction = 0.986; // per-step velocity damping
const double _minSpeed = 0.02; // below this a ball is considered stopped
const double _restitution = 0.96; // ball-ball / cushion bounciness

enum _Group { none, solids, stripes }


class _Ball {
  double x, y, vx = 0, vy = 0;
  final int number; // 0 = cue, 1..7 solids, 8 = eight, 9..15 stripes
  bool pocketed = false;
  _Ball(this.x, this.y, this.number);

  bool get isCue => number == 0;
  bool get isEight => number == 8;
  _Group get group {
    if (number >= 1 && number <= 7) return _Group.solids;
    if (number >= 9 && number <= 15) return _Group.stripes;
    return _Group.none;
  }

  Color get color {
    if (isCue) return Colors.white;
    if (isEight) return Colors.black;
    const palette = {
      1: Color(0xFFF4C20D), // yellow
      2: Color(0xFF1565C0), // blue
      3: Color(0xFFD32F2F), // red
      4: Color(0xFF6A1B9A), // purple
      5: Color(0xFFEF6C00), // orange
      6: Color(0xFF2E7D32), // green
      7: Color(0xFF8D3B0F), // maroon
    };
    final base = number <= 8 ? number : number - 8;
    return palette[base] ?? Colors.grey;
  }
}

class BiliarScreen extends StatefulWidget {
  const BiliarScreen({super.key});
  @override
  State<BiliarScreen> createState() => _BiliarScreenState();
}

class _BiliarScreenState extends State<BiliarScreen>
    with SingleTickerProviderStateMixin {
  late List<_Ball> _balls;
  late Ticker _ticker;

  // Pockets (world coords): 4 corners + 2 side (on the long left/right edges).
  final List<Offset> _pockets = const [
    Offset(0, 0),
    Offset(_tableW, 0),
    Offset(-0.5, _tableH / 2),
    Offset(_tableW + 0.5, _tableH / 2),
    Offset(0, _tableH),
    Offset(_tableW, _tableH),
  ];

  // Turn / rules state.
  bool _playerTurn = true; // true = human, false = AI
  _Group _playerGroup = _Group.none;
  _Group _aiGroup = _Group.none;
  bool _groupsAssigned = false;
  bool _ballsMoving = false;
  String _status = 'Giliranmu — bidik dan tembak!';
  bool _gameOver = false;
  String _resultText = '';

  // Shot controls.
  double _aimAngle = 0; // radians
  double _power = 0.5; // 0..1

  // Foul / pocket tracking within a shot.
  final List<_Ball> _pocketedThisShot = [];
  bool _cueScratch = false;
  bool _firstHitLegal = false;
  bool _anyBallHit = false;

  // Sound.
  final _SfxEngine _sfx = _SfxEngine();

  @override
  void initState() {
    super.initState();
    _sfx.init();
    _rack();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sfx.dispose();
    super.dispose();
  }

  void _rack() {
    _balls = [];
    // Cue ball near the bottom "head spot".
    _balls.add(_Ball(_tableW / 2, _tableH * 0.75, 0));
    // Triangle rack around the "foot spot" toward the top; apex points up.
    final apexX = _tableW / 2;
    final apexY = _tableH * 0.28;
    final spacing = _ballR * 2 + 0.15;
    // Standard-ish 8-ball arrangement; 8 in the middle of row 3.
    final rackOrder = [
      [1],
      [9, 2],
      [3, 8, 10],
      [11, 4, 12, 5],
      [6, 13, 7, 14, 15],
    ];
    for (var row = 0; row < rackOrder.length; row++) {
      final cols = rackOrder[row];
      final rowY = apexY - row * (spacing * 0.87); // rows stack upward
      final startX = apexX - (cols.length - 1) * spacing / 2;
      for (var c = 0; c < cols.length; c++) {
        _balls.add(_Ball(startX + c * spacing, rowY, cols[c]));
      }
    }
    _playerTurn = true;
    _playerGroup = _Group.none;
    _aiGroup = _Group.none;
    _groupsAssigned = false;
    _gameOver = false;
    _resultText = '';
    _status = 'Giliranmu — bidik dan tembak!';
    _aimAngle = 0;
    _power = 0.5;
  }

  _Ball? get _cue {
    for (final b in _balls) {
      if (b.isCue && !b.pocketed) return b;
    }
    return null;
  }

  // ── Physics step ────────────────────────────────────────────────────────
  void _tick(Duration _) {
    if (!_ballsMoving) return;
    // Two sub-steps per frame for stability at higher speeds.
    for (var s = 0; s < 2; s++) {
      _stepPhysics();
    }
    // Check if everything has stopped.
    final moving = _balls.any((b) =>
        !b.pocketed && (b.vx.abs() > _minSpeed || b.vy.abs() > _minSpeed));
    if (!moving) {
      for (final b in _balls) {
        b.vx = 0;
        b.vy = 0;
      }
      _ballsMoving = false;
      _resolveShot();
    }
    setState(() {});
  }

  void _stepPhysics() {
    for (final b in _balls) {
      if (b.pocketed) continue;
      b.x += b.vx;
      b.y += b.vy;
      b.vx *= _friction;
      b.vy *= _friction;
      if (b.vx.abs() < _minSpeed) b.vx = 0;
      if (b.vy.abs() < _minSpeed) b.vy = 0;

      // Cushion collisions.
      if (b.x < _ballR) {
        b.x = _ballR;
        b.vx = -b.vx * _restitution;
      } else if (b.x > _tableW - _ballR) {
        b.x = _tableW - _ballR;
        b.vx = -b.vx * _restitution;
      }
      if (b.y < _ballR) {
        b.y = _ballR;
        b.vy = -b.vy * _restitution;
      } else if (b.y > _tableH - _ballR) {
        b.y = _tableH - _ballR;
        b.vy = -b.vy * _restitution;
      }
    }

    // Ball-ball collisions.
    for (var i = 0; i < _balls.length; i++) {
      final a = _balls[i];
      if (a.pocketed) continue;
      for (var j = i + 1; j < _balls.length; j++) {
        final c = _balls[j];
        if (c.pocketed) continue;
        final dx = c.x - a.x;
        final dy = c.y - a.y;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = _ballR * 2;
        if (dist > 0 && dist < minDist) {
          // Track first legal contact for the shooter.
          if (a.isCue || c.isCue) {
            final other = a.isCue ? c : a;
            if (!_anyBallHit) {
              _anyBallHit = true;
              _firstHitLegal = _isFirstHitLegal(other);
            }
          }
          // Resolve overlap.
          final nx = dx / dist;
          final ny = dy / dist;
          final overlap = (minDist - dist) / 2;
          a.x -= nx * overlap;
          a.y -= ny * overlap;
          c.x += nx * overlap;
          c.y += ny * overlap;
          // Elastic-ish response along the normal.
          final dvx = c.vx - a.vx;
          final dvy = c.vy - a.vy;
          final rel = dvx * nx + dvy * ny;
          if (rel < 0) {
            final imp = -rel * _restitution;
            a.vx -= imp * nx;
            a.vy -= imp * ny;
            c.vx += imp * nx;
            c.vy += imp * ny;
            // Click sound, louder for harder impacts.
            final vol = (imp / 4).clamp(0.15, 1.0);
            _sfx.click(volume: vol);
          }
        }
      }
    }

    // Pocket capture.
    for (final b in _balls) {
      if (b.pocketed) continue;
      for (final p in _pockets) {
        final dx = b.x - p.dx;
        final dy = b.y - p.dy;
        if (dx * dx + dy * dy < _pocketR * _pocketR) {
          b.pocketed = true;
          b.vx = 0;
          b.vy = 0;
          _pocketedThisShot.add(b);
          if (b.isCue) _cueScratch = true;
          _sfx.pocket();
          break;
        }
      }
    }
  }

  bool _isFirstHitLegal(_Ball first) {
    // Before groups are assigned, any object ball (except illegal 8-first) is
    // an open-table legal first contact.
    if (!_groupsAssigned) {
      return !first.isEight;
    }
    final myGroup = _playerTurn ? _playerGroup : _aiGroup;
    // If your group is cleared, you're on the 8-ball.
    if (_groupCleared(myGroup)) {
      return first.isEight;
    }
    return first.group == myGroup;
  }

  bool _groupCleared(_Group g) {
    if (g == _Group.none) return false;
    return !_balls.any((b) => !b.pocketed && b.group == g);
  }

  // ── Shot resolution / rules ──────────────────────────────────────────────
  void _resolveShot() {
    final shooterIsPlayer = _playerTurn;
    final potted = List<_Ball>.from(_pocketedThisShot);
    final pottedEight = potted.any((b) => b.isEight);
    final scratch = _cueScratch;

    // Assign groups on the first shot where an object ball is legally potted
    // and the table is still open.
    if (!_groupsAssigned && !scratch) {
      final objectPotted =
          potted.where((b) => !b.isCue && !b.isEight).toList();
      if (objectPotted.isNotEmpty) {
        // Group = the group of the first object ball potted.
        final g = objectPotted.first.group;
        if (g != _Group.none) {
          if (shooterIsPlayer) {
            _playerGroup = g;
            _aiGroup = g == _Group.solids ? _Group.stripes : _Group.solids;
          } else {
            _aiGroup = g;
            _playerGroup = g == _Group.solids ? _Group.stripes : _Group.solids;
          }
          _groupsAssigned = true;
        }
      }
    }

    // Handle 8-ball outcomes (win/lose).
    if (pottedEight) {
      final myGroup = shooterIsPlayer ? _playerGroup : _aiGroup;
      // ignore: unused_local_variable
      final clearedBeforeEight = _groupCleared(myGroup) || !_groupsAssigned;
      // You win only if your group was cleared AND you didn't scratch.
      final legalEight = _groupsAssigned && _groupCleared(myGroup) && !scratch;
      if (legalEight) {
        _endGame(shooterIsPlayer);
      } else {
        // Potting the 8 early or on a scratch = you lose.
        _endGame(!shooterIsPlayer);
      }
      _clearShotFlags();
      return;
    }

    // Determine if the shot was a foul.
    bool foul = false;
    String foulReason = '';
    if (scratch) {
      foul = true;
      foulReason = 'Scratch! Bola putih masuk.';
    } else if (!_anyBallHit) {
      foul = true;
      foulReason = 'Tidak ada bola yang tersentuh.';
    } else if (!_firstHitLegal) {
      foul = true;
      foulReason = 'Bola pertama yang disentuh salah.';
    }

    // Did the shooter legally pot at least one of their own balls?
    final myGroup = shooterIsPlayer ? _playerGroup : _aiGroup;
    final pottedOwn = potted.any((b) =>
        !b.isCue &&
        !b.isEight &&
        (!_groupsAssigned || b.group == myGroup));

    // Respawn cue ball if scratched.
    if (scratch) _respawnCue();

    // Continue turn if potted own ball and no foul; else pass turn.
    final keepTurn = pottedOwn && !foul;

    _clearShotFlags();

    if (_gameOver) return;

    setState(() {
      if (keepTurn) {
        _playerTurn = shooterIsPlayer;
        _status = shooterIsPlayer
            ? 'Bagus! Lanjut menembak.'
            : 'AI memasukkan bola, giliran AI lagi.';
      } else {
        _playerTurn = !shooterIsPlayer;
        if (foul) {
          _status = '$foulReason Giliran '
              '${_playerTurn ? "kamu" : "AI"}.';
        } else {
          _status = _playerTurn ? 'Giliranmu.' : 'Giliran AI.';
        }
      }
      _updateGroupStatus();
    });

    if (!_playerTurn && !_gameOver) {
      Future.delayed(const Duration(milliseconds: 700), _aiShoot);
    }
  }

  void _updateGroupStatus() {
    if (_groupsAssigned) {
      final me = _playerGroup == _Group.solids ? 'Solids (1-7)' : 'Stripes (9-15)';
      _status += '  •  Kamu: $me';
    }
  }

  void _clearShotFlags() {
    _pocketedThisShot.clear();
    _cueScratch = false;
    _firstHitLegal = false;
    _anyBallHit = false;
  }

  void _respawnCue() {
    // Place cue back near the bottom head spot; nudge if occupied.
    var cx = _tableW / 2;
    var cy = _tableH * 0.75;
    final cue = _balls.firstWhere((b) => b.isCue);
    cue.pocketed = false;
    cue.vx = 0;
    cue.vy = 0;
    var tries = 0;
    while (_overlapsAny(cx, cy, cue) && tries < 50) {
      cx -= _ballR * 2;
      if (cx < _ballR * 2) {
        cx = _tableW / 2;
        cy += _ballR * 2;
      }
      tries++;
    }
    cue.x = cx;
    cue.y = cy;
  }

  bool _overlapsAny(double x, double y, _Ball self) {
    for (final b in _balls) {
      if (b == self || b.pocketed) continue;
      final dx = b.x - x, dy = b.y - y;
      if (dx * dx + dy * dy < (_ballR * 2) * (_ballR * 2)) return true;
    }
    return false;
  }

  void _endGame(bool playerWon) {
    _gameOver = true;
    _resultText = playerWon ? '🎉 Kamu Menang!' : '😔 AI Menang';
    _status = _resultText;
  }

  // ── Shooting ─────────────────────────────────────────────────────────────
  void _shoot(double angle, double power01) {
    final cue = _cue;
    if (cue == null || _ballsMoving || _gameOver) return;
    _clearShotFlags();
    final speed = 1.2 + power01 * 5.5; // world units per step
    cue.vx = cos(angle) * speed;
    cue.vy = sin(angle) * speed;
    _sfx.cue(volume: (0.4 + power01 * 0.6).clamp(0.0, 1.0));
    _ballsMoving = true;
  }

  // Very simple AI: aim at the nearest legal target ball toward the nearest
  // pocket, with a little randomness.
  void _aiShoot() {
    if (_gameOver) return;
    final cue = _cue;
    if (cue == null) {
      _ballsMoving = false;
      return;
    }
    final rng = Random();
    // Candidate target balls.
    final myGroup = _aiGroup;
    List<_Ball> targets;
    if (!_groupsAssigned) {
      targets = _balls
          .where((b) => !b.pocketed && !b.isCue && !b.isEight)
          .toList();
    } else if (_groupCleared(myGroup)) {
      targets = _balls.where((b) => !b.pocketed && b.isEight).toList();
    } else {
      targets = _balls
          .where((b) => !b.pocketed && b.group == myGroup)
          .toList();
    }
    if (targets.isEmpty) {
      targets = _balls
          .where((b) => !b.pocketed && !b.isCue)
          .toList();
    }
    if (targets.isEmpty) {
      _ballsMoving = false;
      return;
    }

    // Pick the target+pocket pair giving the straightest cut.
    double bestAngle = 0;
    double bestScore = -1;
    double bestPower = 0.6;
    for (final t in targets) {
      for (final p in _pockets) {
        // Ghost-ball position: where cue must send the target from.
        final tpx = p.dx - t.x;
        final tpy = p.dy - t.y;
        final tpLen = sqrt(tpx * tpx + tpy * tpy);
        if (tpLen == 0) continue;
        final gx = t.x - tpx / tpLen * _ballR * 2;
        final gy = t.y - tpy / tpLen * _ballR * 2;
        final ax = gx - cue.x;
        final ay = gy - cue.y;
        final aLen = sqrt(ax * ax + ay * ay);
        if (aLen == 0) continue;
        // Straightness: dot of (cue->ghost) and (target->pocket) directions.
        final dot =
            (ax / aLen) * (tpx / tpLen) + (ay / aLen) * (tpy / tpLen);
        final score = dot - aLen * 0.002; // prefer straight + closer
        if (score > bestScore) {
          bestScore = score;
          bestAngle = atan2(ay, ax);
          bestPower = (0.45 + tpLen * 0.003 + aLen * 0.002).clamp(0.4, 0.95);
        }
      }
    }
    // Add small aiming error so the AI isn't perfect.
    bestAngle += (rng.nextDouble() - 0.5) * 0.08;
    _aimAngle = bestAngle;
    _power = bestPower;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 350),
        () => _shoot(bestAngle, bestPower));
  }

  // ── Aim interaction (drag to set angle) ──────────────────────────────────
  void _handleAimDrag(Offset localPos, Size widgetSize) {
    final cue = _cue;
    if (cue == null || _ballsMoving || !_playerTurn || _gameOver) return;
    // Convert widget position to world, compute angle from cue to touch.
    final scale = _scaleFor(widgetSize);
    final worldX = (localPos.dx - _originFor(widgetSize).dx) / scale;
    final worldY = (localPos.dy - _originFor(widgetSize).dy) / scale;
    final dx = worldX - cue.x;
    final dy = worldY - cue.y;
    if (dx == 0 && dy == 0) return;
    setState(() => _aimAngle = atan2(dy, dx));
  }

  double _scaleFor(Size s) {
    final sx = s.width / (_tableW + _ballR * 4);
    final sy = s.height / (_tableH + _ballR * 4);
    return min(sx, sy);
  }

  Offset _originFor(Size s) {
    final scale = _scaleFor(s);
    final drawW = (_tableW + _ballR * 4) * scale;
    final drawH = (_tableH + _ballR * 4) * scale;
    final ox = (s.width - drawW) / 2 + _ballR * 2 * scale;
    final oy = (s.height - drawH) / 2 + _ballR * 2 * scale;
    return Offset(ox, oy);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              // Table fills the whole screen.
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: (d) => _handleAimDrag(d.localPosition, size),
                  onTapDown: (d) => _handleAimDrag(d.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _TablePainter(
                      balls: _balls,
                      pockets: _pockets,
                      aimAngle: _aimAngle,
                      showAim: _playerTurn && !_ballsMoving && !_gameOver,
                      origin: _originFor(size),
                      scale: _scaleFor(size),
                    ),
                  ),
                ),
              ),

              // Top overlay: back + reset + status.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _roundIconButton(
                              icon: Icons.arrow_back,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            _roundIconButton(
                              icon: Icons.refresh,
                              onTap: () => setState(_rack),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom overlay: controls or game-over.
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _gameOver
                        ? _gameOverPanel()
                        : _controlPanel(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _gameOverPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_resultText,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(_rack),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Main Lagi',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 20, color: Colors.amber),
              const SizedBox(width: 6),
              const Text('Power',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              Expanded(
                child: Slider(
                  value: _power,
                  onChanged: (_playerTurn && !_ballsMoving)
                      ? (v) => setState(() => _power = v)
                      : null,
                ),
              ),
              Text('${(_power * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_playerTurn && !_ballsMoving && !_gameOver)
                  ? () => _shoot(_aimAngle, _power)
                  : null,
              icon: const Icon(Icons.sports_golf),
              label: Text(
                _ballsMoving
                    ? 'Menunggu bola berhenti...'
                    : (_playerTurn ? 'TEMBAK' : 'Giliran AI...'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TablePainter extends CustomPainter {
  final List<_Ball> balls;
  final List<Offset> pockets;
  final double aimAngle;
  final bool showAim;
  final Offset origin;
  final double scale;

  _TablePainter({
    required this.balls,
    required this.pockets,
    required this.aimAngle,
    required this.showAim,
    required this.origin,
    required this.scale,
  });

  Offset _w2s(double x, double y) =>
      Offset(origin.dx + x * scale, origin.dy + y * scale);

  @override
  void paint(Canvas canvas, Size size) {
    final r = _ballR * scale;

    // ── Rails: layered bevel (dark base, mid wood, top highlight) ──────────
    final outer = Rect.fromLTWH(
      origin.dx - _ballR * 2 * scale,
      origin.dy - _ballR * 2 * scale,
      (_tableW + _ballR * 4) * scale,
      (_tableH + _ballR * 4) * scale,
    );
    // Drop shadow under the whole table for a "sitting on surface" feel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          outer.inflate(10).shift(const Offset(0, 6)),
          const Radius.circular(18)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    // Base (darkest).
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.inflate(10), const Radius.circular(16)),
      Paint()..color = const Color(0xFF3A2410),
    );
    // Wood rail with vertical gradient.
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.inflate(6), const Radius.circular(12)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A4E22), Color(0xFF5D3A1A)],
        ).createShader(outer.inflate(6)),
    );
    // Thin top highlight on the rail.
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer.inflate(6), const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // ── Felt surface with a soft radial vignette (light from above) ────────
    final surface = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      _tableW * scale,
      _tableH * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(surface, const Radius.circular(4)),
      Paint()..color = const Color(0xFF0B6B3A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(surface, const Radius.circular(4)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.1,
          colors: [
            const Color(0xFF13894C).withValues(alpha: 0.9),
            const Color(0xFF063E22).withValues(alpha: 0.9),
          ],
        ).createShader(surface),
    );
    // Inner cushion shadow (felt looks recessed below the rails).
    canvas.drawRRect(
      RRect.fromRectAndRadius(surface, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 3),
    );

    // ── Pockets: recessed with a lighter rim ───────────────────────────────
    for (final p in pockets) {
      final c = _w2s(p.dx, p.dy);
      canvas.drawCircle(c, _pocketR * scale * 1.05,
          Paint()..color = const Color(0xFF2A1B0C)); // rim
      canvas.drawCircle(
        c,
        _pocketR * scale * 0.85,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.black, Colors.black.withValues(alpha: 0.7)],
          ).createShader(
              Rect.fromCircle(center: c, radius: _pocketR * scale)),
      );
    }

    _Ball? cue;
    for (final b in balls) {
      if (b.isCue && !b.pocketed) {
        cue = b;
        break;
      }
    }

    // ── Aim line + cue stick (during aiming) ───────────────────────────────
    if (showAim && cue != null) {
      final start = _w2s(cue.x, cue.y);
      final len = 60.0 * scale;
      final end = Offset(
        start.dx + cos(aimAngle) * len,
        start.dy + sin(aimAngle) * len,
      );
      // Dashed aim guide.
      final aimPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      const dash = 6.0;
      final total = (end - start).distance;
      final dir = (end - start) / total;
      var d = 0.0;
      while (d < total) {
        final s = start + dir * d;
        final e = start + dir * min(d + dash, total);
        canvas.drawLine(s, e, aimPaint);
        d += dash * 2;
      }
      // Cue stick behind the cue ball (opposite the aim direction).
      final back = Offset(
        start.dx - cos(aimAngle) * (r + 2),
        start.dy - sin(aimAngle) * (r + 2),
      );
      final tail = Offset(
        back.dx - cos(aimAngle) * 55 * scale,
        back.dy - sin(aimAngle) * 55 * scale,
      );
      // Stick shadow.
      canvas.drawLine(back.translate(1.5, 2.5), tail.translate(1.5, 2.5),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..strokeWidth = r * 0.5
            ..strokeCap = StrokeCap.round);
      // Stick body (wood gradient).
      canvas.drawLine(
        back,
        tail,
        Paint()
          ..shader = LinearGradient(
            colors: const [Color(0xFFE8C48A), Color(0xFF8A5A2B)],
          ).createShader(Rect.fromPoints(back, tail))
          ..strokeWidth = r * 0.45
          ..strokeCap = StrokeCap.round,
      );
      // Blue tip.
      canvas.drawCircle(back, r * 0.28,
          Paint()..color = const Color(0xFF2E6FB0));
    }

    // ── Balls: drop shadow + spherical radial shading + specular ───────────
    for (final b in balls) {
      if (b.pocketed) continue;
      final c = _w2s(b.x, b.y);

      // Contact shadow (offset down-right, blurred).
      canvas.drawCircle(
        c.translate(r * 0.35, r * 0.5),
        r * 0.98,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Base sphere with radial gradient (light from top-left).
      const lightCenter = Alignment(-0.45, -0.5);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: lightCenter,
            radius: 1.0,
            colors: [
              _lighten(b.color, 0.45),
              b.color,
              _darken(b.color, 0.35),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );

      // Stripe band for 9-15 (clipped, then re-shade lightly).
      if (b.number >= 9 && b.number <= 15) {
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
        final band =
            Rect.fromCenter(center: c, width: r * 2, height: r * 0.95);
        canvas.drawRect(band, Paint()..color = Colors.white);
        // Re-apply a light radial shadow over the whole ball to keep 3D look.
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              center: lightCenter,
              radius: 1.0,
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.28),
              ],
              stops: const [0.5, 1.0],
            ).createShader(Rect.fromCircle(center: c, radius: r)),
        );
        canvas.restore();
      }

      // Number badge (skip cue).
      if (!b.isCue) {
        canvas.drawCircle(c, r * 0.38,
            Paint()..color = Colors.white.withValues(alpha: 0.95));
        final tp = TextPainter(
          text: TextSpan(
            text: '${b.number}',
            style: TextStyle(
                color: Colors.black,
                fontSize: r * 0.5,
                fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      }

      // Specular highlight (glossy dot, top-left).
      canvas.drawCircle(
        c.translate(-r * 0.35, -r * 0.4),
        r * 0.22,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
  }

  Color _lighten(Color c, double amt) {
    return Color.lerp(c, Colors.white, amt) ?? c;
  }

  Color _darken(Color c, double amt) {
    return Color.lerp(c, Colors.black, amt) ?? c;
  }

  @override
  bool shouldRepaint(covariant _TablePainter old) => true;
}
