import 'package:flutter/material.dart';

/// App color palette for consistent theming throughout the app
class AppColors {
  // Primary black theme colors
  static const Color primaryBlack = Color(0xFF000000);
  static const Color surfaceBlack = Color(0xFF000000);
  static const Color backgroundBlack = Color(0xFF000000);
  
  // Pure colors
  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color black87 = Color(0xDD000000); // 87% opacity black

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
  static const Color destructiveRed = Color(0xFFFF453A); // iOS destructive red
  static const Color successGreen = Color(0xFF00FF66); // Green for success
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color infoBlue = Color(0xFF00FFAA); // Lighter green for info

  // Transparent colors for overlays
  static Color blackOpacity10 = Colors.black.withValues(alpha: 0.1);
  static Color blackOpacity20 = Colors.black.withValues(alpha: 0.2);
  static Color blackOpacity30 = Colors.black.withValues(alpha: 0.3);
  static Color blackOpacity50 = Colors.black.withValues(alpha: 0.5);
  static Color blackOpacity70 = Colors.black.withValues(alpha: 0.7);
  static Color blackOpacity80 = Colors.black.withValues(alpha: 0.8);
  
  static Color whiteOpacity08 = Colors.white.withValues(alpha: 0.08);
  static Color whiteOpacity10 = Colors.white.withValues(alpha: 0.1);
  static Color whiteOpacity15 = Colors.white.withValues(alpha: 0.15);
  static Color whiteOpacity20 = Colors.white.withValues(alpha: 0.2);
  static Color whiteOpacity30 = Colors.white.withValues(alpha: 0.3);
  static Color whiteOpacity50 = Colors.white.withValues(alpha: 0.5);
  static Color whiteOpacity54 = Colors.white.withValues(alpha: 0.54);
  static Color whiteOpacity70 = Colors.white.withValues(alpha: 0.7);
  static Color whiteOpacity80 = Colors.white.withValues(alpha: 0.8);
  
  static Color accentBlueOpacity30 = accentBlue.withValues(alpha: 0.3);
  static Color accentBlueOpacity50 = accentBlue.withValues(alpha: 0.5);
  
  // Additional colors for AI agent UI
  static Color accentBlueOpacity20 = accentBlue.withValues(alpha: 0.2);
  static Color accentBlueOpacity40 = accentBlue.withValues(alpha: 0.4);
  static Color accentBlueOpacity60 = accentBlue.withValues(alpha: 0.6);
  static Color accentBlueOpacity80 = accentBlue.withValues(alpha: 0.8);
  
  // Gradient colors for buttons
  static const Color gradientStart = Color(0xFF00FF66); // Main green
  static const Color gradientMiddle = Color(0xFF00CC55); // Darker green
  static const Color gradientEnd = Color(0xFF00FFAA); // Lighter green
  
  // Loading and progress colors
  static const Color loadingGreen = Color(0xFF00FF66);
  static const Color loadingDark = Color(0xFF00AA44);
  
  // Call control colors
  static const Color callEndRed = Color(0xFFFF453A);
  static const Color callMuteRed = Color(0xFFCF6679);
  static const Color callSpeakerGreen = Color(0xFF00FF66);
  
  // Wave animation colors
  static Color waveColor1 = accentBlue.withValues(alpha: 0.6);
  static Color waveColor2 = accentBlue.withValues(alpha: 0.4);
  static Color waveColor3 = accentBlue.withValues(alpha: 0.2);
  static Color wavePulse = Color(0xFF00FFAA).withValues(alpha: 0.8);
}
