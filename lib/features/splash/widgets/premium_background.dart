import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium Background with Floating Particles and Gradients
/// 
/// Creates a sophisticated background with:
/// - Dynamic gradient overlays
/// - Floating geometric particles
/// - Subtle depth and dimension
/// - Optimized for 120fps performance
class PremiumBackground extends StatefulWidget {
  const PremiumBackground({super.key});

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with TickerProviderStateMixin {
  
  late AnimationController _particleController;
  late List<Particle> _particles;
  
  @override
  void initState() {
    super.initState();
    _setupParticles();
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }
  
  void _setupParticles() {
    _particles = List.generate(12, (index) {
      return Particle(
        id: index,
        initialOffset: Offset(
          math.Random().nextDouble(),
          math.Random().nextDouble(),
        ),
        size: 2.0 + math.Random().nextDouble() * 4.0,
        speed: 0.3 + math.Random().nextDouble() * 0.4,
        opacity: 0.1 + math.Random().nextDouble() * 0.3,
      );
    });
  }
  
  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Container(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          // Primary Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  const Color(0xFF0A0A0A),
                  const Color(0xFF000000),
                  const Color(0xFF000000),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
          
          // Secondary Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Colors.blue.withOpacity(0.03),
                  Colors.transparent,
                  Colors.indigo.withOpacity(0.02),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Animated Particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              return CustomPaint(
                painter: ParticlePainter(
                  particles: _particles,
                  animationValue: _particleController.value,
                  canvasSize: size,
                ),
                size: size,
              );
            },
          ),
          
          // Subtle Vignette Effect
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual Particle Data Class
class Particle {
  final int id;
  final Offset initialOffset;
  final double size;
  final double speed;
  final double opacity;
  
  const Particle({
    required this.id,
    required this.initialOffset,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

/// Custom Painter for Floating Particles
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;
  final Size canvasSize;
  
  ParticlePainter({
    required this.particles,
    required this.animationValue,
    required this.canvasSize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..blendMode = BlendMode.screen;
    
    for (final particle in particles) {
      // Calculate particle position with smooth movement
      final progress = (animationValue + particle.id * 0.1) % 1.0;
      final x = particle.initialOffset.dx * size.width + 
                (math.sin(progress * 2 * math.pi + particle.id) * 50);
      final y = particle.initialOffset.dy * size.height + 
                (math.cos(progress * 2 * math.pi + particle.id * 0.7) * 30);
      
      // Create gradient for each particle
      final gradient = RadialGradient(
        colors: [
          Colors.white.withOpacity(particle.opacity),
          Colors.blue.withOpacity(particle.opacity * 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      );
      
      // Paint particle with gradient
      paint.shader = gradient.createShader(
        Rect.fromCircle(
          center: Offset(x, y),
          radius: particle.size,
        ),
      );
      
      canvas.drawCircle(
        Offset(x, y),
        particle.size,
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
