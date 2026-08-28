import 'package:flutter/material.dart';

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
    return MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const LoginScreen(),
    );
  }
}
