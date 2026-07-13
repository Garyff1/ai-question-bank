import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Color color) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.18,
        fontWeight: FontWeight.w900,
        color: color,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.2,
        fontWeight: FontWeight.w900,
        color: color,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w800,
        color: color,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: color),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: color),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: color),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}
