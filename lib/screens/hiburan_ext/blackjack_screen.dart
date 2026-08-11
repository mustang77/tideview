import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

/// ════════════════════════════════════════════════════════════════════════
/// Blackjack — kamu + 2 AI lawan Dealer. Taruhan chip main-main (Hit/Stand/
/// Double), Bahasa Indonesia, suara sintetis (tanpa file). Satu file,
/// hanya butuh audioplayers.
/// ════════════════════════════════════════════════════════════════════════

// ── Suara sintetis ─────────────────────────────────────────────────────────
class _BjSfx {
  final AudioPlayer _deal = AudioPlayer();
  final AudioPlayer _chip = AudioPlayer();
  final AudioPlayer _win = AudioPlayer();
  final AudioPlayer _bust = AudioPlayer();
  Uint8List? _dealW, _chipW, _winW, _bustW;
  bool _ready = false;

  void init() {
    if (_ready) return;
    _dealW = _tone(freq: 480, ms: 55, decay: 22, vol: 0.5, second: 300);
    _chipW = _tone(freq: 700, ms: 60, decay: 25, vol: 0.6, second: 1100);
    _winW = _tone(freq: 523, ms: 260, decay: 160, vol: 0.75, second: 784);
    _bustW = _tone(freq: 200, ms: 220, decay: 120, vol: 0.7, slideDown: true);
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

  void deal() => _play(_deal, _dealW, 0.6);
  void chip() => _play(_chip, _chipW, 0.8);
  void win() => _play(_win, _winW, 0.9);
  void bust() => _play(_bust, _bustW, 0.8);

  void dispose() {
    _deal.dispose();
    _chip.dispose();
    _win.dispose();
    _bust.dispose();
  }

  Uint8List _tone({
    required double freq,
    required int ms,
    required int decay,
    required double vol,
    double? second,
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

// ── Kartu ───────────────────────────────────────────────────────────────────
const List<String> _rankNames = [
  'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
];
const List<String> _suitSym = ['♠', '♥', '♦', '♣'];

class _Card {
  final int rank; // 0=A, 1..9 = 2..10, 10=J,11=Q,12=K
  final int suit;
  const _Card(this.rank, this.suit);
  String get label => '${_rankNames[rank]}${_suitSym[suit]}';
  bool get isRed => suit == 1 || suit == 2;
  int get baseValue {
    if (rank == 0) return 11; // Ace = 11 (disesuaikan nanti)
    if (rank >= 10) return 10; // J,Q,K
    return rank + 1; // 2..10
  }
  bool get isAce => rank == 0;
}

/// Nilai tangan dengan penyesuaian Ace (11 -> 1 bila bust).
int _handValue(List<_Card> cards) {
  var total = 0;
  var aces = 0;
  for (final c in cards) {
    total += c.baseValue;
    if (c.isAce) aces++;
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return total;
}

bool _isBlackjack(List<_Card> cards) =>
    cards.length == 2 && _handValue(cards) == 21;

// ── Pemain ──────────────────────────────────────────────────────────────────
class _Seat {
  final String name;
  final bool isHuman;
  int chips;
  int bet = 0;
  List<_Card> hand = [];
  bool stood = false;
  bool busted = false;
  bool doubled = false;
  String result = ''; // 'Menang','Kalah','Seri','BJ','Bust'
  _Seat(this.name, this.chips, {this.isHuman = false});
}

enum _Phase { betting, playerTurns, dealerTurn, settle }

class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({super.key});
  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  static const int _startChips = 1000;
  static const int _minBet = 25;

  final _rng = Random();
  final _BjSfx _sfx = _BjSfx();

  late List<_Seat> _seats; // 0 = kamu, 1..2 = AI
  List<_Card> _dealer = [];
  List<_Card> _shoe = [];
  bool _dealerHoleHidden = true;
  _Phase _phase = _Phase.betting;
  int _activeSeat = 0;
  String _status = 'Pasang taruhanmu.';
  int _pendingBet = _minBet; // taruhan yang sedang dipilih manusia

  @override
  void initState() {
    super.initState();
    _sfx.init();
    _seats = [
      _Seat('Kamu', _startChips, isHuman: true),
      _Seat('Andi', _startChips),
      _Seat('Budi', _startChips),
    ];
    _newShoe();
    _phase = _Phase.betting;
  }

  @override
  void dispose() {
    _sfx.dispose();
    super.dispose();
  }

  _Seat get _human => _seats[0];

  void _newShoe() {
    // 4 dek dikocok jadi satu shoe.
    _shoe = [];
    for (var d = 0; d < 4; d++) {
      for (var r = 0; r < 13; r++) {
        for (var s = 0; s < 4; s++) {
          _shoe.add(_Card(r, s));
        }
      }
    }
    _shoe.shuffle(_rng);
  }

  _Card _draw() {
    if (_shoe.length < 20) _newShoe();
    return _shoe.removeLast();
  }

  // ── Taruhan ──────────────────────────────────────────────────────────────
  void _placeBetAndDeal() {
    if (_phase != _Phase.betting) return;
    final bet = _pendingBet.clamp(_minBet, _human.chips);
    if (_human.chips < _minBet) {
      // Reset chips kalau bangkrut.
      for (final s in _seats) {
        if (s.chips < _minBet) s.chips = _startChips;
      }
    }
    // Set taruhan semua kursi (AI taruhan sederhana).
    for (final s in _seats) {
      s.hand = [];
      s.stood = false;
      s.busted = false;
      s.doubled = false;
      s.result = '';
      if (s.isHuman) {
        s.bet = bet;
      } else {
        s.bet = (_minBet * (1 + _rng.nextInt(4))).clamp(_minBet, s.chips);
      }
      s.chips -= s.bet;
    }
    _sfx.chip();
    _dealer = [];
    _dealerHoleHidden = true;

    // Bagikan: 2 kartu tiap kursi + dealer.
    for (var round = 0; round < 2; round++) {
      for (final s in _seats) {
        s.hand.add(_draw());
      }
      _dealer.add(_draw());
    }
    _sfx.deal();

    _phase = _Phase.playerTurns;
    _activeSeat = 0;
    setState(() => _status = 'Kartu dibagikan.');
    _beginSeatTurn();
  }

  // ── Giliran pemain ────────────────────────────────────────────────────────
  void _beginSeatTurn() {
    if (_activeSeat >= _seats.length) {
      _dealerPlay();
      return;
    }
    final s = _seats[_activeSeat];
    // Blackjack otomatis stand.
    if (_isBlackjack(s.hand)) {
      s.result = 'BJ';
      s.stood = true;
      _nextSeat();
      return;
    }
    if (s.isHuman) {
      setState(() => _status = 'Giliranmu: Hit, Stand, atau Double?');
    } else {
      setState(() => _status = '${s.name} bermain...');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _aiPlay(_activeSeat);
      });
    }
  }

  void _nextSeat() {
    _activeSeat++;
    _beginSeatTurn();
  }

  void _humanHit() {
    if (_phase != _Phase.playerTurns || _activeSeat != 0) return;
    final s = _human;
    s.hand.add(_draw());
    _sfx.deal();
    final v = _handValue(s.hand);
    if (v > 21) {
      s.busted = true;
      s.result = 'Bust';
      _sfx.bust();
      setState(() => _status = 'Kamu bust dengan $v!');
      Future.delayed(const Duration(milliseconds: 700), _nextSeat);
    } else {
      setState(() {});
    }
  }

  void _humanStand() {
    if (_phase != _Phase.playerTurns || _activeSeat != 0) return;
    _human.stood = true;
    _nextSeat();
  }

  void _humanDouble() {
    if (_phase != _Phase.playerTurns || _activeSeat != 0) return;
    final s = _human;
    if (s.chips < s.bet || s.hand.length != 2) return;
    s.chips -= s.bet;
    s.bet *= 2;
    s.doubled = true;
    _sfx.chip();
    s.hand.add(_draw());
    _sfx.deal();
    final v = _handValue(s.hand);
    if (v > 21) {
      s.busted = true;
      s.result = 'Bust';
      _sfx.bust();
      setState(() => _status = 'Double — kamu bust dengan $v!');
    } else {
      s.stood = true;
      setState(() => _status = 'Double — kamu berhenti di $v.');
    }
    Future.delayed(const Duration(milliseconds: 700), _nextSeat);
  }

  // ── AI ────────────────────────────────────────────────────────────────────
  void _aiPlay(int index) {
    final s = _seats[index];
    // Strategi dasar sederhana: lihat kartu atas dealer.
    final dealerUp = _dealer[0].baseValue;
    // Loop: hit sampai berhenti sesuai aturan basic-strategy ringkas.
    void act() {
      final v = _handValue(s.hand);
      final soft = _isSoft(s.hand);
      bool hit;
      if (v <= 11) {
        hit = true;
      } else if (soft && v <= 17) {
        hit = true; // soft 17 or less -> hit
      } else if (v == 12) {
        hit = dealerUp >= 7 || dealerUp <= 3;
      } else if (v >= 13 && v <= 16) {
        hit = dealerUp >= 7;
      } else {
        hit = false; // 17+
      }
      if (hit && v < 21) {
        s.hand.add(_draw());
        _sfx.deal();
        final nv = _handValue(s.hand);
        setState(() {});
        if (nv > 21) {
          s.busted = true;
          s.result = 'Bust';
          _sfx.bust();
          Future.delayed(const Duration(milliseconds: 600), _nextSeat);
        } else {
          Future.delayed(const Duration(milliseconds: 600), act);
        }
      } else {
        s.stood = true;
        Future.delayed(const Duration(milliseconds: 400), _nextSeat);
      }
    }
    act();
  }

  bool _isSoft(List<_Card> cards) {
    var total = 0;
    var aces = 0;
    for (final c in cards) {
      total += c.baseValue;
      if (c.isAce) aces++;
    }
    // Soft jika ada Ace yang masih dihitung 11.
    return aces > 0 && total <= 21;
  }

  // ── Giliran dealer ────────────────────────────────────────────────────────
  void _dealerPlay() {
    _phase = _Phase.dealerTurn;
    _dealerHoleHidden = false;
    setState(() => _status = 'Dealer membuka kartu...');

    // Kalau semua pemain bust/BJ, dealer tetap main untuk kejelasan.
    void step() {
      final v = _handValue(_dealer);
      // Dealer hit sampai 17 (stand di semua 17, termasuk soft 17 -> stand).
      if (v < 17) {
        _dealer.add(_draw());
        _sfx.deal();
        setState(() {});
        Future.delayed(const Duration(milliseconds: 700), step);
      } else {
        _settle();
      }
    }

    Future.delayed(const Duration(milliseconds: 700), step);
  }

  // ── Penyelesaian ──────────────────────────────────────────────────────────
  void _settle() {
    _phase = _Phase.settle;
    final dv = _handValue(_dealer);
    final dealerBJ = _isBlackjack(_dealer);
    final dealerBust = dv > 21;

    for (final s in _seats) {
      if (s.busted) {
        s.result = 'Bust';
        continue; // taruhan sudah hilang
      }
      final pv = _handValue(s.hand);
      final playerBJ = _isBlackjack(s.hand);

      if (playerBJ && !dealerBJ) {
        // Blackjack bayar 3:2.
        s.chips += (s.bet * 2.5).round();
        s.result = 'BJ';
      } else if (dealerBJ && !playerBJ) {
        s.result = 'Kalah';
      } else if (dealerBust) {
        s.chips += s.bet * 2;
        s.result = 'Menang';
      } else if (pv > dv) {
        s.chips += s.bet * 2;
        s.result = 'Menang';
      } else if (pv == dv) {
        s.chips += s.bet; // seri, taruhan kembali
        s.result = 'Seri';
      } else {
        s.result = 'Kalah';
      }
    }

    // Suara berdasarkan hasil manusia.
    final r = _human.result;
    if (r == 'Menang' || r == 'BJ') {
      _sfx.win();
    } else if (r == 'Bust' || r == 'Kalah') {
      _sfx.bust();
    }

    final msg = dealerBust
        ? 'Dealer bust ($dv)! ${_resultText(_human.result)}'
        : 'Dealer $dv. ${_resultText(_human.result)}';
    setState(() => _status = msg);
  }

  String _resultText(String r) {
    switch (r) {
      case 'Menang':
        return 'Kamu menang! 🎉';
      case 'BJ':
        return 'Blackjack! Bayar 3:2 🎉';
      case 'Seri':
        return 'Seri — taruhan kembali.';
      case 'Kalah':
        return 'Kamu kalah.';
      case 'Bust':
        return 'Kamu bust.';
    }
    return '';
  }

  void _nextRound() {
    setState(() {
      _phase = _Phase.betting;
      _dealer = [];
      _dealerHoleHidden = true;
      _status = 'Pasang taruhanmu.';
      for (final s in _seats) {
        s.hand = [];
        s.bet = 0;
        s.stood = false;
        s.busted = false;
        s.doubled = false;
        s.result = '';
      }
      _pendingBet = _pendingBet.clamp(_minBet, max(_minBet, _human.chips));
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF072A18),
        foregroundColor: Colors.white,
        title: const Text('Blackjack'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dealer.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  Text(
                    _dealerHoleHidden
                        ? 'Dealer'
                        : 'Dealer — ${_handValue(_dealer)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _dealer.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: (i == 1 && _dealerHoleHidden)
                              ? _cardBack(big: true)
                              : _cardWidget(_dealer[i], big: true),
                        ),
                      if (_dealer.isEmpty) _cardBack(big: true),
                    ],
                  ),
                ],
              ),
            ),
            // Status.
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            // Seats (AI + you).
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 1; i < _seats.length; i++) _seatRow(i),
                    _seatRow(0), // kamu paling bawah
                  ],
                ),
              ),
            ),
            // Controls.
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _seatRow(int index) {
    final s = _seats[index];
    final active = _phase == _Phase.playerTurns && _activeSeat == index;
    final v = s.hand.isEmpty ? 0 : _handValue(s.hand);
    Color resultColor() {
      switch (s.result) {
        case 'Menang':
        case 'BJ':
          return Colors.greenAccent;
        case 'Kalah':
        case 'Bust':
          return Colors.redAccent;
        case 'Seri':
          return Colors.amberAccent;
      }
      return Colors.white70;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active
            ? Colors.amber.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active ? Colors.amber : Colors.white24,
            width: active ? 2 : 1),
      ),
      child: Row(
        children: [
          // Name + chips + bet.
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: TextStyle(
                        color: s.isHuman ? Colors.lightBlueAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text('💰 ${s.chips}',
                    style: const TextStyle(
                        color: Colors.amber, fontSize: 11)),
                if (s.bet > 0)
                  Text('Taruh ${s.bet}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          // Cards.
          Expanded(
            child: Row(
              children: [
                for (final c in s.hand)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: _cardWidget(c),
                  ),
              ],
            ),
          ),
          // Value + result.
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (s.hand.isNotEmpty)
                  Text('$v',
                      style: TextStyle(
                          color: v > 21 ? Colors.redAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                if (s.result.isNotEmpty)
                  Text(s.result,
                      style: TextStyle(
                          color: resultColor(),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    if (_phase == _Phase.betting) {
      final maxBet = max(_minBet, _human.chips);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Taruhan',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _pendingBet
                        .clamp(_minBet, maxBet)
                        .toDouble(),
                    min: _minBet.toDouble(),
                    max: maxBet.toDouble(),
                    onChanged: (v) =>
                        setState(() => _pendingBet = v.round()),
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: Text('$_pendingBet',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _placeBetAndDeal,
                icon: const Icon(Icons.style),
                label: const Text('BAGIKAN KARTU',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      );
    }

    if (_phase == _Phase.settle) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _nextRound,
            icon: const Icon(Icons.replay),
            label: const Text('Ronde Berikutnya',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      );
    }

    // Player turn controls (only enabled when it's the human's turn).
    final myTurn = _phase == _Phase.playerTurns && _activeSeat == 0;
    final canDouble = myTurn && _human.hand.length == 2 &&
        _human.chips >= _human.bet;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: myTurn ? _humanHit : null,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Hit',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: myTurn ? _humanStand : null,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Stand',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: canDouble ? _humanDouble : null,
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Double',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Kartu widget ────────────────────────────────────────────────────────
  Widget _cardWidget(_Card c, {bool big = false}) {
    final w = big ? 44.0 : 30.0;
    final h = big ? 62.0 : 42.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(big ? 7 : 5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 2,
              offset: const Offset(1, 1)),
        ],
      ),
      child: Center(
        child: Text('${_rankNames[c.rank]}\n${_suitSym[c.suit]}',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c.isRed ? const Color(0xFFD32F2F) : Colors.black,
                fontSize: big ? 16 : 12,
                height: 1.05,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _cardBack({bool big = false}) {
    final w = big ? 44.0 : 30.0;
    final h = big ? 62.0 : 42.0;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: const Color(0xFF1A4C8B),
        borderRadius: BorderRadius.circular(big ? 7 : 5),
        border: Border.all(color: Colors.white54, width: 1),
      ),
      child: Center(
        child: Icon(Icons.anchor,
            color: Colors.white.withValues(alpha: 0.6), size: big ? 22 : 14),
      ),
    );
  }
}
