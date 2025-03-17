import 'package:flutter/material.dart';
import 'package:neopop/neopop.dart';
import 'package:lottie/lottie.dart';

// Constants for button styling
const Duration kButtonAnimationDuration = Duration(milliseconds: 150);
const double kButtonDepth = 10;
const double kButtonBorderWidth = 1.5;

// Button colors
const Color kPrimaryButtonColor = Color(0xFF0A84FF);
const Color kSecondaryButtonLightColor = Color(0xFF2E3A59);
const Color kBorderColorGreen = Color(0xFF01F7FF);
const Color kBorderColorBlue = Color(0xFF0A84FF);
const Color kBorderColorRed = Color(0xFFFF3B30);
const Color kBorderColorGrey = Color(0xFFE0E0E0);

class DuckBuckButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final Color? bottomShadowColor;
  final Color? rightShadowColor;
  final Color borderColor;
  final Color textColor;
  final double width;
  final double height;
  final double depth;
  final double borderWidth;
  final String? lottieAsset;
  final bool isLoading;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Widget? icon;
  final MainAxisAlignment alignment;
  final TextStyle? textStyle;

  const DuckBuckButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.color = kPrimaryButtonColor,
    this.bottomShadowColor,
    this.rightShadowColor,
    this.borderColor = kBorderColorBlue,
    this.textColor = Colors.white,
    this.width = double.infinity,
    this.height = 50,
    this.depth = kButtonDepth,
    this.borderWidth = kButtonBorderWidth,
    this.lottieAsset,
    this.isLoading = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    this.margin = const EdgeInsets.symmetric(vertical: 8),
    this.icon,
    this.alignment = MainAxisAlignment.center,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate shadow colors if not provided
    final bottomShadow = bottomShadowColor ?? 
        ColorUtils.getVerticalShadow(borderColor);
    final rightShadow = rightShadowColor ?? 
        ColorUtils.getHorizontalShadow(borderColor);
    
    // Default text style
    final effectiveTextStyle = textStyle ?? 
        TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        );

    return Container(
      margin: margin,
      width: width,
      height: height,
      child: NeoPopButton(
        color: color,
        onTapUp: onTap,
        onTapDown: () {},
        bottomShadowColor: bottomShadow,
        rightShadowColor: rightShadow,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        depth: depth,
        animationDuration: kButtonAnimationDuration,
        child: Padding(
          padding: padding,
          child: isLoading
              ? Center(
                  child: SizedBox(
                    height: height * 0.6,
                    width: height * 0.6,
                    child: lottieAsset != null
                        ? Lottie.asset(lottieAsset!)
                        : CircularProgressIndicator(color: textColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: alignment,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lottieAsset != null) ...[
                      SizedBox(
                        height: height * 0.6,
                        width: height * 0.6,
                        child: Lottie.asset(lottieAsset!),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: effectiveTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      icon!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// Helper class for shadow color calculations
class ColorUtils {
  static Color getVerticalShadow(Color color) {
    final hslColor = HSLColor.fromColor(color);
    return hslColor.withLightness((hslColor.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }

  static Color getHorizontalShadow(Color color) {
    final hslColor = HSLColor.fromColor(color);
    return hslColor.withLightness((hslColor.lightness - 0.1).clamp(0.0, 1.0)).toColor();
  }
}

// Predefined button styles
class DuckBuckButtonStyles {
  // Primary button
  static DuckBuckButton primary({
    required String text,
    required VoidCallback onTap,
    String? lottieAsset,
    bool isLoading = false,
    double width = double.infinity,
    Widget? icon,
  }) {
    return DuckBuckButton(
      text: text,
      onTap: onTap,
      color: kPrimaryButtonColor,
      borderColor: kBorderColorBlue,
      textColor: Colors.white,
      lottieAsset: lottieAsset,
      isLoading: isLoading,
      width: width,
      icon: icon,
    );
  }

  // Success button
  static DuckBuckButton success({
    required String text,
    required VoidCallback onTap,
    String? lottieAsset,
    bool isLoading = false,
    double width = double.infinity,
    Widget? icon,
  }) {
    return DuckBuckButton(
      text: text,
      onTap: onTap,
      color: const Color(0xFF34C759),
      borderColor: kBorderColorGreen,
      textColor: Colors.white,
      lottieAsset: lottieAsset,
      isLoading: isLoading,
      width: width,
      icon: icon,
    );
  }

  // Danger button
  static DuckBuckButton danger({
    required String text,
    required VoidCallback onTap,
    String? lottieAsset,
    bool isLoading = false,
    double width = double.infinity,
    Widget? icon,
  }) {
    return DuckBuckButton(
      text: text,
      onTap: onTap,
      color: const Color(0xFFFF3B30),
      borderColor: kBorderColorRed,
      textColor: Colors.white,
      lottieAsset: lottieAsset,
      isLoading: isLoading,
      width: width,
      icon: icon,
    );
  }

  // Secondary button
  static DuckBuckButton secondary({
    required String text,
    required VoidCallback onTap,
    String? lottieAsset,
    bool isLoading = false,
    double width = double.infinity,
    Widget? icon,
  }) {
    return DuckBuckButton(
      text: text,
      onTap: onTap,
      color: kSecondaryButtonLightColor,
      borderColor: kBorderColorGrey,
      textColor: Colors.white,
      lottieAsset: lottieAsset,
      isLoading: isLoading,
      width: width,
      icon: icon,
    );
  }

  // Scan & Pay button (as per your example)
  static DuckBuckButton scanAndPay({
    required VoidCallback onTap,
    bool isLoading = false,
    String text = "Scan & Pay",
  }) {
    return DuckBuckButton(
      text: text,
      onTap: onTap,
      color: kSecondaryButtonLightColor,
      borderColor: kBorderColorGreen,
      isLoading: isLoading,
      icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
    );
  }

  // Outlined button
  static DuckBuckButton outlined({
    required String text,
    required VoidCallback onTap,
    Color borderColor = kBorderColorBlue,
    Color textColor = kPrimaryButtonColor,
    Widget? icon,
  }) {
    return DuckBuckButton(
      text: text,
      onTap: onTap,
      color: Colors.transparent,
      borderColor: borderColor,
      textColor: textColor,
      icon: icon,
    );
  }
}