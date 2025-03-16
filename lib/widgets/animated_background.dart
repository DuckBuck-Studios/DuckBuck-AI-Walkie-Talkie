import 'dart:math';
import 'package:flutter/material.dart';

class DuckBuckAnimatedBackground extends StatefulWidget {
  final Widget child;
  final double opacity;
  
  const DuckBuckAnimatedBackground({
    super.key, 
    required this.child,
    this.opacity = 0.05,
  });

  @override
  State<DuckBuckAnimatedBackground> createState() => _DuckBuckAnimatedBackgroundState();
}

class _DuckBuckAnimatedBackgroundState extends State<DuckBuckAnimatedBackground> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // Warm ghee color background constants
  static const Color warmGheeColor = Color(0xFFF5E8C7);
  static const Color deeperWarmColor = Color(0xFFE6C38D);
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background with gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                warmGheeColor,
                deeperWarmColor,
              ],
              stops: [0.5, 1.0],
            ),
          ),
        ),
        
        // Animated checkboxes pattern
        Opacity(
          opacity: widget.opacity,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                painter: AnimatedCheckboxPatternPainter(
                  progress: _animationController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

// Animated checkbox pattern painter
class AnimatedCheckboxPatternPainter extends CustomPainter {
  final double progress;
  
  AnimatedCheckboxPatternPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    
    // Smaller spacing for more checkboxes
    const double spacing = 25.0;
    
    // Calculate the number of rows and columns
    final int rows = (size.height / spacing).ceil() + 1;
    final int cols = (size.width / spacing).ceil() + 1;
    
    // Calculate wave offset based on progress
    final double waveOffset = progress * 2 * pi; // Full circle
    
    // Draw horizontal lines with wave-like visibility
    for (int i = 0; i < rows; i++) {
      final double y = i * spacing;
      final double horizontalAlpha = (0.5 + 0.5 * sin(waveOffset + i * 0.2)).clamp(0.0, 1.0);
      
      paint.color = Colors.black.withOpacity(horizontalAlpha);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
    
    // Draw vertical lines with different wave pattern
    for (int i = 0; i < cols; i++) {
      final double x = i * spacing;
      final double verticalAlpha = (0.5 + 0.5 * cos(waveOffset + i * 0.2)).clamp(0.0, 1.0);
      
      paint.color = Colors.black.withOpacity(verticalAlpha);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Add some diagonal lines that appear and disappear
    final int diagonals = min(rows, cols);
    for (int i = 0; i < diagonals; i += 3) {
      final double diagonalAlpha = (0.3 + 0.7 * sin(waveOffset + i * 0.3 + 1.0)).clamp(0.0, 1.0);
      if (diagonalAlpha > 0.1) {
        paint.color = Colors.black.withOpacity(diagonalAlpha * 0.7);
        canvas.drawLine(
          Offset(i * spacing, 0),
          Offset(0, i * spacing),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AnimatedCheckboxPatternPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}