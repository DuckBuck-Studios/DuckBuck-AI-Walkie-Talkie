import 'dart:math';
import 'package:flutter/material.dart';

// Custom painter for the swipe path
class SwipePathPainter extends CustomPainter {
  final Offset startPosition;
  final double progress;
  final Size screenSize;
  final Offset endPosition;
  final PathDirection direction;
  final PathDirection? presetDirection;
  final Offset? presetEndPosition;
  
  SwipePathPainter({
    required this.startPosition,
    required this.progress,
    required this.screenSize,
    this.presetDirection,
    this.presetEndPosition,
  }) : endPosition = presetEndPosition ?? calculateEndPosition(startPosition, screenSize, presetDirection ?? determineDirection(startPosition, screenSize)),
       direction = presetDirection ?? determineDirection(startPosition, screenSize);
  
  static Offset calculateEndPosition(Offset start, Size screenSize, PathDirection direction) {
    // Determine where to place the endpoint based on screen position
    final pathLength = 150.0;
    
    switch (direction) {
      case PathDirection.right:
        return Offset(start.dx + pathLength, start.dy);
      case PathDirection.left:
        return Offset(start.dx - pathLength, start.dy);
      case PathDirection.up:
        return Offset(start.dx, start.dy - pathLength);
      case PathDirection.down:
        return Offset(start.dx, start.dy + pathLength);
      case PathDirection.upRight:
        return Offset(start.dx + pathLength * 0.7, start.dy - pathLength * 0.7);
      case PathDirection.upLeft:
        return Offset(start.dx - pathLength * 0.7, start.dy - pathLength * 0.7);
      case PathDirection.downRight:
        return Offset(start.dx + pathLength * 0.7, start.dy + pathLength * 0.7);
      case PathDirection.downLeft:
        return Offset(start.dx - pathLength * 0.7, start.dy + pathLength * 0.7);
    }
  }
  
  static PathDirection determineDirection(Offset start, Size screenSize) {
    // Calculate distance to edges
    final distanceToRight = screenSize.width - start.dx;
    final distanceToLeft = start.dx;
    final distanceToTop = start.dy;
    final distanceToBottom = screenSize.height - start.dy;
    
    // Minimum distance required for path
    const minDistance = 180.0;
    
    // List of possible directions based on available space
    List<PathDirection> possibleDirections = [];
    
    if (distanceToRight >= minDistance) possibleDirections.add(PathDirection.right);
    if (distanceToLeft >= minDistance) possibleDirections.add(PathDirection.left);
    if (distanceToTop >= minDistance) possibleDirections.add(PathDirection.up);
    if (distanceToBottom >= minDistance) possibleDirections.add(PathDirection.down);
    
    // Add diagonal directions if there's enough space in both directions
    if (distanceToRight >= minDistance * 0.7 && distanceToTop >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.upRight);
    if (distanceToLeft >= minDistance * 0.7 && distanceToTop >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.upLeft);
    if (distanceToRight >= minDistance * 0.7 && distanceToBottom >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.downRight);
    if (distanceToLeft >= minDistance * 0.7 && distanceToBottom >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.downLeft);
    
    // Default to right if no direction has enough space (unlikely)
    if (possibleDirections.isEmpty) return PathDirection.right;
    
    // Choose a random direction from the possible ones
    return possibleDirections[Random().nextInt(possibleDirections.length)];
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    
    // Calculate the path vector
    final pathVector = Offset(
      endPosition.dx - startPosition.dx,
      endPosition.dy - startPosition.dy,
    );
    
    // Current path end position based on progress
    final currentEnd = Offset(
      startPosition.dx + pathVector.dx * progress,
      startPosition.dy + pathVector.dy * progress,
    );
    
    // Draw dashed line for remaining path
    paint.color = Colors.white.withOpacity(0.5);
    final dashWidth = 15.0;
    final dashSpace = 5.0;
    
    double currentDistance = pathVector.distance * progress;
    final totalDistance = pathVector.distance;
    
    while (currentDistance < totalDistance) {
      final nextDistance = currentDistance + dashWidth;
      if (nextDistance > totalDistance) break;
      
      final startPoint = Offset(
        startPosition.dx + (pathVector.dx * currentDistance / totalDistance),
        startPosition.dy + (pathVector.dy * currentDistance / totalDistance),
      );
      
      final endPoint = Offset(
        startPosition.dx + (pathVector.dx * nextDistance / totalDistance),
        startPosition.dy + (pathVector.dy * nextDistance / totalDistance),
      );
      
      canvas.drawLine(startPoint, endPoint, paint);
      currentDistance = nextDistance + dashSpace;
    }
    
    // Draw completed path
    paint.color = Colors.green;
    paint.strokeWidth = 8;
    canvas.drawLine(startPosition, currentEnd, paint);
    
    // Draw arrow heads along the path if not completed
    if (progress < 0.9) {
      final arrowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      // Calculate unit vector for arrow direction
      final dx = pathVector.dx / pathVector.distance;
      final dy = pathVector.dy / pathVector.distance;
      
      // Draw arrow heads along the remaining path
      for (double d = pathVector.distance * progress + 20; d < totalDistance; d += 40) {
        final arrowX = startPosition.dx + (dx * d);
        final arrowY = startPosition.dy + (dy * d);
        
        // Create a path for the arrow head
        final path = Path();
        path.moveTo(arrowX, arrowY);
        
        // Calculate perpendicular vector for arrow wings
        final perpX = -dy * 5;
        final perpY = dx * 5;
        
        // Draw arrow that points in the direction of the path
        path.lineTo(arrowX - (dx * 10) + perpX, arrowY - (dy * 10) + perpY);
        path.lineTo(arrowX - (dx * 10) - perpX, arrowY - (dy * 10) - perpY);
        path.close();
        
        canvas.drawPath(path, arrowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant SwipePathPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.startPosition != startPosition ||
           oldDelegate.direction != direction;
  }
}

enum PathDirection {
  right,
  left,
  up,
  down,
  upRight,
  upLeft,
  downRight,
  downLeft,
} 