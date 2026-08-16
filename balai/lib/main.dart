import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'screens/gerbang_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setelan Firebase dibaca dari android/app/google-services.json (Android)
  // dan web/index.html (web). Lihat README untuk cara membuatnya.
  await Firebase.initializeApp();

  runApp(const BalaiApp());
}

class BalaiApp extends StatefulWidget {
  const BalaiApp({super.key});

  /// Mengganti mode tampilan dari layar mana pun, tanpa perlu pustaka
  /// pengelola keadaan hanya untuk satu setelan.
  static void ubahTampilan(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_BalaiAppState>()?._setMode(mode);
  }

  static ThemeMode tampilanSekarang(BuildContext context) {
    return context.findAncestorStateOfType<_BalaiAppState>()?._mode ??
        ThemeMode.system;
  }

  @override
  State<BalaiApp> createState() => _BalaiAppState();
}

class _BalaiAppState extends State<BalaiApp> {
  ThemeMode _mode = ThemeMode.system;

  void _setMode(ThemeMode mode) => setState(() => _mode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${BalaiConfig.namaAplikasi} ${BalaiConfig.namaDesa}',
      debugShowCheckedModeBanner: false,
      theme: BalaiThemeData.terang(),
      darkTheme: BalaiThemeData.gelap(),
      themeMode: _mode,
      home: const GerbangScreen(),
    );
  }
}
