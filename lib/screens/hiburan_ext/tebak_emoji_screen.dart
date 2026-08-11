import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One emoji-vocabulary item: an emoji + its English word.
class EmojiItem {
  final String emoji;
  final String word;
  const EmojiItem(this.emoji, this.word);
}

/// One themed round of Tebak Emoji.
class _ERound {
  final String title;
  final String subtitle;
  final String badge; // small emoji shown on the round tile
  final List<EmojiItem> items;
  const _ERound(this.title, this.subtitle, this.badge, this.items);
}

/// 10 themed rounds, 10 emojis each. Answer choices are generated from the
/// round's own pool so the wrong options stay on-theme. Pass 80% to unlock.
// ignore: library_private_types_in_public_api
const List<_ERound> emojiRounds = [
  _ERound('Ship & Sea', 'Kapal & laut', '🚢', [
    EmojiItem('🚢', 'Ship'),
    EmojiItem('⚓', 'Anchor'),
    EmojiItem('🌊', 'Sea'),
    EmojiItem('🛟', 'Life buoy'),
    EmojiItem('🚤', 'Speedboat'),
    EmojiItem('⛵', 'Sailboat'),
    EmojiItem('🧭', 'Compass'),
    EmojiItem('🗺️', 'Map'),
    EmojiItem('🏝️', 'Island'),
    EmojiItem('🌅', 'Sunrise'),
  ]),
  _ERound('Crew & People', 'Awak & orang', '🧑‍✈️', [
    EmojiItem('🧑‍✈️', 'Captain'),
    EmojiItem('👨‍🍳', 'Chef'),
    EmojiItem('👮', 'Officer'),
    EmojiItem('🧑‍🔧', 'Engineer'),
    EmojiItem('💁', 'Receptionist'),
    EmojiItem('🧑‍🎤', 'Singer'),
    EmojiItem('👥', 'Crew'),
    EmojiItem('🙋', 'Guest'),
    EmojiItem('👋', 'Welcome'),
    EmojiItem('🤝', 'Handshake'),
  ]),
  _ERound('Cabin & Housekeeping', 'Kabin & tata graha', '🛏️', [
    EmojiItem('🛏️', 'Bed'),
    EmojiItem('🧴', 'Shampoo'),
    EmojiItem('🧹', 'Broom'),
    EmojiItem('🧺', 'Laundry'),
    EmojiItem('🧼', 'Soap'),
    EmojiItem('🪣', 'Bucket'),
    EmojiItem('🧻', 'Tissue'),
    EmojiItem('🛁', 'Bathtub'),
    EmojiItem('🚿', 'Shower'),
    EmojiItem('🪟', 'Window'),
  ]),
  _ERound('Food & Drink', 'Makanan & minuman', '🍽️', [
    EmojiItem('🍽️', 'Restaurant'),
    EmojiItem('🍹', 'Cocktail'),
    EmojiItem('☕', 'Coffee'),
    EmojiItem('🍷', 'Wine'),
    EmojiItem('🍞', 'Bread'),
    EmojiItem('🥗', 'Salad'),
    EmojiItem('🍰', 'Cake'),
    EmojiItem('🍜', 'Noodles'),
    EmojiItem('🥤', 'Soda'),
    EmojiItem('🍴', 'Cutlery'),
  ]),
  _ERound('Kitchen & Galley', 'Dapur', '🍳', [
    EmojiItem('🍳', 'Kitchen'),
    EmojiItem('🔪', 'Knife'),
    EmojiItem('🥄', 'Spoon'),
    EmojiItem('🍽️', 'Plate'),
    EmojiItem('🧊', 'Ice'),
    EmojiItem('🔥', 'Fire'),
    EmojiItem('🥘', 'Pan'),
    EmojiItem('🧂', 'Salt'),
    EmojiItem('🫕', 'Pot'),
    EmojiItem('🧑‍🍳', 'Cook'),
  ]),
  _ERound('Travel & Documents', 'Perjalanan & dokumen', '🧳', [
    EmojiItem('🧳', 'Luggage'),
    EmojiItem('📖', 'Passport'),
    EmojiItem('🎫', 'Ticket'),
    EmojiItem('✈️', 'Airplane'),
    EmojiItem('🚕', 'Taxi'),
    EmojiItem('🏨', 'Hotel'),
    EmojiItem('💳', 'Card'),
    EmojiItem('💵', 'Money'),
    EmojiItem('📷', 'Camera'),
    EmojiItem('🎒', 'Backpack'),
  ]),
  _ERound('Safety & Emergency', 'Keselamatan & darurat', '🦺', [
    EmojiItem('🦺', 'Life jacket'),
    EmojiItem('🚨', 'Alarm'),
    EmojiItem('🧯', 'Extinguisher'),
    EmojiItem('🚪', 'Exit'),
    EmojiItem('⚠️', 'Warning'),
    EmojiItem('🩹', 'Bandage'),
    EmojiItem('🆘', 'Help'),
    EmojiItem('🔦', 'Flashlight'),
    EmojiItem('🚑', 'Ambulance'),
    EmojiItem('⛑️', 'Helmet'),
  ]),
  _ERound('Entertainment & Leisure', 'Hiburan', '🎤', [
    EmojiItem('🎤', 'Microphone'),
    EmojiItem('🎸', 'Guitar'),
    EmojiItem('🎬', 'Movie'),
    EmojiItem('🎮', 'Game'),
    EmojiItem('🏊', 'Swimming'),
    EmojiItem('🎯', 'Target'),
    EmojiItem('🎲', 'Dice'),
    EmojiItem('💃', 'Dance'),
    EmojiItem('🎹', 'Piano'),
    EmojiItem('🃏', 'Card game'),
  ]),
  _ERound('Weather & Nature', 'Cuaca & alam', '🌤️', [
    EmojiItem('🌤️', 'Sunny'),
    EmojiItem('🌧️', 'Rain'),
    EmojiItem('⛈️', 'Storm'),
    EmojiItem('🌫️', 'Fog'),
    EmojiItem('🌈', 'Rainbow'),
    EmojiItem('❄️', 'Snow'),
    EmojiItem('💨', 'Wind'),
    EmojiItem('🌙', 'Moon'),
    EmojiItem('⭐', 'Star'),
    EmojiItem('🌡️', 'Temperature'),
  ]),
  _ERound('Service & Amenities — Expert', 'Layanan & fasilitas', '🛎️', [
    EmojiItem('🛎️', 'Bell'),
    EmojiItem('🔑', 'Key'),
    EmojiItem('🧾', 'Receipt'),
    EmojiItem('📞', 'Telephone'),
    EmojiItem('🛗', 'Elevator'),
    EmojiItem('💈', 'Barber'),
    EmojiItem('💆', 'Massage'),
    EmojiItem('🧖', 'Spa'),
    EmojiItem('🛍️', 'Shopping'),
    EmojiItem('🪪', 'ID card'),
  ]),
];

const int _ePassPercent = 80;

/// Entry screen: round-select map for Tebak Emoji.
class TebakEmojiScreen extends StatefulWidget {
  const TebakEmojiScreen({super.key});

  @override
  State<TebakEmojiScreen> createState() => _TebakEmojiScreenState();
}

class _TebakEmojiScreenState extends State<TebakEmojiScreen> {
  static const String _unlockedKey = 'emoji_unlocked';
  static const String _bestPrefix = 'emoji_best_';

  int _unlocked = 0;
  final Map<int, int> _best = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final unlocked = prefs.getInt(_unlockedKey) ?? 0;
    final best = <int, int>{};
    for (var i = 0; i < emojiRounds.length; i++) {
      final b = prefs.getInt('$_bestPrefix$i');
      if (b != null) best[i] = b;
    }
    if (!mounted) return;
    setState(() {
      _unlocked = unlocked;
      _best
        ..clear()
        ..addAll(best);
      _loading = false;
    });
  }

  Future<void> _openRound(int index) async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _EmojiRoundScreen(
          roundIndex: index,
          round: emojiRounds[index],
        ),
      ),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      final prevBest = prefs.getInt('$_bestPrefix$index') ?? 0;
      if (result > prevBest) {
        await prefs.setInt('$_bestPrefix$index', result);
      }
      final pct = (result / emojiRounds[index].items.length * 100).round();
      if (pct >= _ePassPercent && index == _unlocked &&
          index + 1 < emojiRounds.length) {
        await prefs.setInt(_unlockedKey, index + 1);
      }
    }
    _load();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Progress?'),
        content: const Text(
            'This will lock all rounds except Round 1 and clear best scores.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unlockedKey, 0);
      for (var i = 0; i < emojiRounds.length; i++) {
        await prefs.remove('$_bestPrefix$i');
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = _best.entries
        .where((e) =>
            (e.value / emojiRounds[e.key].items.length * 100).round() >=
            _ePassPercent)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tebak Emoji'),
        actions: [
          IconButton(
            tooltip: 'Reset progress',
            onPressed: _confirmReset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emoji → English',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                            '$completed / ${emojiRounds.length} rounds passed · '
                            'score $_ePassPercent%+ to unlock the next',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                            value: completed / emojiRounds.length),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _roundTile(cs, i),
                      childCount: emojiRounds.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _roundTile(ColorScheme cs, int i) {
    final round = emojiRounds[i];
    final locked = i > _unlocked;
    final best = _best[i];
    final total = round.items.length;
    final passed =
        best != null && (best / total * 100).round() >= _ePassPercent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: locked
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: locked
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Pass Round $i with $_ePassPercent%+ to unlock this.')),
                  );
                }
              : () => _openRound(i),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: locked
                          ? [Colors.grey.shade600, Colors.grey.shade800]
                          : const [Color(0xFFFF6CAB), Color(0xFF7366FF)],
                    ),
                  ),
                  child: Center(
                    child: locked
                        ? const Icon(Icons.lock, color: Colors.white70)
                        : Text(round.badge,
                            style: const TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Round ${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant)),
                          if (passed) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                size: 15, color: Colors.green),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(round.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  locked ? cs.onSurfaceVariant : cs.onSurface)),
                      Text(round.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (locked)
                  const Icon(Icons.lock_outline, color: Colors.grey)
                else if (best != null)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$best/$total',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('best',
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant)),
                    ],
                  )
                else
                  const Icon(Icons.play_circle_fill,
                      color: Color(0xFFFF6CAB), size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays a single round. Choices are drawn from the round's own item pool.
/// Pops with the score achieved.
class _EmojiRoundScreen extends StatefulWidget {
  final int roundIndex;
  final _ERound round;
  const _EmojiRoundScreen({required this.roundIndex, required this.round});

  @override
  State<_EmojiRoundScreen> createState() => _EmojiRoundScreenState();
}

class _EmojiRoundScreenState extends State<_EmojiRoundScreen> {
  final _tts = FlutterTts();
  final _rng = Random();

  late List<EmojiItem> _deck;
  int _index = 0;
  int _score = 0;
  bool _finished = false;

  late List<EmojiItem> _choices;
  int? _picked;
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    _deck = List<EmojiItem>.from(widget.round.items)..shuffle(_rng);
    _index = 0;
    _score = 0;
    _finished = false;
    _buildChoices();
  }

  void _buildChoices() {
    _picked = null;
    final correct = _deck[_index];
    // Wrong options come from the round pool first; if the round is small,
    // fall back to all rounds so we always have 3 distractors.
    final pool = <EmojiItem>[
      ...widget.round.items.where((v) => v.word != correct.word),
    ]..shuffle(_rng);
    final fallback = <EmojiItem>[
      for (final r in emojiRounds) ...r.items,
    ].where((v) => v.word != correct.word).toList()
      ..shuffle(_rng);
    final distractors = <EmojiItem>[];
    final seen = <String>{correct.word};
    for (final v in [...pool, ...fallback]) {
      if (distractors.length >= 3) break;
      if (seen.add(v.word)) distractors.add(v);
    }
    final opts = [correct, ...distractors]..shuffle(_rng);
    _choices = opts;
    _correctIndex = opts.indexWhere((v) => v.word == correct.word);
    _speak(correct.word);
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.4);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _pick(int i) {
    if (_picked != null) return;
    setState(() {
      _picked = i;
      if (i == _correctIndex) _score++;
    });
  }

  void _next() {
    if (_index + 1 >= _deck.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _index++;
        _buildChoices();
      });
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('R${widget.roundIndex + 1} · ${widget.round.title}'),
      ),
      body: SafeArea(child: _finished ? _result() : _question()),
    );
  }

  Widget _question() {
    final item = _deck[_index];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Soal ${_index + 1}/${_deck.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('Skor: $_score',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(item.emoji,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 96)),
                  const SizedBox(height: 6),
                  const Text('Apa Bahasa Inggrisnya?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 20),
                  ...List.generate(_choices.length, (i) {
                    Color? bg;
                    Color? fg;
                    if (_picked != null) {
                      if (i == _correctIndex) {
                        bg = Colors.green;
                        fg = Colors.white;
                      } else if (i == _picked) {
                        bg = Colors.red;
                        fg = Colors.white;
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: bg ?? Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _pick(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_choices[i].word,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: fg ?? Colors.black87)),
                                ),
                                if (_picked != null && i == _correctIndex)
                                  const Icon(Icons.check_circle,
                                      color: Colors.white),
                                if (_picked != null &&
                                    i == _picked &&
                                    i != _correctIndex)
                                  const Icon(Icons.cancel, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (_picked != null)
            FilledButton(
              onPressed: _next,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(
                  _index + 1 >= _deck.length ? 'Lihat Hasil' : 'Lanjut',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _result() {
    final total = _deck.length;
    final pct = total == 0 ? 0 : (_score / total * 100).round();
    final passed = pct >= _ePassPercent;
    final isLast = widget.roundIndex + 1 >= emojiRounds.length;
    String msg;
    if (passed && isLast) {
      msg = 'Incredible! You\'ve completed all rounds! 🎉';
    } else if (passed) {
      msg = 'Great job! Round ${widget.roundIndex + 2} is now unlocked. 🔓';
    } else {
      msg = 'You need $_ePassPercent% to pass. Try again! 😀';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(passed ? '🎉' : '💪', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('Skor kamu: $_score/$total',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (passed ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(passed ? '✅ Passed' : '🔒 Not passed',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _deck = List<EmojiItem>.from(widget.round.items)
                      ..shuffle(_rng);
                    _index = 0;
                    _score = 0;
                    _finished = false;
                    _buildChoices();
                  });
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Main Lagi',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_score),
              child: const Text('Kembali ke Ronde'),
            ),
          ],
        ),
      ),
    );
  }
}
