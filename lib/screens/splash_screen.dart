import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../widgets/animated_background.dart';
import 'package:shimmer/shimmer.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) { 
    final Size screenSize = MediaQuery.of(context).size;
    final double titleSize = screenSize.width * 0.15; 
    final double particleSize = math.min(screenSize.width, screenSize.height) * 0.6;
    
    return DuckBuckAnimatedBackground(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated floating particles
            ParticleOverlay(size: particleSize),
            
            // 3D DuckBuck title with shimmer (copied from welcome screen)
            Stack(
              alignment: Alignment.center,
              children: [
                // Shadow layers for 3D effect
                Positioned(
                  left: titleSize * 0.05,
                  top: titleSize * 0.05,
                  child: Text(
                    "DuckBuck",
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.brown.shade900.withOpacity(0.3),
                    ),
                  ),
                ),
                Positioned(
                  left: titleSize * 0.033,
                  top: titleSize * 0.033,
                  child: Text(
                    "DuckBuck",
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.brown.shade800.withOpacity(0.5),
                    ),
                  ),
                ),
                // Main text with shimmer
                Shimmer.fromColors(
                  baseColor: Colors.brown.shade700,
                  highlightColor: Colors.amber.shade300,
                  child: Text(
                    "DuckBuck",
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ).animate(autoPlay: false, onInit: (controller) {
              Future.delayed(const Duration(seconds: 5), () {
                // Use try-catch to safely handle if controller is disposed
                try {
                  controller.forward();
                } catch (e) {
                  // Controller might be disposed, ignore the error
                  print('Animation controller error: $e');
                }
              });
            }).fadeOut(duration: 800.ms),
          ],
        ),
      ),
    );
  }
}

// Custom particle animation
class ParticleOverlay extends StatefulWidget {
  final double size;

  const ParticleOverlay({super.key, this.size = 240.0});

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay> with TickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Particle> _particles = [];
  final int particleCount = 15;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    
    // Create particles with random properties
    final random = math.Random();
    final halfSize = widget.size / 2;
    
    for (int i = 0; i < particleCount; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble() * widget.size - halfSize,
          y: random.nextDouble() * widget.size - halfSize,
          size: (random.nextDouble() * 3 + 1.5) * (widget.size / 240), // Scale particle size based on container size
          speedX: (random.nextDouble() - 0.5) * 0.5,
          speedY: (random.nextDouble() - 0.5) * 0.5,
          opacity: 0.2 + random.nextDouble() * 0.4,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: ParticlePainter(
            _particles,
            _controller.value,
            color: const Color(0xFFD4A76A),
          ),
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  final double size;
  final double speedX;
  final double speedY;
  final double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;
  final Color color;

  ParticlePainter(this.particles, this.animation, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scaleFactor = size.width / 240; // Base scale is 240
    
    for (final particle in particles) {
      // Update particle position in a circular motion
      final angle = animation * 2 * math.pi + (particle.x + particle.y) * 0.01;
      
      final wobble = math.sin(animation * 2 * math.pi + particle.size) * 4 * scaleFactor;
      
      final x = center.dx + particle.x + 
                math.sin(angle) * particle.speedX * 20 * scaleFactor + wobble;
      final y = center.dy + particle.y + 
                math.cos(angle) * particle.speedY * 20 * scaleFactor - wobble;
      
      // Draw the particle
      final paint = Paint()
        ..color = color.withOpacity(particle.opacity * 
                  (0.5 + 0.5 * math.sin(animation * 2 * math.pi + particle.size)))
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}