import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StatusAnimationPopup extends StatelessWidget {
  final Function(String?) onAnimationSelected;

  const StatusAnimationPopup({
    Key? key,
    required this.onAnimationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFD4A76A).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Status Animation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.1, end: 0, duration: 400.ms),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // No Animation Option
            _buildNoAnimationOption(context),
            
            // Divider
            Divider(
              color: Colors.white.withOpacity(0.2),
              thickness: 1,
              indent: 20,
              endIndent: 20,
            ),
            
            // Animation Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: 57, // Total number of animations (42 blue-demon + 15 usr-emoji)
                itemBuilder: (context, index) {
                  return _buildAnimationItem(index, context);
                },
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 300.ms)
      .scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        duration: 300.ms,
        curve: Curves.easeOutBack,
      );
  }

  Widget _buildNoAnimationOption(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: InkWell(
        onTap: () {
          onAnimationSelected(null);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.do_not_disturb,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No Animation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Show only online/offline status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(delay: 200.ms, duration: 400.ms)
      .slideY(delay: 200.ms, begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildAnimationItem(int index, BuildContext context) {
    final animationName = _getAnimationName(index);
    return GestureDetector(
      onTap: () {
        onAnimationSelected(animationName);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Lottie.asset(
            'assets/status/${_getStatusAnimationPath(animationName)}',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print("Error loading animation: ${_getStatusAnimationPath(animationName)}");
              print(error);
              return Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.withOpacity(0.7),
                ),
              );
            },
          ),
        ),
      ),
    ).animate(delay: (50 * index).ms)
      .fadeIn(duration: 300.ms)
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.0, 1.0),
        duration: 300.ms, 
        curve: Curves.easeOutBack,
      );
  }

  String _getAnimationName(int index) {
    if (index < 42) {
      return 'blue-demon${index + 1}';
    } else {
      return 'usr-emoji${index - 41}';
    }
  }

  String _getStatusAnimationPath(String animation) {
    if (animation.startsWith('blue-demon')) {
      return 'blue-demon/$animation.json';
    } else if (animation.startsWith('usr-emoji')) {
      return 'usr-emoji/$animation.json';
    }
    return '$animation.json';
  }
} 