import 'package:flutter/material.dart';

import '../../store.dart';

// Layar Ramalan Zodiak — dibawa dari wca_app; sumber ramalan diganti
// dari Cloud Function menjadi endpoint server sendiri (/api/zodiac).

class _Sign {
  final String api;
  final String name;
  final String animal;
  final String symbol;
  final String dates;
  final Color color;
  const _Sign(
      this.api, this.name, this.animal, this.symbol, this.dates, this.color);
}

const _signs = <_Sign>[
  _Sign('Aries', 'Aries', '🐐', '♈', '21 Mar - 19 Apr', Color(0xFFE53935)),
  _Sign('Taurus', 'Taurus', '🐂', '♉', '20 Apr - 20 Mei', Color(0xFF43A047)),
  _Sign('Gemini', 'Gemini', '👯', '♊', '21 Mei - 20 Jun', Color(0xFFF9A825)),
  _Sign('Cancer', 'Cancer', '🦀', '♋', '21 Jun - 22 Jul', Color(0xFF00ACC1)),
  _Sign('Leo', 'Leo', '🦁', '♌', '23 Jul - 22 Agu', Color(0xFFFB8C00)),
  _Sign('Virgo', 'Virgo', '👰', '♍', '23 Agu - 22 Sep', Color(0xFF8E24AA)),
  _Sign('Libra', 'Libra', '⚖️', '♎', '23 Sep - 22 Okt', Color(0xFFEC407A)),
  _Sign('Scorpio', 'Scorpio', '🦂', '♏', '23 Okt - 21 Nov', Color(0xFFC62828)),
  _Sign('Sagittarius', 'Sagittarius', '🏹', '♐', '22 Nov - 21 Des',
      Color(0xFF5E35B1)),
  _Sign('Capricorn', 'Capricorn', '🐐', '♑', '22 Des - 19 Jan',
      Color(0xFF6D4C41)),
  _Sign('Aquarius', 'Aquarius', '🏺', '♒', '20 Jan - 18 Feb',
      Color(0xFF039BE5)),
  _Sign('Pisces', 'Pisces', '🐟', '♓', '19 Feb - 20 Mar', Color(0xFF00897B)),
];

class ZodiacScreen extends StatelessWidget {
  const ZodiacScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ramalan Zodiak')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                'Ketuk zodiakmu untuk melihat ramalan hari ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _signs.length,
                itemBuilder: (context, i) {
                  final s = _signs[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _HoroscopeScreen(sign: s),
                    )),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            s.color.withValues(alpha: 0.85),
                            s.color.withValues(alpha: 0.55),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: s.color.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.animal,
                              style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          Text(s.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                        offset: Offset(0, 1))
                                  ])),
                          const SizedBox(height: 2),
                          Text('${s.symbol}  ${s.dates}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 9.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoroscopeScreen extends StatefulWidget {
  final _Sign sign;
  const _HoroscopeScreen({required this.sign});
  @override
  State<_HoroscopeScreen> createState() => _HoroscopeScreenState();
}

class _HoroscopeScreenState extends State<_HoroscopeScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _d = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final a = store.api;
    if (a == null) {
      setState(() {
        _error = 'Ramalan membutuhkan koneksi ke server.';
        _loading = false;
      });
      return;
    }
    try {
      final d = await a.getZodiac(widget.sign.api);
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tidak bisa terhubung. Cek koneksi internet.';
        _loading = false;
      });
    }
  }

  int _rating(String key) {
    final r = _d['rating'];
    if (r is Map) return (r[key] as num?)?.toInt() ?? 3;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sign;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Kepala gradasi besar dengan warna khas zodiaknya.
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: s.color,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('${s.name}  ${s.symbol}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [s.color, s.color.withValues(alpha: 0.55)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.animal, style: const TextStyle(fontSize: 64)),
                      const SizedBox(height: 6),
                      Text(s.dates,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                      ? Column(
                          children: [
                            const SizedBox(height: 24),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba lagi'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                _luckyChip(
                                    '🔢', 'Angka', '${_d['angka'] ?? '-'}'),
                                const SizedBox(width: 8),
                                _luckyChip(
                                    '🎨', 'Warna', '${_d['warna'] ?? '-'}'),
                                const SizedBox(width: 8),
                                _luckyChip('💞', 'Cocok dgn',
                                    '${_d['pasangan'] ?? '-'}'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _section('✨', 'Umum', '${_d['umum'] ?? ''}',
                                null, s.color),
                            _section(
                                '❤️',
                                'Asmara',
                                '${_d['asmara'] ?? ''}',
                                _rating('asmara'),
                                const Color(0xFFE91E63)),
                            _section(
                                '💰',
                                'Keuangan',
                                '${_d['keuangan'] ?? ''}',
                                _rating('keuangan'),
                                const Color(0xFF43A047)),
                            _section(
                                '🧺',
                                'Karier',
                                '${_d['karier'] ?? ''}',
                                _rating('karier'),
                                const Color(0xFF1E88E5)),
                            _section(
                                '🌿',
                                'Kesehatan',
                                '${_d['kesehatan'] ?? ''}',
                                _rating('kesehatan'),
                                const Color(0xFF00897B)),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Ramalan hanya untuk hiburan. • '
                                '${_d['date'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _luckyChip(String emoji, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 1),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _section(
      String emoji, String title, String body, int? stars, Color accent) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: accent)),
                const Spacer(),
                if (stars != null)
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        size: 16,
                        color: const Color(0xFFF5B942),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(fontSize: 14.5, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
