import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../widgets/animated_background.dart';
import 'package:shimmer/shimmer.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DuckBuckAnimatedBackground(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated floating particles
            ParticleOverlay(),
            
            // 3D DuckBuck title with shimmer (copied from welcome screen)
            Stack(
              alignment: Alignment.center,
              children: [
                // Shadow layers for 3D effect
                Positioned(
                  left: 3,
                  top: 3,
                  child: Text(
                    "DuckBuck",
                    style: TextStyle(
                      fontSize: 60, // Increased size from 36 to 60
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.brown.shade900.withOpacity(0.3),
                    ),
                  ),
                ),
                Positioned(
                  left: 2,
                  top: 2,
                  child: Text(
                    "DuckBuck",
                    style: TextStyle(
                      fontSize: 60, // Increased size from 36 to 60
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
                      fontSize: 60, // Increased size from 36 to 60
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ).animate(autoPlay: false, onInit: (controller) {
              Future.delayed(const Duration(seconds: 5), () {
                controller.forward();
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
  const ParticleOverlay({super.key});

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
    for (int i = 0; i < particleCount; i++) {
      _particles.add(
        Particle(
          x: random.nextDouble() * 240 - 120,
          y: random.nextDouble() * 240 - 120,
          size: random.nextDouble() * 3 + 1.5,
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
          size: const Size(240, 240),
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
    
    for (final particle in particles) {
      // Update particle position in a circular motion
      final angle = animation * 2 * math.pi + (particle.x + particle.y) * 0.01;
      
      final wobble = math.sin(animation * 2 * math.pi + particle.size) * 4;
      
      final x = center.dx + particle.x + 
                math.sin(angle) * particle.speedX * 20 + wobble;
      final y = center.dy + particle.y + 
                math.cos(angle) * particle.speedY * 20 - wobble;
      
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