import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'hiburan_ext/games_hub_screen.dart';
import 'hiburan_ext/music_screen.dart';
import 'hiburan_ext/zodiac_screen.dart';

/// Bagian Hiburan di Beranda: kisi ubin tautan (musik, game, dll)
/// yang isinya dikelola admin lewat HiburanManageScreen.
class HiburanSection extends StatelessWidget {
  const HiburanSection({super.key});

  static const _tileColors = [
    [Color(0xFF6D28D9), Color(0xFF9333EA)],
    [Color(0xFF0E7490), Color(0xFF06B6D4)],
    [Color(0xFFDB2777), Color(0xFFF472B6)],
    [Color(0xFFD97706), Color(0xFFFBBF24)],
    [Color(0xFF16A34A), Color(0xFF4ADE80)],
    [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionTitle('Hiburan'),
        GridView.count(
          crossAxisCount:
              MediaQuery.sizeOf(context).width > 560 ? 4 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            // Ubin bawaan: layar Game dan Musik di dalam aplikasi
            // (dibawa dari wca_app).
            _BuiltinTileCard(
              emoji: '🎮',
              title: 'Game',
              colors: const [Color(0xFF7C3AED), Color(0xFFDB2777)],
              builder: () => const GamesHubScreen(),
            ),
            _BuiltinTileCard(
              emoji: '🎵',
              title: 'Musik',
              colors: const [Color(0xFF0E7490), Color(0xFF06B6D4)],
              builder: () => const MusicScreen(),
            ),
            _BuiltinTileCard(
              emoji: '🔮',
              title: 'Zodiak',
              colors: const [Color(0xFF5E35B1), Color(0xFF039BE5)],
              builder: () => const ZodiacScreen(),
            ),
            for (var i = 0; i < store.hiburan.length; i++)
              _HiburanTileCard(
                tile: store.hiburan[i],
                colors: _tileColors[(i + 2) % _tileColors.length],
              ),
          ],
        ),
      ],
    );
  }
}

/// Ubin bawaan yang membuka layar di dalam aplikasi (bukan tautan).
class _BuiltinTileCard extends StatelessWidget {
  const _BuiltinTileCard({
    required this.emoji,
    required this.title,
    required this.colors,
    required this.builder,
  });

  final String emoji;
  final String title;
  final List<Color> colors;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => builder())),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiburanTileCard extends StatelessWidget {
  const _HiburanTileCard({required this.tile, required this.colors});

  final HiburanTile tile;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final uri = Uri.tryParse(tile.url);
        if (uri == null) return;
        var ok = false;
        try {
          ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
        if (!ok) {
          try {
            await launchUrl(uri);
          } catch (_) {}
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(tile.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              tile.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layar pemilik: kelola ubin Hiburan (tambah & hapus).
class HiburanManageScreen extends StatelessWidget {
  const HiburanManageScreen({super.key});

  Future<void> _addTile(BuildContext context) async {
    final title = TextEditingController();
    final emoji = TextEditingController(text: '🎵');
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Tambah Ubin Hiburan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'Judul (mis. Musik)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emoji,
              maxLength: 8,
              decoration: const InputDecoration(
                  labelText: 'Emoji ikon', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'URL', hintText: 'https://...'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Tambah')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await store.addHiburan(
        title.text.trim(), emoji.text.trim(), url.text.trim());
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hiburan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTile(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Ubin'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => store.hiburan.isEmpty
              ? const EmptyState(
                  icon: Icons.sports_esports_outlined,
                  message: 'Belum ada ubin. Tambahkan tautan musik, '
                      'game, atau hiburan lain untuk pelanggan!')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: store.hiburan.length,
                  itemBuilder: (context, i) {
                    final t = store.hiburan[i];
                    return Card(
                      child: ListTile(
                        leading: Text(t.emoji,
                            style: const TextStyle(fontSize: 24)),
                        title: Text(t.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        subtitle: Text(t.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => store.deleteHiburan(t),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
