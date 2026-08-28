import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'util/brand.dart';
import 'util/notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  runApp(const H2OMailApp());
}

class H2OMailApp extends StatelessWidget {
  const H2OMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0288D1);
    final lightText = GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.light).textTheme);
    final darkText = GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme);
    return MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
        textTheme: lightText,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: darkText,
      ),
      themeMode: ThemeMode.system,
      home: const LoginScreen(),
    );
  }
}
