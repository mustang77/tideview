import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:share_plus/share_plus.dart";

import "app_state.dart";
import "tahlil_data.dart";

/// The Tahlil arrangement, read sequentially. Content from NU Online.
class TahlilScreen extends StatelessWidget {
  const TahlilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tahlil",
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: "Share all",
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final text = tahlilEntries
                  .map((e) =>
                      "${e.arabic}\n${e.latin}\n${e.translation}")
                  .join("\n\n");
              SharePlus.instance.share(ShareParams(
                  text: "Bacaan Tahlil\n\n$text\n\n— quran.nu.or.id/tahlil"));
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tahlilEntries.length + 1,
        itemBuilder: (context, i) {
          if (i == tahlilEntries.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Text(
                "Source: NU Online — quran.nu.or.id/tahlil",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            );
          }
          final e = tahlilEntries[i];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor:
                          scheme.primary.withValues(alpha: 0.12),
                      child: Text("${i + 1}",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary)),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () => SharePlus.instance.share(ShareParams(
                          text:
                              "${e.arabic}\n\n${e.latin}\n\n${e.translation}")),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  e.arabic,
                  style: GoogleFonts.amiri(
                      fontSize: state.arabicFontSize * 0.9, height: 2.0),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 10),
                Text(e.latin,
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                        height: 1.5,
                        color: scheme.primary)),
                const SizedBox(height: 8),
                Text(e.translation,
                    style: const TextStyle(fontSize: 14.5, height: 1.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}
