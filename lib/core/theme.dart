import 'package:flutter/material.dart';

/// Theme de l'application (couleurs militaires sobres).
class AppTheme {
  static const Color olive = Color(0xFF4B5320);
  static const Color green = Color(0xFF2E7D32);
  static const Color amber = Color(0xFFF9A825);
  static const Color red = Color(0xFFC62828);
  static const Color slate = Color(0xFF37474F);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: slate,
        primary: slate,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F5F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: slate,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
