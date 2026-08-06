import "dart:async";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_state.dart";
import "duas_screen.dart";
import "prayer_times_screen.dart";
import "quran_data.dart";
import "quran_service.dart";
import "sirah_screen.dart";
import "surah_screen.dart";
import "tahlil_screen.dart";
import "tasbih_screen.dart";

/// Dashboard home: hero header with Hijri date, city and next-prayer
/// countdown, then quick actions into the rest of the app.
class DashboardScreen extends StatefulWidget {
  final QuranService service;
  final VoidCallback onOpenProfile;
  const DashboardScreen(
      {super.key, required this.service, required this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _prayerService = PrayerTimesService();
  PrayerTimesResult? _times;
  String _loadedCity = "";
  bool _loading = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Re-render the countdown every 30 seconds.
    _ticker = Timer.periodic(
        const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // City may have changed (AppScope notifies); fetch outside of build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetch());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _maybeFetch() async {
    if (!mounted) return;
    final state = AppScope.of(context);
    final city = state.prayerCity;
    if (city.isEmpty || city == _loadedCity || _loading) return;
    setState(() => _loading = true);
    try {
      final t = await _prayerService.byCity(city, state.prayerCountry);
      if (!mounted) return;
      setState(() {
        _times = t;
        _loadedCity = city;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _askCity() async {
    final state = AppScope.of(context);
    final cityController = TextEditingController(text: state.prayerCity);
    final countryController = TextEditingController(text: state.prayerCountry);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Your location"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: "City"),
            ),
            TextField(
              controller: countryController,
              decoration: const InputDecoration(labelText: "Country"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("Save")),
        ],
      ),
    );
    if (saved == true && mounted) {
      AppScope.of(context).setPrayerLocation(
          cityController.text.trim(), countryController.text.trim());
      _loadedCity = "";
      _maybeFetch();
    }
  }

  void _openSurah(int surah) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SurahScreen(service: widget.service, surahNumber: surah),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lastRead = state.lastRead;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            times: _times,
            city: state.prayerCity,
            userName: state.userName,
            loading: _loading,
            onPickCity: _askCity,
            onOpenProfile: widget.onOpenProfile,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text("Quick start",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            childAspectRatio: 0.95,
            children: [
              _Action(
                icon: Icons.auto_stories,
                label: "Last read",
                subtitle: lastRead == null
                    ? "—"
                    : "${surahByNumber(lastRead.surah).nameEnglish} ${lastRead.ayah}",
                onTap: lastRead == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SurahScreen(
                              service: widget.service,
                              surahNumber: lastRead.surah,
                              scrollToAyah: lastRead.ayah),
                        )),
              ),
              _Action(
                  icon: Icons.menu_book,
                  label: "Ya-Sin",
                  subtitle: "Surah 36",
                  onTap: () => _openSurah(36)),
              _Action(
                  icon: Icons.nightlight_round,
                  label: "Al-Mulk",
                  subtitle: "Surah 67",
                  onTap: () => _openSurah(67)),
              _Action(
                  icon: Icons.history_edu,
                  label: "Sirah Nabi",
                  subtitle: "Kisah Rasulullah ﷺ",
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SirahScreen()))),
              _Action(
                  icon: Icons.landscape,
                  label: "Al-Kahf",
                  subtitle: "Surah 18",
                  onTap: () => _openSurah(18)),
              _Action(
                  icon: Icons.article,
                  label: "Tahlil",
                  subtitle: "NU Online",
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TahlilScreen()))),
              _Action(
                  icon: Icons.pan_tool_alt,
                  label: "Duas",
                  subtitle: "Daily prayers",
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DuasScreen()))),
              _Action(
                  icon: Icons.radio_button_checked,
                  label: "Tasbih",
                  subtitle: "Dhikr counter",
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TasbihScreen()))),
              _Action(
                  icon: Icons.schedule,
                  label: "Prayer times",
                  subtitle: "Full schedule",
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PrayerTimesScreen()))),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final PrayerTimesResult? times;
  final String city;
  final String userName;
  final bool loading;
  final VoidCallback onPickCity;
  final VoidCallback onOpenProfile;

  const _Hero({
    required this.times,
    required this.city,
    required this.userName,
    required this.loading,
    required this.onPickCity,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = times?.nextPrayer(now);
    String big = "As-salamu alaykum";
    String small = "";
    if (times != null) {
      if (next != null) {
        big = "${next.$1}, ${next.$2}";
        final parts = next.$2.split(":");
        final when = DateTime(now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        final diff = when.difference(now);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        small = h > 0 ? "in $h h $m min" : "in $m min";
      } else {
        final fajr = times!.timings["Fajr"];
        big = "Isha has passed";
        small = fajr == null ? "" : "Fajr tomorrow at $fajr";
      }
    }

    final hijriLine = times == null
        ? "Al-Quran"
        : [
            if (times!.hijriWeekday.isNotEmpty) times!.hijriWeekday,
            times!.hijriDate.replaceAll(" AH", " H"),
          ].join(", ");

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B8A6B), Color(0xFF0B4437)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _MosquePainter()),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hijriLine,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onOpenProfile,
                        icon: userName.isEmpty
                            ? const Icon(Icons.account_circle,
                                color: Colors.white, size: 30)
                            : CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.white,
                                child: Text(
                                  userName.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                      color: Color(0xFF0B4437),
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: onPickCity,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_outlined,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            city.isEmpty ? "Set your city" : city,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else ...[
                    Text(
                      big,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (small.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(small,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft mosque silhouette + crescent, like a watermark behind the hero text.
class _MosquePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final w = size.width;
    final h = size.height;
    final base = h * 0.98;

    final path = Path()..moveTo(0, base);
    // left minaret
    path.lineTo(w * 0.08, base);
    path.lineTo(w * 0.08, h * 0.45);
    path.lineTo(w * 0.10, h * 0.38);
    path.lineTo(w * 0.12, h * 0.45);
    path.lineTo(w * 0.12, base);
    // left small dome
    path.lineTo(w * 0.20, base);
    path.arcTo(Rect.fromCircle(center: Offset(w * 0.28, base), radius: w * 0.08),
        3.14159, 3.14159, false);
    // central big dome
    path.lineTo(w * 0.36, base);
    path.arcTo(Rect.fromCircle(center: Offset(w * 0.52, base), radius: w * 0.16),
        3.14159, 3.14159, false);
    // right small dome
    path.lineTo(w * 0.72, base);
    path.arcTo(Rect.fromCircle(center: Offset(w * 0.78, base), radius: w * 0.08),
        3.14159, 3.14159, false);
    // right minaret
    path.lineTo(w * 0.88, base);
    path.lineTo(w * 0.88, h * 0.45);
    path.lineTo(w * 0.90, h * 0.38);
    path.lineTo(w * 0.92, h * 0.45);
    path.lineTo(w * 0.92, base);
    path.lineTo(w, base);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    canvas.drawPath(path, paint);

    // crescent glow top-left
    final glow = Paint()..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(Offset(w * 0.30, h * 0.22), w * 0.09, glow);
    final cut = Paint()
      ..color = const Color(0xFF15745A)
      ..blendMode = BlendMode.srcOver;
    canvas.drawCircle(Offset(w * 0.33, h * 0.19), w * 0.075, cut);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _Action(
      {required this.icon,
      required this.label,
      required this.subtitle,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: onTap == null
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                      size: 24),
                ),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
