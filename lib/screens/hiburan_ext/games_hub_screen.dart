import 'package:flutter/material.dart';

import 'biliar_screen.dart';
import 'blackjack_screen.dart';
import 'catur_screen.dart';
import 'ular_tangga_screen.dart';

/// Pusat Game H2O — mandiri, tanpa server: Biliar, Catur,
/// Ular Tangga, dan Blackjack.
class GamesHubScreen extends StatelessWidget {
  const GamesHubScreen({super.key});

  static final _games = <(String, String, String, List<Color>,
      Widget Function())>[
    (
      '🎱',
      'Biliar',
      'Bola 8 — bidik dan sodok',
      [Color(0xFF0E7490), Color(0xFF16A34A)],
      () => const BiliarScreen(),
    ),
    (
      '♟️',
      'Catur',
      'Lawan komputer atau teman',
      [Color(0xFF334155), Color(0xFF0F172A)],
      () => const CaturScreen(),
    ),
    (
      '🐍',
      'Ular Tangga',
      'Papan klasik, 2-4 pemain',
      [Color(0xFF16A34A), Color(0xFF65A30D)],
      () => const UlarTanggaScreen(),
    ),
    (
      '🃏',
      'Blackjack 21',
      'Lawan bandar, kumpulkan 21',
      [Color(0xFF7C3AED), Color(0xFFDB2777)],
      () => const BlackjackScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Main sambil menunggu cucian 🧺',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final (emoji, title, subtitle, colors, builder)
                in _games)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => builder())),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 38)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill,
                            color: Colors.white, size: 34),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
