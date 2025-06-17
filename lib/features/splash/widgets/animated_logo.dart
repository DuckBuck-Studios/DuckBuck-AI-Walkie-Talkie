import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Premium Animated Logo with Glow Effects
/// 
/// Features:
/// - High-quality logo rendering with smooth scaling
/// - Dynamic glow effects that respond to animation
/// - Optimized image caching and error handling
/// - Glass morphism effects for premium feel
class AnimatedLogo extends StatelessWidget {
  final double size;
  final double glowIntensity;
  
  const AnimatedLogo({
    super.key,
    required this.size,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow Effect
          if (glowIntensity > 0) ...[
            Container(
              width: size * 1.4,
              height: size * 1.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3 * glowIntensity),
                    blurRadius: 30 * glowIntensity,
                    spreadRadius: 5 * glowIntensity,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1 * glowIntensity),
                    blurRadius: 60 * glowIntensity,
                    spreadRadius: 10 * glowIntensity,
                  ),
                ],
              ),
            ),
          ],
          
          // Glass Morphism Container
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.15),
                    child: _buildLogo(),
                  ),
                ),
              ),
            ),
          ),
          
          // Inner Highlight
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  Colors.white.withValues(alpha: 0.2 * glowIntensity),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogo() {
    return Image.asset(
      'assets/logo.png',
      width: size * 0.7,
      height: size * 0.7,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to beautiful icon if asset fails
        return Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade400,
                Colors.blue.shade600,
                Colors.indigo.shade700,
              ],
            ),
          ),
          child: Icon(
            Icons.auto_awesome,
            size: size * 0.4,
            color: Colors.white,
          ),
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Add shimmer effect while loading
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        
        return Container(
          width: size * 0.7,
          height: size * 0.7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade800,
                Colors.grey.shade900,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }
}
