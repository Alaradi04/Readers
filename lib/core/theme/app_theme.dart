import 'package:flutter/material.dart';

class AppTheme {
  static const ink = Color(0xFF18201D);
  static const forest = Color(0xFF1D5B4A);
  static const mint = Color(0xFFE7F2EB);
  static const cream = Color(0xFFFAF8F2);
  static const coral = Color(0xFFE9795F);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: forest, brightness: Brightness.light, surface: cream),
        fontFamily: 'Georgia',
        appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: ink, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: mint,
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'Georgia')),
        ),
      );
}