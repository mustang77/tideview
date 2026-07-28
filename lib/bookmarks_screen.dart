import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_state.dart";
import "quran_data.dart";
import "quran_service.dart";
import "surah_screen.dart";

/// Saved verses; tap to jump back to the ayah.
class BookmarksScreen extends StatelessWidget {
  final QuranService service;
  const BookmarksScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final bookmarks = state.bookmarks;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Bookmarks",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: bookmarks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_outline,
                      size: 48, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    "No bookmarks yet.\nTap the bookmark icon on any ayah.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, i) {
                final ref = bookmarks[i];
                final surah = surahByNumber(ref.surah);
                return Dismissible(
                  key: ValueKey(ref.key),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: scheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(Icons.delete, color: scheme.onErrorContainer),
                  ),
                  onDismissed: (_) => state.toggleBookmark(ref),
                  child: ListTile(
                    leading: Icon(Icons.bookmark, color: scheme.primary),
                    title: Text(
                        "${surah.nameEnglish} ${ref.surah}:${ref.ayah}",
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text("${surah.meaning} • ${surah.revelation}"),
                    trailing: Text(
                      surah.nameArabic,
                      style:
                          GoogleFonts.amiri(fontSize: 18, color: scheme.primary),
                      textDirection: TextDirection.rtl,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SurahScreen(
                          service: service,
                          surahNumber: ref.surah,
                          scrollToAyah: ref.ayah,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
