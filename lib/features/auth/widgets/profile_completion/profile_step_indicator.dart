import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';

/// Step indicator widget showing progress through profile completion
class ProfileStepIndicator extends StatelessWidget {
  final int currentStep;
  final AnimationController stepTransitionController;

  const ProfileStepIndicator({
    super.key,
    required this.currentStep,
    required this.stepTransitionController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stepTransitionController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First step indicator (Photo) with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: currentStep == 0 ? 12 : 10,
                height: currentStep == 0 ? 12 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentStep == 0 ? AppColors.accentBlue : Colors.grey.shade600,
                ),
              )
              .animate()
              .scale(
                duration: 300.milliseconds,
                curve: Curves.elasticOut,
              ),
              
              const SizedBox(width: 8),
              
              // Step labels
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: currentStep == 0 ? Colors.white : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: currentStep == 0 ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                child: const Text('PHOTO'),
              ),
              
              const SizedBox(width: 8),
              
              // Connecting line with gradient animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    colors: currentStep == 1 
                      ? [AppColors.accentBlue, Colors.grey.shade600]
                      : [Colors.grey.shade700, Colors.grey.shade700],
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Step labels
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: currentStep == 1 ? Colors.white : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: currentStep == 1 ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                child: const Text('NAME'),
              ),
              
              const SizedBox(width: 8),
              
              // Second step indicator (Name) with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: currentStep == 1 ? 12 : 10,
                height: currentStep == 1 ? 12 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentStep == 1 ? AppColors.accentBlue : Colors.grey.shade600,
                ),
              )
              .animate()
              .scale(
                duration: 300.milliseconds,
                curve: Curves.elasticOut,
              ),
            ],
          ),
        );
      },
    );
  }
}
