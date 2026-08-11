// Pembuat Banner satu-ketuk untuk Info & Promo: pilih template, ketik
// teks, pratinjau langsung, lalu "Pasang" — banner dirender menjadi
// gambar PNG dan diposting sebagai promo admin (tampil di carousel
// Beranda semua pelanggan).

import 'dart:convert' show base64Encode;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../store.dart';

class _BannerStyle {
  const _BannerStyle(this.name, this.colors, this.accent, this.emoji,
      {this.darkText = false});

  final String name;
  final List<Color> colors;
  final Color accent;
  final String emoji;

  /// true = latar terang, teks pakai warna gelap.
  final bool darkText;
}

const _styles = <_BannerStyle>[
  _BannerStyle('Laut H2O', [Color(0xFF06B6D4), Color(0xFF0B4F6C)],
      Color(0xFFF6C445), '💧'),
  _BannerStyle('Diskon Merah', [Color(0xFFEF4444), Color(0xFF991B1B)],
      Color(0xFFFDE047), '🎉'),
  _BannerStyle('Senja', [Color(0xFF8B5CF6), Color(0xFFEC4899)],
      Color(0xFFFDE047), '✨'),
  _BannerStyle('Hijau Emas', [Color(0xFF059669), Color(0xFF064E3B)],
      Color(0xFFF6C445), '🌙'),
  _BannerStyle('Ceria', [Color(0xFFFDE047), Color(0xFFF97316)],
      Color(0xFF0E7490), '☀️', darkText: true),
  _BannerStyle('Malam Neon', [Color(0xFF0F172A), Color(0xFF312E81)],
      Color(0xFF22D3EE), '⚡'),
];

class BannerMakerScreen extends StatefulWidget {
  const BannerMakerScreen({super.key});

  @override
  State<BannerMakerScreen> createState() => _BannerMakerScreenState();
}

class _BannerMakerScreenState extends State<BannerMakerScreen> {
  final _judul = TextEditingController(text: 'DISKON 20%');
  final _sub = TextEditingController(text: 'Semua layanan cuci minggu ini');
  final _badge = TextEditingController(text: 'PROMO SPESIAL');
  int _style = 0;
  bool _busy = false;
  final _previewKey = GlobalKey();

  @override
  void dispose() {
    _judul.dispose();
    _sub.dispose();
    _badge.dispose();
    super.dispose();
  }

  Future<void> _pasang() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Render pratinjau menjadi PNG tajam (~1400 px lebar).
      final boundary = _previewKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ratio = 1400 / boundary.size.width;
      final img = await boundary.toImage(pixelRatio: ratio);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final b64 = base64Encode(data!.buffer.asUint8List());
      final err = await store.createPromo(
        caption: _judul.text.trim().isEmpty
            ? 'Promo H2O Laundry'
            : '${_judul.text.trim()} — ${_sub.text.trim()}',
        imageBase64: b64,
        imageExt: 'png',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Banner terpasang di Beranda ✅')));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal membuat banner. Coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _styles[_style];
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Banner')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Pratinjau langsung (inilah yang dirender jadi PNG) --
            RepaintBoundary(
              key: _previewKey,
              child: _BannerPreview(
                style: s,
                judul: _judul.text,
                sub: _sub.text,
                badge: _badge.text,
              ),
            ),
            const SizedBox(height: 14),
            // ---- Pilih template ------------------------------------
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _styles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final t = _styles[i];
                  final active = i == _style;
                  return InkWell(
                    onTap: () => setState(() => _style = i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 86,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: t.colors),
                        borderRadius: BorderRadius.circular(12),
                        border: active
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                width: 3)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${t.emoji}\n${t.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10.5,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                            color: t.darkText
                                ? const Color(0xFF1E293B)
                                : Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // ---- Teks ----------------------------------------------
            TextField(
              controller: _badge,
              maxLength: 24,
              decoration: const InputDecoration(
                  labelText: 'Label kecil (badge)',
                  counterText: '',
                  prefixIcon: Icon(Icons.sell_outlined)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _judul,
              maxLength: 26,
              decoration: const InputDecoration(
                  labelText: 'Judul besar',
                  counterText: '',
                  prefixIcon: Icon(Icons.title)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sub,
              maxLength: 60,
              decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  counterText: '',
                  prefixIcon: Icon(Icons.notes_outlined)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _pasang,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.rocket_launch_outlined),
              label: Text(
                  _busy ? 'Memasang...' : 'Pasang Banner ke Beranda'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
            ),
            const SizedBox(height: 8),
            Text(
              'Banner tampil di carousel Info & Promo Beranda dan semua '
              'pelanggan mendapat notifikasi promo baru.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tampilan banner itu sendiri — 16:7, gradasi + hiasan lingkaran +
/// emoji besar, teks kiri: badge, judul (menyusut otomatis), keterangan,
/// dan merek H2O di bawah.
class _BannerPreview extends StatelessWidget {
  const _BannerPreview(
      {required this.style,
      required this.judul,
      required this.sub,
      required this.badge});

  final _BannerStyle style;
  final String judul;
  final String sub;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final fg = style.darkText ? const Color(0xFF1E293B) : Colors.white;
    final fgSoft = style.darkText
        ? const Color(0xB31E293B)
        : Colors.white.withValues(alpha: 0.85);
    final deco = style.darkText ? Colors.black : Colors.white;
    return AspectRatio(
      aspectRatio: 16 / 7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: style.colors,
                ),
              ),
            ),
            // Hiasan lingkaran lembut.
            Positioned(
                right: -40,
                top: -60,
                child: _circle(150, deco.withValues(alpha: 0.10))),
            Positioned(
                right: 40,
                bottom: -70,
                child: _circle(140, deco.withValues(alpha: 0.08))),
            Positioned(
                left: -30,
                bottom: -50,
                child: _circle(110, deco.withValues(alpha: 0.07))),
            // Emoji besar kanan.
            Positioned(
              right: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.12,
                  child: Text(style.emoji,
                      style: const TextStyle(fontSize: 64)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 96, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badge.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge.trim().toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w800,
                            color: style.darkText
                                ? Colors.white
                                : const Color(0xFF1E293B)),
                      ),
                    ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      judul.trim().isEmpty ? 'Judul Promo' : judul.trim(),
                      style: TextStyle(
                          fontSize: 34,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: fg),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, height: 1.25, color: fgSoft),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.local_laundry_service,
                          size: 14, color: fgSoft),
                      const SizedBox(width: 5),
                      Text('H2O Laundry Parakan',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: fgSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );
}
