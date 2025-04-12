import 'package:flutter/material.dart';

class DotPatternPainter extends CustomPainter {
  final Color dotColor;
  final double dotSize;
  final double spacing;

  DotPatternPainter({
    required this.dotColor,
    this.dotSize = 5.0,
    this.spacing = 15.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    // Calculate number of dots based on size and spacing
    final horizontalCount = (size.width / spacing).floor();
    final verticalCount = (size.height / spacing).floor();

    // Draw dots in a grid pattern
    for (int x = 0; x < horizontalCount; x++) {
      for (int y = 0; y < verticalCount; y++) {
        final xPos = x * spacing + spacing / 2;
        final yPos = y * spacing + spacing / 2;
        canvas.drawCircle(Offset(xPos, yPos), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 