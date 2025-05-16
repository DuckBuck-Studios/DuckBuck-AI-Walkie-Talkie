import 'package:flutter/material.dart';

/// App color palette for consistent theming throughout the app
class AppColors {
  // Primary black theme colors
  static const Color primaryBlack = Color(0xFF000000);
  static const Color surfaceBlack = Color(0xFF000000);
  static const Color backgroundBlack = Color(0xFF000000);

  // Accent colors for the black theme
  static const Color accentBlue = Color(0xFF00FF66); // Green accent
  static const Color accentPurple = Color(0xFF00CC55); // Darker green variant
  static const Color accentTeal = Color(0xFF00FFAA); // Lighter green variant

  // Text colors for the black theme
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF8A8A8A);

  // Border colors
  static const Color borderColor = Color(0xFF00FF66); // Green border

  // Utility colors
  static const Color errorRed = Color(0xFFCF6679);
  static const Color successGreen = Color(0xFF00FF66); // Green for success
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color infoBlue = Color(0xFF00FFAA); // Lighter green for info

  // Transparent colors for overlays
  static Color blackOpacity10 = Colors.black.withValues(alpha: 0.1);
  static Color blackOpacity20 = Colors.black.withValues(alpha: 0.2);
  static Color blackOpacity50 = Colors.black.withValues(alpha: 0.5);
  static Color whiteOpacity10 = Colors.white.withValues(alpha: 0.1);
  static Color whiteOpacity20 = Colors.white.withValues(alpha: 0.2);
  static Color whiteOpacity50 = Colors.white.withValues(alpha: 0.5);
}
