import "package:flutter/material.dart";

import "kitchen_screen.dart";
import "models.dart";
import "painters.dart";
import "sound.dart";
import "storage.dart";

const Color kGameBg = Color(0xFF16324F);
const Color kGameBg2 = Color(0xFF1D4568);
const Color kAccent = Color(0xFFF2A03D);
const Color kAccentDark = Color(0xFFCB7E1F);
const Color kGood = Color(0xFF5FBF6E);
const Color kBad = Color(0xFFE05B5B);

/// Root of the cooking game: header, lifetime stats, venue cards.
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
    Sfx.instance.init();
    _storage.init().then((_) {
      if (mounted) {
        setState(() => _loaded = true);
        Sfx.instance.enabled = _storage.soundOn;
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _openVenue(VenueDef venue) async {
    Sfx.instance.tap();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VenueLevelsScreen(venue: venue, storage: _storage),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 10),
              _header(),
              const SizedBox(height: 2),
              _statsRow(),
              const SizedBox(height: 4),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                  children: [
                    for (final venue in kVenues) ...[
                      _venueCard(venue),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
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
            width: 60,
            height: 60,
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
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                shadows: [Shadow(color: Colors.black45, offset: Offset(0, 3))],
              ),
            ),
            Text(
              "Three kitchens. One chef.",
              style: TextStyle(
                color: kAccent.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: color ?? Colors.white70, size: 18),
        ),
      ),
    );
  }

  Widget _statsRow() {
    final stars = _loaded ? _storage.totalStars : 0;
    final coins = _loaded ? _storage.totalCoins : 0;
    final soundOn = !_loaded || _storage.soundOn;
    Widget chip(IconData icon, Color color, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 5),
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
          chip(Icons.star_rounded, kAccent,
              "$stars / ${kVenues.length * 12 * 3}"),
          const SizedBox(width: 8),
          chip(Icons.monetization_on_rounded, const Color(0xFFF7D046),
              "$coins"),
          const SizedBox(width: 8),
          _iconButton(
            soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            () async {
              final v = !_storage.soundOn;
              await _storage.setSoundOn(v);
              Sfx.instance.enabled = v;
              if (v) Sfx.instance.tap();
              setState(() {});
            },
            color: soundOn ? Colors.white70 : Colors.white30,
          ),
          const SizedBox(width: 8),
          _iconButton(Icons.question_mark_rounded, () => _showHowToPlay()),
        ],
      ),
    );
  }

  Widget _venueCard(VenueDef venue) {
    final stars = _loaded ? _storage.venueStars(venue.id) : 0;
    final endlessOpen = _loaded && _storage.endlessUnlocked(venue.id);
    final best = _loaded ? _storage.endlessBest(venue.id) : 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openVenue(venue),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                venue.accent.withValues(alpha: 0.30),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: venue.accent.withValues(alpha: 0.6), width: 1.6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(painter: VenueEmblemPainter(venue.id)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(venue.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(venue.tagline,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            color: venue.accent, size: 18),
                        const SizedBox(width: 4),
                        Text("$stars / 36",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        const SizedBox(width: 12),
                        Icon(
                          endlessOpen
                              ? Icons.all_inclusive_rounded
                              : Icons.lock_rounded,
                          color: endlessOpen
                              ? venue.accent
                              : Colors.white24,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          endlessOpen ? "Best $best" : "Endless",
                          style: TextStyle(
                              color: endlessOpen
                                  ? Colors.white
                                  : Colors.white30,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white54, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowToPlay() {
    Sfx.instance.tap();
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
              _rule(Icons.receipt_long_rounded,
                  "Customers show their order in a bubble. Serve every item before their patience bar empties."),
              _rule(Icons.local_fire_department_rounded,
                  "Burger Bar: grill patties and take them off while they glow — too long and they burn."),
              _rule(Icons.local_pizza_rounded,
                  "Pizza Palace: build dough, sauce, cheese and toppings, then bake it in the stone oven."),
              _rule(Icons.set_meal_rounded,
                  "Sushi Dock: layer nori, rice and fillings, then roll it on the mat. Fresh fish never burns!"),
              _rule(Icons.room_service_rounded,
                  "Finished food waits on the SERVE shelf — tap it to hand it to whoever ordered it."),
              _rule(Icons.timer_rounded,
                  "Quick service earns tips and combos. Long-press a plate or shelf item to bin a mistake."),
              _rule(Icons.all_inclusive_rounded,
                  "Beat the first four levels of a venue to unlock its Endless Rush. Three walk-outs end the run."),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kAccent, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// Level map for one venue, plus its endless-mode card.
class VenueLevelsScreen extends StatefulWidget {
  final VenueDef venue;
  final GameStorage storage;
  const VenueLevelsScreen(
      {super.key, required this.venue, required this.storage});

  @override
  State<VenueLevelsScreen> createState() => _VenueLevelsScreenState();
}

class _VenueLevelsScreenState extends State<VenueLevelsScreen> {
  Future<void> _play(LevelDef level) async {
    Sfx.instance.tap();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KitchenScreen(level: level, storage: widget.storage),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final venue = widget.venue;
    final levels = levelsFor(venue.id);
    final unlocked = widget.storage.unlockedLevel(venue.id);
    final endlessOpen = widget.storage.endlessUnlocked(venue.id);
    final best = widget.storage.endlessBest(venue.id);

    return Scaffold(
      backgroundColor: kGameBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(venue.accent.withValues(alpha: 0.25), kGameBg2),
              kGameBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                    ),
                    SizedBox(
                      width: 46,
                      height: 46,
                      child:
                          CustomPaint(painter: VenueEmblemPainter(venue.id)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(venue.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900)),
                          Text(venue.tagline,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.star_rounded, color: venue.accent, size: 20),
                    Text(" ${widget.storage.venueStars(venue.id)}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _endlessCard(endlessOpen, best),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: levels.length,
                  itemBuilder: (context, i) {
                    final level = levels[i];
                    final isUnlocked = level.id <= unlocked;
                    final stars =
                        widget.storage.starsFor(venue.id, level.id);
                    return _LevelTile(
                      level: level,
                      accent: venue.accent,
                      unlocked: isUnlocked,
                      stars: stars,
                      onTap: isUnlocked ? () => _play(level) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _endlessCard(bool open, int best) {
    final venue = widget.venue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: open
            ? venue.accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: open ? () => _play(endlessLevel(venue.id)) : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: open
                    ? venue.accent.withValues(alpha: 0.7)
                    : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  open ? Icons.all_inclusive_rounded : Icons.lock_rounded,
                  color: open ? venue.accent : Colors.white24,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ENDLESS RUSH",
                          style: TextStyle(
                              color: open ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14)),
                      Text(
                        open
                            ? "Survive the never-ending queue. 3 walk-outs and it's over."
                            : "Beat level 4 to unlock.",
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (open)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("BEST",
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                      Text("$best",
                          style: TextStyle(
                              color: venue.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final LevelDef level;
  final Color accent;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.accent,
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
              color:
                  unlocked ? accent.withValues(alpha: 0.55) : Colors.white12,
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
                        ? accent
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
