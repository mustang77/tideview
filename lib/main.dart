import "dart:async";
import "dart:ui";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "app_state.dart";
import "bookmarks_screen.dart";
import "dashboard_screen.dart";
import "home_screen.dart";
import "profile_screen.dart";
import "quran_search_screen.dart";
import "quran_service.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(AlQuranApp(state: state));
}

class AlQuranApp extends StatelessWidget {
  final AppState state;
  const AlQuranApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF166F5B),
      brightness: Brightness.light,
    );
    final lightTheme = ThemeData(
      colorScheme: lightScheme,
      scaffoldBackgroundColor: const Color(0xFFF6F3EB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F3EB),
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      useMaterial3: true,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3ECBA5),
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF101614));
    final darkTheme = ThemeData(
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF101614),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101614),
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      useMaterial3: true,
    );

    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: "Al-Quran",
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: state.themeMode,
          home: const SplashGate(),
        ),
      ),
    );
  }
}

/// Shows the branded splash for a moment on startup, then fades into the app.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _ready ? const RootShell() : const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Container(
      // Material ancestor so the splash text renders with proper styling.
      color: Colors.transparent,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B8A6B), Color(0xFF0B4437)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset("assets/branding/icon_fg.png", width: 220),
                  const SizedBox(height: 8),
                  const Text(
                    "Al-Quran",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Read • Listen • Reflect",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _quranService = QuranService();

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        service: _quranService,
        onOpenProfile: () => setState(() => _index = 4),
      ),
      HomeScreen(service: _quranService),
      QuranSearchScreen(service: _quranService),
      BookmarksScreen(service: _quranService),
      const ProfileScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _GlassNavBar(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Frosted-glass bottom bar in the style of the Cuit (wca_app) shell:
/// translucent blur with a hairline top border, hidden labels, no indicator
/// pill — unselected icons sit back at 40%, the selected one carries the
/// accent color.
class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _GlassNavBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white : Colors.black;
    final accent = Theme.of(context).colorScheme.primary;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF0B1512).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.60),
            border: Border(
              top: BorderSide(color: base.withValues(alpha: 0.08), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                indicatorShape: const RoundedRectangleBorder(),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: accent, size: 26);
                  }
                  return IconThemeData(
                    color: base.withValues(alpha: 0.40),
                    size: 26,
                  );
                }),
              ),
              child: NavigationBar(
                height: 56,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                selectedIndex: index,
                onDestinationSelected: onTap,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    label: "Home",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.menu_book_rounded),
                    label: "Quran",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    label: "Search",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bookmark_rounded),
                    label: "Bookmarks",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_rounded),
                    label: "Profile",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
