import "package:flutter/material.dart";
import "search_screen.dart";

void main() => runApp(const TideViewApp());

class TideViewApp extends StatelessWidget {
  const TideViewApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "TideView",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF9c6b26), useMaterial3: true),
      home: const SearchScreen(),
    );
  }
}
