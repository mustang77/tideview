import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_state.dart";
import "models.dart";
import "quran_data.dart";
import "quran_service.dart";
import "surah_screen.dart";

/// Home: last-read card plus Surah / Juz index tabs.
class HomeScreen extends StatefulWidget {
  final QuranService service;
  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = "";

  void _openSurah(int surah, {int? scrollToAyah}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurahScreen(
        service: widget.service,
        surahNumber: surah,
        scrollToAyah: scrollToAyah,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final filtered = _filter.isEmpty
        ? surahs
        : surahs
            .where((s) =>
                s.nameEnglish.toLowerCase().contains(_filter) ||
                s.meaning.toLowerCase().contains(_filter) ||
                s.nameArabic.contains(_filter) ||
                s.number.toString() == _filter)
            .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Al-Quran",
              style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: const TabBar(
            tabs: [Tab(text: "Surah"), Tab(text: "Juz")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSurahTab(state, filtered),
            _buildJuzTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahTab(AppState state, List<SurahInfo> filtered) {
    final lastRead = state.lastRead;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Find a surah…",
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
            ),
            onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
          ),
        ),
        if (lastRead != null && _filter.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _LastReadCard(
              lastRead: lastRead,
              onTap: () =>
                  _openSurah(lastRead.surah, scrollToAyah: lastRead.ayah),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 72, endIndent: 16),
            itemBuilder: (context, i) {
              final s = filtered[i];
              return _SurahTile(surah: s, onTap: () => _openSurah(s.number));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJuzTab() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: juzStarts.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (context, i) {
        final j = juzStarts[i];
        final start = surahByNumber(j.startSurah);
        return ListTile(
          leading: _NumberBadge(number: j.number),
          title: Text("Juz ${j.number}",
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              "Starts at ${start.nameEnglish} ${j.startSurah}:${j.startAyah}"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openSurah(j.startSurah, scrollToAyah: j.startAyah),
        );
      },
    );
  }
}

class _LastReadCard extends StatelessWidget {
  final VerseRef lastRead;
  final VoidCallback onTap;
  const _LastReadCard({required this.lastRead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surah = surahByNumber(lastRead.surah);
    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.auto_stories, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Continue reading",
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.8))),
                    const SizedBox(height: 2),
                    Text(
                      "${surah.nameEnglish} — Ayah ${lastRead.ayah}",
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill,
                  size: 32, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  final SurahInfo surah;
  final VoidCallback onTap;
  const _SurahTile({required this.surah, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _NumberBadge(number: surah.number),
      title: Text(surah.nameEnglish,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          "${surah.meaning} • ${surah.revelation} • ${surah.ayahCount} ayahs"),
      trailing: Text(
        surah.nameArabic,
        style: GoogleFonts.amiri(fontSize: 20, color: scheme.primary),
        textDirection: TextDirection.rtl,
      ),
      onTap: onTap,
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.785398, // 45°: a diamond behind the number
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.4)),
              ),
            ),
          ),
          Text("$number",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary)),
        ],
      ),
    );
  }
}
