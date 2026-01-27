import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors (from Figma design)
  static const Color primary = Color(0xFF4CD964); // Green from design
  static const Color primaryLight = Color(0xFF7EE08F);
  static const Color primaryDark = Color(0xFF34C759);

  // Accent Colors
  static const Color accent = Color(0xFF5AC8FA); // Blue operator buttons
  static const Color accentLight = Color(0xFF7DD4FB);
  static const Color accentDark = Color(0xFF32B5F5);

  // Transaction Colors
  static const Color income = Color(0xFF4CD964); // Green
  static const Color expense = Color(0xFFFF3B30); // Red

  // Numpad Colors (Dark theme)
  static const Color numpadBackground = Color(0xFF1C1C1E);
  static const Color numpadButton = Color(0xFF2C2C2E);
  static const Color numpadButtonLight = Color(0xFF3A3A3C);
  static const Color numpadOperator = Color(0xFF5AC8FA);
  static const Color numpadEquals = Color(0xFF4CD964);

  // Background Colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color card = Colors.white;
  static const Color cardDark = Color(0xFF2C2C2C);

  // Text Colors - Made more visible
  static const Color textPrimary = Color(0xFF1A1A1A);      // Darker for better readability
  static const Color textSecondary = Color(0xFF636E72);    // Stronger grey
  static const Color textTertiary = Color(0xFF95A5A6);     // For less important text
  static const Color textHint = Color(0xFFB2BEC3);
  static const Color textOnPrimary = Colors.white;
  static const Color textPrimaryDark = Color(0xFFF5F5F5);  // Brighter in dark mode
  static const Color textSecondaryDark = Color(0xFFB2BEC3);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color dividerDark = Color(0xFF373737);

  // Category Colors
  static const List<Color> categoryColors = [
    Color(0xFFE53935), // Red
    Color(0xFFD81B60), // Pink
    Color(0xFF8E24AA), // Purple
    Color(0xFF5E35B1), // Deep Purple
    Color(0xFF3949AB), // Indigo
    Color(0xFF1E88E5), // Blue
    Color(0xFF00ACC1), // Cyan
    Color(0xFF00897B), // Teal
    Color(0xFF43A047), // Green
    Color(0xFF7CB342), // Light Green
    Color(0xFFC0CA33), // Lime
    Color(0xFFFDD835), // Yellow
    Color(0xFFFFB300), // Amber
    Color(0xFFFB8C00), // Orange
    Color(0xFFF4511E), // Deep Orange
    Color(0xFF6D4C41), // Brown
  ];

  // Chart Colors (Statistics screen)
  static const List<Color> chartColors = [
    Color(0xFF4CD964), // Green - Primary
    Color(0xFFFFCC00), // Yellow
    Color(0xFFFF9500), // Orange
    Color(0xFFFF3B30), // Red
    Color(0xFF5AC8FA), // Blue
    Color(0xFFAF52DE), // Purple
    Color(0xFF00C7BE), // Teal
    Color(0xFF8E8E93), // Gray
  ];

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF4CD964), Color(0xFF34C759)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFF3B30), Color(0xFFFF2D55)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
