import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";

import "sirah_data.dart";

/// Sirah Nabawiyah: garis waktu kehidupan Rasulullah ﷺ per periode.
class SirahScreen extends StatelessWidget {
  const SirahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <Widget>[
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B8A6B), Color(0xFF0B4437)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sirah Nabawiyah",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "Ringkasan perjalanan hidup Rasulullah Muhammad ﷺ — dari "
              "kelahiran di Makkah hingga wafat di Madinah, disusun per "
              "periode.",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), height: 1.5),
            ),
          ],
        ),
      ),
    ];

    for (final period in sirahPeriods) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                period.title.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: scheme.primary,
                ),
              ),
            ),
            Text(period.range,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
      ));
      for (final e in period.events) {
        items.add(_EventCard(event: e));
      }
    }

    items.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Text(
        "Ringkasan ini disusun dari riwayat-riwayat sirah yang masyhur; "
        "sebagian penanggalan Masehi bersifat perkiraan.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    ));

    return Scaffold(
      appBar: AppBar(
          title: const Text("Sirah Nabawiyah",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(children: items),
    );
  }
}

class _EventCard extends StatelessWidget {
  final SirahEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.year,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(event.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => SharePlus.instance.share(ShareParams(
                    text: "${event.title} (${event.year})\n\n${event.body}"
                        "\n\n— Sirah Nabawiyah, aplikasi Al-Quran")),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.share_outlined,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(event.body,
              style: const TextStyle(fontSize: 14.5, height: 1.55)),
        ],
      ),
    );
  }
}
