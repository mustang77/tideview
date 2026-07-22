import "package:flutter/material.dart";

import "kitchen_screen.dart";
import "models.dart";
import "painters.dart";
import "storage.dart";

const Color kGameBg = Color(0xFF16324F);
const Color kGameBg2 = Color(0xFF1D4568);
const Color kAccent = Color(0xFFF2A03D);
const Color kAccentDark = Color(0xFFCB7E1F);
const Color kGood = Color(0xFF5FBF6E);

/// Root of the cooking game: animated title header + level map.
class GameHomeScreen extends StatefulWidget {
  const GameHomeScreen({super.key});

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen>
    with SingleTickerProviderStateMixin {
  final GameStorage _storage = GameStorage();
  bool _loaded = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _storage.init().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _play(LevelDef level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KitchenScreen(level: level, storage: _storage),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _loaded ? _storage.unlockedLevel : 1;
    return Scaffold(
      backgroundColor: kGameBg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kGameBg2, kGameBg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _header(),
              const SizedBox(height: 4),
              _statsRow(),
              const SizedBox(height: 8),
              Expanded(child: _levelGrid(unlocked)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: const SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(painter: ChefLogoPainter(kAccent)),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "TIDE KITCHEN",
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                shadows: [Shadow(color: Colors.black45, offset: Offset(0, 3))],
              ),
            ),
            Text(
              "Burger Rush",
              style: TextStyle(
                color: kAccent.withValues(alpha: 0.95),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C3E50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text("HOW TO PLAY",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 2)),
              ),
              const SizedBox(height: 14),
              _rule(Icons.local_fire_department_rounded,
                  "Tap RAW to grill a patty. Take it off when it glows green — leave it too long and it burns!"),
              _rule(Icons.lunch_dining_rounded,
                  "Tap BUN to start a plate, add the patty and toppings from the order, then tap TOP to finish."),
              _rule(Icons.room_service_rounded,
                  "Finished food waits on the SERVE shelf. Tap it to hand it to the first customer who ordered it."),
              _rule(Icons.timer_rounded,
                  "Serve before patience runs out. Fast service earns tips, and combos grow the tips!"),
              _rule(Icons.delete_rounded,
                  "Made a mistake? Long-press a plate or shelf item to throw it away."),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("GOT IT",
                      style: TextStyle(
                          color: kAccent, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rule(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13.5, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final stars = _loaded ? _storage.totalStars : 0;
    final coins = _loaded ? _storage.totalCoins : 0;
    final served = _loaded ? _storage.totalServed : 0;
    Widget chip(IconData icon, Color color, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(text,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chip(Icons.star_rounded, kAccent, "$stars / ${kLevels.length * 3}"),
          const SizedBox(width: 10),
          chip(Icons.monetization_on_rounded, const Color(0xFFF7D046),
              "$coins"),
          const SizedBox(width: 10),
          chip(Icons.people_alt_rounded, kGood, "$served"),
          const SizedBox(width: 10),
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showHowToPlay,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.question_mark_rounded,
                    color: Colors.white70, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelGrid(int unlocked) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.86,
      ),
      itemCount: kLevels.length,
      itemBuilder: (context, i) {
        final level = kLevels[i];
        final isUnlocked = level.id <= unlocked;
        final stars = _loaded ? _storage.starsFor(level.id) : 0;
        return _LevelTile(
          level: level,
          unlocked: isUnlocked,
          stars: stars,
          onTap: isUnlocked ? () => _play(level) : null,
        );
      },
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelDef level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unlocked
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unlocked
                  ? kAccent.withValues(alpha: 0.55)
                  : Colors.white12,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!unlocked)
                const Icon(Icons.lock_rounded, color: Colors.white24, size: 30)
              else
                Text(
                  "${level.id}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                unlocked ? level.title : "Locked",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unlocked ? Colors.white70 : Colors.white24,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (s) {
                  return Icon(
                    Icons.star_rounded,
                    size: 17,
                    color: s < stars
                        ? kAccent
                        : Colors.white.withValues(alpha: 0.15),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
