import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final Color color;

  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.25);
    
    // Create a wavy pattern
    for (int i = 0; i < 6; i++) {
      final x1 = size.width * (i / 6);
      final x2 = size.width * ((i + 1) / 6);
      final y2 = size.height * (0.25 + (i % 2 == 0 ? -0.1 : 0.1));
      
      path.quadraticBezierTo(
        (x1 + x2) / 2, 
        i % 2 == 0 ? size.height * 0.4 : size.height * 0.1, 
        x2, 
        y2
      );
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 