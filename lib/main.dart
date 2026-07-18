import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "search_screen.dart";
import "shorts_screen.dart";
import "banuba/ui/ar_studio_screen.dart";
import "editor/ui/editor_screen.dart";

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

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF9c6b26),
      scaffoldBackgroundColor: const Color(0xFFF3EFE6),
      useMaterial3: true,
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9c6b26),
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF0F0F0F));

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
      ),
      useMaterial3: true,
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
      const ARStudioScreen(),
      const EditorScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: "Shorts"),
          NavigationDestination(icon: Icon(Icons.face_retouching_natural), selectedIcon: Icon(Icons.face), label: "AR Studio"),
          NavigationDestination(icon: Icon(Icons.movie_creation_outlined), selectedIcon: Icon(Icons.movie_creation), label: "Editor"),
        ],
      ),
    );
  }
}
