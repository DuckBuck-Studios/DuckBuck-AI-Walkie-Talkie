
/// Production-level constants for the call screen components
/// Centralizes all styling and animation constants for consistency
class CallScreenConstants {
  // Animation durations
  static const fadeInDuration = Duration(milliseconds: 600);
  static const shimmerDuration = Duration(milliseconds: 2000);
  static const scaleButtonDuration = Duration(milliseconds: 200);
  static const elasticButtonDuration = Duration(milliseconds: 300);
  static const imageTransitionDuration = Duration(milliseconds: 200);

  // Shadow opacities
  static const strongShadowOpacity = 0.8;
  static const mediumShadowOpacity = 0.4;
  static const lightShadowOpacity = 0.3;
  static const veryLightShadowOpacity = 0.15;

  // Gradient stops for overlay
  static const gradientStops = [0.0, 0.15, 0.5, 0.85, 1.0];

  // Border radius values
  static const borderRadius = 32.0;
  static const buttonBorderRadius = 28.0;

  // Layout constants
  static const bottomHeightFactor = 0.05;
  static const controlsOpacity = 0.65;
  static const controlsBorderOpacity = 0.12;
  static const backgroundIconOpacity = 0.8;
  static const backgroundIconLetterSpacing = 4.0;
  static const backgroundIconFontSize = 120.0;

  // Memory cache optimization
  static const memCacheWidth = 800;
  static const memCacheHeight = 1200;
}
