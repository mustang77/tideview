import 'dart:math';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

/// Catur: papan penuh dengan aturan resmi (paket chess, port
/// chess.js). Dua mode: lawan komputer (langkah pintar sederhana:
/// utamakan skakmat/tangkapan, hindari blunder) atau 2 pemain
/// bergantian di satu HP. Promosi pion otomatis jadi ratu.
class CaturScreen extends StatefulWidget {
  const CaturScreen({super.key});

  @override
  State<CaturScreen> createState() => _CaturScreenState();
}

class _CaturScreenState extends State<CaturScreen> {
  final ch.Chess _game = ch.Chess();
  final _rnd = Random();
  bool _vsComputer = true;
  String? _selected;
  List<String> _targets = const [];
  String? _lastFrom;
  String? _lastTo;
  bool _thinking = false;

  static const _glyph = {
    'wk': '♔', 'wq': '♕', 'wr': '♖', 'wb': '♗', 'wn': '♘', 'wp': '♙',
    'bk': '♚', 'bq': '♛', 'br': '♜', 'bb': '♝', 'bn': '♞', 'bp': '♟',
  };

  static const _value = {'p': 1.0, 'n': 3.0, 'b': 3.2, 'r': 5.0, 'q': 9.0, 'k': 0.0};

  void _reset() {
    setState(() {
      _game.reset();
      _selected = null;
      _targets = const [];
      _lastFrom = null;
      _lastTo = null;
      _thinking = false;
    });
  }

  List<String> _legalTargets(String from) => [
        for (final m in _game.generate_moves())
          if (m.fromAlgebraic == from) m.toAlgebraic,
      ];

  void _tap(String square) {
    if (_game.game_over || _thinking) return;
    if (_vsComputer && _game.turn == ch.Color.BLACK) return;
    final piece = _game.get(square);
    if (_selected == null || (piece != null && piece.color == _game.turn)) {
      if (piece != null && piece.color == _game.turn) {
        setState(() {
          _selected = square;
          _targets = _legalTargets(square);
        });
      }
      return;
    }
    if (square == _selected) {
      setState(() {
        _selected = null;
        _targets = const [];
      });
      return;
    }
    if (_targets.contains(square)) {
      _game.move({'from': _selected!, 'to': square, 'promotion': 'q'});
      setState(() {
        _lastFrom = _selected;
        _lastTo = square;
        _selected = null;
        _targets = const [];
      });
      if (_vsComputer && !_game.game_over) _computerMove();
    }
  }

  Future<void> _computerMove() async {
    setState(() => _thinking = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _game.game_over) {
      if (mounted) setState(() => _thinking = false);
      return;
    }
    ch.Move? best;
    var bestScore = double.negativeInfinity;
    for (final m in _game.generate_moves()) {
      var s = _rnd.nextDouble() * 0.2;
      if (m.captured != null) s += _value[m.captured!.name] ?? 0;
      if (m.promotion != null) s += 8;
      _game.make_move(m);
      if (_game.in_checkmate) {
        s += 1000;
      } else if (_game.in_check) {
        s += 0.2;
      }
      // Hindari blunder: kurangi nilai tangkapan balasan terbaik lawan.
      var worst = 0.0;
      for (final r in _game.generate_moves()) {
        if (r.captured != null) {
          worst = max(worst, _value[r.captured!.name] ?? 0);
        }
      }
      s -= worst * 0.9;
      _game.undo_move();
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    if (best != null) {
      _game.make_move(best);
      _lastFrom = best.fromAlgebraic;
      _lastTo = best.toAlgebraic;
    }
    if (mounted) setState(() => _thinking = false);
  }

  void _undo() {
    if (_thinking) return;
    _game.undo_move();
    if (_vsComputer && _game.turn == ch.Color.BLACK) _game.undo_move();
    setState(() {
      _selected = null;
      _targets = const [];
      _lastFrom = null;
      _lastTo = null;
    });
  }

  String get _status {
    if (_game.in_checkmate) {
      final white = _game.turn == ch.Color.WHITE;
      if (_vsComputer) return white ? 'Skakmat — komputer menang 🤖' : 'Skakmat — kamu MENANG! 🏆';
      return white ? 'Skakmat — Hitam menang!' : 'Skakmat — Putih menang!';
    }
    if (_game.in_draw) return 'Remis (seri).';
    final turn = _game.turn == ch.Color.WHITE ? 'Putih' : 'Hitam';
    final cek = _game.in_check ? ' — SKAK!' : '';
    if (_thinking) return 'Komputer berpikir...';
    if (_vsComputer) return 'Giliranmu (Putih)$cek';
    return 'Giliran $turn$cek';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catur'),
        actions: [
          IconButton(
              tooltip: 'Batalkan langkah',
              onPressed: _undo,
              icon: const Icon(Icons.undo)),
          IconButton(
              tooltip: 'Ulang dari awal',
              onPressed: _reset,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.smart_toy_outlined),
                    label: Text('vs Komputer')),
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.people_outline),
                    label: Text('2 Pemain')),
              ],
              selected: {_vsComputer},
              onSelectionChanged: (v) {
                _vsComputer = v.first;
                _reset();
              },
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_status,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF7A5C3E), width: 4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        for (var rank = 8; rank >= 1; rank--)
                          Expanded(
                            child: Row(
                              children: [
                                for (var file = 0; file < 8; file++)
                                  Expanded(
                                      child: _square(
                                          '${'abcdefgh'[file]}$rank',
                                          (rank + file) % 2 == 0)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _square(String square, bool dark) {
    final piece = _game.get(square);
    final selected = square == _selected;
    final target = _targets.contains(square);
    final last = square == _lastFrom || square == _lastTo;
    final base = dark ? const Color(0xFFB58863) : const Color(0xFFF0D9B5);
    Color bg = base;
    if (last) bg = Color.alphaBlend(const Color(0x59FFD54F), base);
    if (selected) bg = Color.alphaBlend(const Color(0x8067C2FF), base);
    return GestureDetector(
      onTap: () => _tap(square),
      child: Container(
        color: bg,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (target && piece == null)
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0x8038761D),
                  shape: BoxShape.circle,
                ),
              ),
            if (target && piece != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xCCD32F2F), width: 3),
                  shape: BoxShape.circle,
                ),
              ),
            if (piece != null)
              FittedBox(
                child: Text(
                  _glyph['${piece.color == ch.Color.WHITE ? 'w' : 'b'}'
                      '${piece.type.name}']!,
                  style: TextStyle(
                    fontSize: 34,
                    height: 1,
                    color: piece.color == ch.Color.WHITE
                        ? Colors.white
                        : Colors.black,
                    shadows: const [
                      Shadow(color: Colors.black38, blurRadius: 2)
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
