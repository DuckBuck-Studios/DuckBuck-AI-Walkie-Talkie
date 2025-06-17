import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium Animated Text with Typewriter Effect
/// 
/// Features:
/// - Letter-by-letter typewriter animation
/// - Premium typography with custom styling
/// - Elegant underline accent animation
/// - Mathematical precision in letter spacing
/// - Optimized performance for smooth 120fps
class AnimatedText extends StatelessWidget {
  final String text;
  final double animationProgress;
  final double fontSize;
  
  const AnimatedText({
    super.key,
    required this.text,
    required this.animationProgress,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main animated text
        _buildTypewriterText(),
        
        const SizedBox(height: 8),
        
        // Animated accent underline
        _buildAccentLine(),
      ],
    );
  }
  
  Widget _buildTypewriterText() {
    // Calculate how many letters should be visible
    final totalLetters = text.length;
    final visibleLetters = (animationProgress * totalLetters).floor();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Build each letter with individual animations
        for (int i = 0; i < totalLetters; i++)
          _buildAnimatedLetter(
            text[i],
            i,
            i < visibleLetters,
            i == visibleLetters - 1,
          ),
      ],
    );
  }
  
  Widget _buildAnimatedLetter(
    String letter,
    int index,
    bool isVisible,
    bool isLatest,
  ) {
    // Calculate individual letter animation progress
    final letterProgress = math.max(
      0.0,
      math.min(1.0, animationProgress * text.length - index),
    );
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Transform.translate(
        offset: Offset(0, isVisible ? 0 : 10),
        child: Opacity(
          opacity: letterProgress,
          child: Transform.scale(
            scale: 0.8 + (0.2 * letterProgress),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: fontSize * 0.05,
                shadows: [
                  // Subtle text shadow for premium feel
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  // Glow effect for latest letter
                  if (isLatest)
                    Shadow(
                      offset: Offset.zero,
                      blurRadius: 8,
                      color: Colors.blue.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildAccentLine() {
    // Accent line appears after text is mostly complete
    final lineProgress = math.max(0.0, (animationProgress - 0.7) / 0.3);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: fontSize * text.length * 0.4 * lineProgress,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.blue.withValues(alpha: 0.8),
            Colors.blue.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3 * lineProgress),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
