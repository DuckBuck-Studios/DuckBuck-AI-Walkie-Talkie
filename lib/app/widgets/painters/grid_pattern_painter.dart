import 'package:flutter/material.dart';

class GridPatternPainter extends CustomPainter {
  final Color lineColor;
  final double spacing;

  GridPatternPainter({
    required this.lineColor,
    this.spacing = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Calculate number of lines based on size and spacing
    final horizontalCount = (size.height / spacing).floor();
    final verticalCount = (size.width / spacing).floor();

    // Draw horizontal lines
    for (int i = 0; i < horizontalCount; i++) {
      final y = i * spacing;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw vertical lines
    for (int i = 0; i < verticalCount; i++) {
      final x = i * spacing;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 