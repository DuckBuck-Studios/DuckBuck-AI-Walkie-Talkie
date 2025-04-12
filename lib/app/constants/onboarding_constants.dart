import 'package:flutter/material.dart';

class OnboardingConstants {
  // Logo dimensions
  static const double logoSize = 180.0;
  static const double logoPadding = 25.0;
  static const double logoShadowBlur = 20.0;
  static const double logoShadowSpread = 5.0;
  static const double logoShadowOpacity = 0.3;
  static const double logoShadowOffset = 10.0;

  // Text styles
  static const TextStyle titleStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static const TextStyle featureTextStyle = TextStyle(
    fontSize: 18,
    color: Colors.white,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  // Feature icon container
  static const double featureIconContainerSize = 42.0;
  static const double featureIconBorderRadius = 14.0;
  static const double featureIconShadowBlur = 8.0;
  static const double featureIconShadowSpread = 1.0;
  static const double featureIconShadowOpacity = 0.1;
  static const double featureIconShadowOffset = 4.0;
  static const double featureIconSize = 22.0;

  // Spacing
  static const double horizontalPadding = 30.0;
  static const double verticalSpacing = 16.0;
  static const double featureSpacing = 20.0;
  static const double iconTextSpacing = 14.0;

  // Animation durations
  static const Duration logoFadeInDuration = Duration(milliseconds: 700);
  static const Duration logoScaleDuration = Duration(milliseconds: 700);
  static const Duration titleFadeInDuration = Duration(milliseconds: 600);
  static const Duration titleSlideDuration = Duration(milliseconds: 600);
  static const Duration shimmerDuration = Duration(milliseconds: 2200);
  static const Duration featureFadeInDuration = Duration(milliseconds: 600);
  static const Duration featureScaleDuration = Duration(milliseconds: 600);

  // Animation delays
  static const Duration logoFadeInDelay = Duration(milliseconds: 300);
  static const Duration titleFadeInDelay = Duration(milliseconds: 200);
  static const Duration shimmerDelay = Duration(milliseconds: 1500);
  static const Duration featureBaseDelay = Duration(milliseconds: 400);
  static const Duration featureStaggerDelay = Duration(milliseconds: 150);

  // Background elements
  static const double backgroundElementOpacity = 0.2;
  static const double backgroundElementBlur = 20.0;
  static const double backgroundElementSpread = 5.0;
  static const double backgroundElementOffset = 10.0;

  // Responsive layout
  static double getLogoTopPadding(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.08;
  }

  static double getBottomSpacing(BuildContext context) {
    return MediaQuery.of(context).size.height * 0.1;
  }

  // Platform-specific styles
  static TextStyle getPlatformSpecificTitleStyle(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return titleStyle.copyWith(
        fontSize: 38,
        fontWeight: FontWeight.w600,
      );
    }
    return titleStyle;
  }

  static TextStyle getPlatformSpecificSubtitleStyle(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return subtitleStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w400,
      );
    }
    return subtitleStyle;
  }
} 