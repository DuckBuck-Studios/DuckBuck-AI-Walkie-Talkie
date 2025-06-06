
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'call_screen_constants.dart';

/// Responsive caller name section widget with platform-specific styling
/// Adapts text size and layout based on screen dimensions
class CallerNameSection extends StatelessWidget {
  final String callerName;
  final bool isIOS;

  const CallerNameSection({
    super.key,
    required this.callerName,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    final nameMetrics = _getNameMetrics(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: nameMetrics.horizontalPadding,
        right: nameMetrics.horizontalPadding,
        top: nameMetrics.verticalPadding + 40, // Add extra top padding to move name down
        bottom: nameMetrics.verticalPadding,
      ),
      child: Text(
        callerName,
        style: _getNameTextStyle(context, nameMetrics, isIOS),
        textAlign: TextAlign.center,
        maxLines: nameMetrics.maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    )
    .animate()
    .fadeIn(duration: CallScreenConstants.fadeInDuration)
    .moveY(
      begin: -20, 
      end: 0, 
      duration: CallScreenConstants.fadeInDuration, 
      curve: Curves.easeOutQuad,
    )
    .shimmer(
      duration: CallScreenConstants.shimmerDuration, 
      delay: 1000.ms,
    );
  }

  /// Calculate responsive metrics based on screen size
  ({
    double fontSize,
    double horizontalPadding,
    double verticalPadding,
    double letterSpacing,
    int maxLines,
  }) _getNameMetrics(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    double fontSize;
    double horizontalPadding;
    double verticalPadding;
    double letterSpacing;
    int maxLines;
    
    if (screenWidth <= 320) {
      // iPhone SE (1st gen) and smaller
      fontSize = 24.0;
      horizontalPadding = 16.0;
      verticalPadding = 20.0;
      letterSpacing = 0.2;
      maxLines = 2;
    } else if (screenWidth <= 375) {
      // iPhone SE (2nd/3rd gen), iPhone 12 mini
      fontSize = 28.0;
      horizontalPadding = 20.0;
      verticalPadding = 24.0;
      letterSpacing = 0.3;
      maxLines = 2;
    } else if (screenWidth <= 390) {
      // iPhone 12, iPhone 13
      fontSize = 30.0;
      horizontalPadding = 24.0;
      verticalPadding = 28.0;
      letterSpacing = 0.4;
      maxLines = 2;
    } else if (screenWidth <= 414) {
      // iPhone 11, iPhone XR, iPhone 12/13 Pro Max
      fontSize = 32.0;
      horizontalPadding = 28.0;
      verticalPadding = 32.0;
      letterSpacing = 0.5;
      maxLines = 2;
    } else if (screenWidth <= 428) {
      // iPhone 14 Pro Max, iPhone 15 Pro Max
      fontSize = 34.0;
      horizontalPadding = 32.0;
      verticalPadding = 36.0;
      letterSpacing = 0.6;
      maxLines = 2;
    } else {
      // Larger screens (iPad, etc.)
      fontSize = 36.0;
      horizontalPadding = 40.0;
      verticalPadding = 40.0;
      letterSpacing = 0.8;
      maxLines = 1;
    }
    
    // Adjust for very small screens
    if (screenHeight < 600) {
      fontSize *= 0.9;
      verticalPadding *= 0.8;
    } else if (screenHeight < 700) {
      fontSize *= 0.95;
      verticalPadding *= 0.9;
    }
    
    return (
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      letterSpacing: letterSpacing,
      maxLines: maxLines,
    );
  }

  /// Generate platform-specific text style
  TextStyle _getNameTextStyle(
    BuildContext context,
    ({
      double fontSize,
      double horizontalPadding,
      double verticalPadding,
      double letterSpacing,
      int maxLines,
    }) metrics,
    bool isIOS,
  ) {
    final baseStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: metrics.fontSize,
      color: Colors.white,
      letterSpacing: metrics.letterSpacing,
      height: 1.2,
      shadows: [
        Shadow(
          offset: const Offset(0, 2),
          blurRadius: 6,
          color: Colors.black.withValues(alpha: CallScreenConstants.strongShadowOpacity),
        ),
        Shadow(
          offset: const Offset(0, 1),
          blurRadius: 3,
          color: Colors.black.withValues(alpha: CallScreenConstants.mediumShadowOpacity),
        ),
      ],
    );

    if (isIOS) {
      return CupertinoTheme.of(context)
          .textTheme
          .navLargeTitleTextStyle
          .copyWith(
            fontWeight: baseStyle.fontWeight,
            fontSize: baseStyle.fontSize,
            color: baseStyle.color,
            letterSpacing: baseStyle.letterSpacing,
            height: baseStyle.height,
            shadows: baseStyle.shadows,
          );
    }

    return baseStyle;
  }
}
