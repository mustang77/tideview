import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";

import "app_state.dart";

/// Digital dhikr counter with a persistent count and selectable target.
class TasbihScreen extends StatelessWidget {
  const TasbihScreen({super.key});

  static const _dhikr = [
    ("سُبْحَانَ اللَّهِ", "SubhanAllah"),
    ("الْحَمْدُ لِلَّهِ", "Alhamdulillah"),
    ("اللَّهُ أَكْبَرُ", "Allahu Akbar"),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = state.tasbihCount;
    final target = state.tasbihTarget;
    final lap = count % target;
    final rounds = count ~/ target;
    final phrase = _dhikr[rounds % _dhikr.length];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasbih",
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.flag_outlined),
            tooltip: "Target",
            onSelected: state.setTasbihTarget,
            itemBuilder: (_) => [33, 99, 100]
                .map((t) => PopupMenuItem(
                    value: t,
                    child: Text("Target $t${t == target ? "  ✓" : ""}")))
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reset",
            onPressed: () => state.setTasbihCount(0),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            phrase.$1,
            style: GoogleFonts.amiri(fontSize: 40, color: scheme.primary),
            textDirection: TextDirection.rtl,
          ),
          Text(phrase.$2,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
          const SizedBox(height: 8),
          Text("Round ${rounds + 1} • total $count",
              style: TextStyle(color: scheme.onSurfaceVariant)),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final next = count + 1;
                  if (next % target == 0) HapticFeedback.heavyImpact();
                  state.setTasbihCount(next);
                },
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B8A6B), Color(0xFF0B4437)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 216,
                        height: 216,
                        child: CircularProgressIndicator(
                          value: target == 0 ? 0 : lap / target,
                          strokeWidth: 6,
                          color: const Color(0xFFF2D488),
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("$lap",
                              style: const TextStyle(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text("of $target",
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Text("Tap the circle to count",
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
