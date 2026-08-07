import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";
import "search_screen.dart";
import "shorts_screen.dart";

// Brand accent (app seed colour).
const Color kGold = Color(0xFF9C6B26);
const Color kGoldLight = Color(0xFFE8C77E);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow all orientations so the player can rotate to landscape in fullscreen.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TideViewApp());
}

class TideViewApp extends StatefulWidget {
  const TideViewApp({super.key});
  @override
  State<TideViewApp> createState() => _TideViewAppState();
}

class _TideViewAppState extends State<TideViewApp> {
  ThemeMode _mode = ThemeMode.system;

  void _toggle() {
    setState(() {
      final isDark = _mode == ThemeMode.dark ||
          (_mode == ThemeMode.system &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
      _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  // Apply a clean, modern typeface across the whole app.
  TextTheme _fonts(TextTheme base) => GoogleFonts.plusJakartaSansTextTheme(base);

  NavigationBarThemeData _navTheme(Color surface, Color onSurface) {
    return NavigationBarThemeData(
      height: 64,
      backgroundColor: surface,
      elevation: 0,
      indicatorColor: kGold.withValues(alpha: 0.20),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? kGoldLight : onSurface.withValues(alpha: 0.6),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? kGoldLight : onSurface.withValues(alpha: 0.6),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseLight = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: kGold,
      scaffoldBackgroundColor: const Color(0xFFF3EFE6),
      useMaterial3: true,
    );
    final lightTheme = baseLight.copyWith(
      textTheme: _fonts(baseLight.textTheme),
      navigationBarTheme: _navTheme(const Color(0xFFF3EFE6), const Color(0xFF1A1A1A)),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF3EFE6),
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: kGold,
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF0F0F0F));

    final baseDark = ThemeData(
      brightness: Brightness.dark,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      useMaterial3: true,
    );
    final darkTheme = baseDark.copyWith(
      textTheme: _fonts(baseDark.textTheme),
      navigationBarTheme: _navTheme(const Color(0xFF0D0D0D), Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );

    return MaterialApp(
      title: "TideView",
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _mode,
      home: RootShell(onToggleTheme: _toggle),
    );
  }
}

class RootShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const RootShell({super.key, required this.onToggleTheme});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      SearchScreen(onToggleTheme: widget.onToggleTheme),
      const ShortsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: "Shorts"),
        ],
      ),
    );
  }
}
