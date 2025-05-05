import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Consistent styles for commonly used widgets across the app
class WidgetStyles {
  // Private constructor to prevent instantiation
  WidgetStyles._();

  /// Logo container style
  static BoxDecoration logoContainerDecoration = BoxDecoration(
    color: AppColors.whiteOpacity20,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: AppColors.blackOpacity20,
        blurRadius: 10,
        spreadRadius: 2,
      ),
    ],
  );

  /// Content container style
  static BoxDecoration contentContainerDecoration = BoxDecoration(
    color: AppColors.whiteOpacity10,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: AppColors.blackOpacity10,
        blurRadius: 8,
        spreadRadius: 1,
      ),
    ],
  );

  /// Slider style for welcome screen
  static BoxDecoration sliderContainerDecoration = BoxDecoration(
    color: AppColors.whiteOpacity20,
    borderRadius: BorderRadius.circular(16),
  );

  /// Common padding values
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: 24.0,
    vertical: 16.0,
  );
  static const EdgeInsets contentPadding = EdgeInsets.all(16.0);
  static const EdgeInsets itemSpacing = EdgeInsets.symmetric(vertical: 12.0);

  /// Common text styles
  static const TextStyle titleStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    height: 1.5,
  );

  static const TextStyle captionStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
  );

  static const TextStyle smallTextStyle = TextStyle(
    color: AppColors.textTertiary,
    fontSize: 12,
  );

  /// Button text styles
  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  /// Common sizes
  static Size logoSize(Size screenSize) =>
      Size(screenSize.width * 0.25, screenSize.width * 0.25);
  static Size illustrationSize(Size screenSize) =>
      Size(screenSize.width * 0.7, screenSize.height * 0.3);
}
