import 'package:flutter/material.dart';

import 'screens/login_screen.dart';

void main() => runApp(const H2OMailApp());

class H2OMailApp extends StatelessWidget {
  const H2OMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0288D1);
    return MaterialApp(
      title: 'H2O Mail',
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
