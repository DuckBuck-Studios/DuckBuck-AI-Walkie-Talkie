import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../constants/onboarding_constants.dart';
import '../../../widgets/painters/dot_pattern_painter.dart';
import '../../../widgets/painters/wave_painter.dart';
import 'dart:math' as math;

abstract class BaseOnboardingScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final Size screenSize;

  const BaseOnboardingScreen({
    super.key,
    required this.data,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getOptimizedGradient(data['gradient'] as LinearGradient),
      ),
      width: MediaQuery.of(context).size.width,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Background elements with RepaintBoundary
            RepaintBoundary(
              child: _BackgroundElements(screenSize: screenSize),
            ),
            
            // Main content
            Column(
              children: [
                SizedBox(height: OnboardingConstants.getLogoTopPadding(context)),
                
                // App logo with optimized image loading
                _buildLogo(context),
                
                const Spacer(),
                
                // Content area with optimized feature list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: OnboardingConstants.horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with platform-specific styling
                      Text(
                        data['title'],
                        style: _getPlatformSpecificTitleStyle(context),
                        textAlign: TextAlign.start,
                      ),
                      
                      SizedBox(height: OnboardingConstants.verticalSpacing),
                      
                      // Subtitle with platform-specific styling
                      Text(
                        data['subtitle'],
                        style: _getPlatformSpecificSubtitleStyle(context),
                        textAlign: TextAlign.start,
                      ),
                      
                      SizedBox(height: OnboardingConstants.featureSpacing * 2),
                      
                      // Optimized feature list using ListView.builder
                      _FeatureList(features: data['features'], gradient: data['gradient'] as LinearGradient),
                    ],
                  ),
                ),
                
                SizedBox(height: OnboardingConstants.getBottomSpacing(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Center(
      child: Container(
        width: OnboardingConstants.logoSize,
        height: OnboardingConstants.logoSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          boxShadow: _getOptimizedShadows(),
        ),
        child: Padding(
          padding: EdgeInsets.all(OnboardingConstants.logoPadding),
          child: Image.asset(
            'assets/app_logo.png',
            fit: BoxFit.contain,
            cacheWidth: (OnboardingConstants.logoSize * MediaQuery.of(context).devicePixelRatio).round(),
            cacheHeight: (OnboardingConstants.logoSize * MediaQuery.of(context).devicePixelRatio).round(),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _getOptimizedShadows() {
    if (Platform.isIOS) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(OnboardingConstants.logoShadowOpacity),
          blurRadius: OnboardingConstants.logoShadowBlur,
          spreadRadius: OnboardingConstants.logoShadowSpread,
          offset: Offset(0, OnboardingConstants.logoShadowOffset),
        )
      ];
    } else {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(OnboardingConstants.logoShadowOpacity),
          blurRadius: OnboardingConstants.logoShadowBlur,
          spreadRadius: OnboardingConstants.logoShadowSpread,
          offset: Offset(0, OnboardingConstants.logoShadowOffset),
        )
      ];
    }
  }

  TextStyle _getPlatformSpecificTitleStyle(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
        color: Colors.white,
        height: 1.1,
      );
    }
    return OnboardingConstants.getPlatformSpecificTitleStyle(context);
  }

  TextStyle _getPlatformSpecificSubtitleStyle(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
        color: Colors.white.withOpacity(0.9),
        height: 1.4,
      );
    }
    return OnboardingConstants.getPlatformSpecificSubtitleStyle(context);
  }

  LinearGradient _getOptimizedGradient(LinearGradient original) {
    // Pre-compute gradient colors with opacity applied
    return LinearGradient(
      begin: original.begin,
      end: original.end,
      colors: original.colors.map((color) {
        if (color.opacity < 1.0) {
          return color.withOpacity(color.opacity);
        }
        return color;
      }).toList(),
    );
  }
}

// Extracted background elements widget with RepaintBoundary
class _BackgroundElements extends StatelessWidget {
  final Size screenSize;
  late final List<Positioned> _preCalculatedCircles;

  _BackgroundElements({required this.screenSize}) {
    _preCalculatedCircles = _calculateCirclePositions(screenSize);
  }

  static List<Positioned> _calculateCirclePositions(Size screenSize) {
    final random = math.Random(1); // Use consistent seed for randomness
    return List.generate(5, (i) {
      return Positioned(
        top: screenSize.height * (0.3 + random.nextDouble() * 0.4),
        left: screenSize.width * random.nextDouble(),
        child: Container(
          width: 10 + random.nextInt(20).toDouble(),
          height: 10 + random.nextInt(20).toDouble(),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(OnboardingConstants.backgroundElementOpacity * (0.5 + random.nextDouble())),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dotted pattern container 
        Positioned(
          top: screenSize.height * 0.18,
          right: -20,
          child: Transform.rotate(
            angle: -math.pi / 8,
            child: Container(
              width: 150,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(OnboardingConstants.backgroundElementOpacity * 0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: CustomPaint(
                painter: DotPatternPainter(
                  dotColor: Colors.white.withOpacity(OnboardingConstants.backgroundElementOpacity * 1.5),
                  dotSize: 4,
                  spacing: 12,
                ),
              ),
            ),
          ),
        ),
        
        // Wave-like shape
        Positioned(
          top: screenSize.height * 0.23,
          left: 20,
          child: CustomPaint(
            size: Size(100, 150),
            painter: WavePainter(
              color: Colors.white.withOpacity(OnboardingConstants.backgroundElementOpacity),
            ),
          ),
        ),
        
        // Pre-calculated circles
        ..._preCalculatedCircles,
      ],
    );
  }
}

// Extracted feature list widget with optimized rendering
class _FeatureList extends StatelessWidget {
  final List<String> features;
  final LinearGradient gradient;

  const _FeatureList({
    required this.features,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      itemBuilder: (context, index) => _FeatureItem(
        text: features[index],
        icon: _getFeatureIcon(index),
        gradient: gradient,
      ),
    );
  }

  IconData _getFeatureIcon(int index) {
    final List<IconData> icons = [
      Icons.flash_on_rounded,         // Speed/transmission
      Icons.chat_bubble_rounded,      // Modern messaging
      Icons.touch_app_rounded,        // Simple button press
      Icons.person_add_rounded,       // Create profile
    ];
    
    return icons[index % icons.length];
  }
}

// Extracted feature item widget with const constructor
class _FeatureItem extends StatelessWidget {
  final String text;
  final IconData icon;
  final LinearGradient gradient;

  const _FeatureItem({
    required this.text,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: OnboardingConstants.featureSpacing),
      child: Row(
        children: [
          Container(
            width: OnboardingConstants.featureIconContainerSize,
            height: OnboardingConstants.featureIconContainerSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(OnboardingConstants.featureIconBorderRadius),
              boxShadow: _getOptimizedFeatureShadows(),
            ),
            child: Icon(
              icon,
              color: gradient.colors.first,
              size: OnboardingConstants.featureIconSize,
            ),
          ),
          SizedBox(width: OnboardingConstants.iconTextSpacing),
          Expanded(
            child: Text(
              text,
              style: OnboardingConstants.featureTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  List<BoxShadow> _getOptimizedFeatureShadows() {
    if (Platform.isIOS) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(OnboardingConstants.featureIconShadowOpacity),
          blurRadius: OnboardingConstants.featureIconShadowBlur,
          spreadRadius: OnboardingConstants.featureIconShadowSpread,
          offset: Offset(0, OnboardingConstants.featureIconShadowOffset),
        )
      ];
    } else {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(OnboardingConstants.featureIconShadowOpacity),
          blurRadius: OnboardingConstants.featureIconShadowBlur,
          spreadRadius: OnboardingConstants.featureIconShadowSpread,
          offset: Offset(0, OnboardingConstants.featureIconShadowOffset),
        )
      ];
    }
  }
} 