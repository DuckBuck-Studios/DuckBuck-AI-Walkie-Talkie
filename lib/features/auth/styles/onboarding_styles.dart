import 'package:flutter/material.dart';

/// Styles for onboarding screens
///
/// This class contains static methods and properties to define
/// consistent styling across all onboarding screens.
class OnboardingStyles {
  // Private constructor to prevent instantiation
  OnboardingStyles._();

  // Colors
  static const Color lightBlue = Color(0xFF4FABF7);
  static const Color darkBlue = Color(0xFF1565C0);
  static const Color purple = Color(0xFF673AB7);
  static const Color deepPurple = Color(0xFF4527A0);
  static const Color teal = Color(0xFF009688);
  static const Color deepTeal = Color(0xFF00695C);

  /// Logo size based on screen size
  static Size logoSize(Size screenSize) {
    final width = screenSize.width * 0.28;
    return Size(width, width);
  }

  /// Gradient background for all onboarding screens
  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.black,
      Colors.black.withOpacity(0.9),
      const Color(0xFF1A1A1A),
    ],
  );

  // Gradients for each onboarding screen
  static List<Color> gradientScreen1(bool isDarkMode) =>
      isDarkMode
          ? [deepPurple, purple.withOpacity(0.8), purple.withOpacity(0.6)]
          : [purple, purple.withOpacity(0.8), purple.withOpacity(0.6)];

  static List<Color> gradientScreen2(bool isDarkMode) =>
      isDarkMode
          ? [darkBlue, lightBlue.withOpacity(0.7), lightBlue.withOpacity(0.5)]
          : [lightBlue, lightBlue.withOpacity(0.7), lightBlue.withOpacity(0.5)];

  static List<Color> gradientScreen3(bool isDarkMode) =>
      isDarkMode
          ? [deepTeal, teal.withOpacity(0.7), teal.withOpacity(0.5)]
          : [teal, teal.withOpacity(0.7), teal.withOpacity(0.5)];

  /// Title text style
  static const TextStyle titleStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1,
  );

  /// Subtitle text style
  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 18,
    color: Colors.white70,
    letterSpacing: 0.5,
    height: 1.5,
  );

  // Text styles
  static const TextStyle descriptionStyle = TextStyle(
    color: Colors.white70,
    fontSize: 16,
    height: 1.5,
  );

  // Logo styling
  static BoxDecoration logoDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.2),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        spreadRadius: 2,
      ),
    ],
  );

  /// Button style for primary actions
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    elevation: 0,
  );

  /// Button style for secondary actions
  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Colors.white, width: 1.5),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    elevation: 0,
  );

  // Button styling
  static ButtonStyle socialButtonStyle() => OutlinedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(0.1),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    side: const BorderSide(color: Colors.white54, width: 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  );

  // Container sizing
  static Size illustrationSize(Size screenSize) =>
      Size(screenSize.width * 0.7, screenSize.height * 0.3);
}
