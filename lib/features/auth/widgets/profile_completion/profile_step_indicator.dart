import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Step indicator widget showing progress through profile completion
class ProfileStepIndicator extends StatelessWidget {
  final int currentStep;

  const ProfileStepIndicator({
    super.key,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
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
          // First step indicator (Photo)
          Container(
            width: currentStep == 0 ? 12 : 10,
            height: currentStep == 0 ? 12 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentStep == 0 ? AppColors.accentBlue : Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Step labels
          Text(
            'PHOTO',
            style: TextStyle(
              color: currentStep == 0 ? Colors.white : Colors.grey.shade500,
              fontSize: 12,
              fontWeight: currentStep == 0 ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Connecting line
          Container(
            width: 24,
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: currentStep == 1 ? AppColors.accentBlue : Colors.grey.shade700,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Step labels
          Text(
            'NAME',
            style: TextStyle(
              color: currentStep == 1 ? Colors.white : Colors.grey.shade500,
              fontSize: 12,
              fontWeight: currentStep == 1 ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Second step indicator (Name)
          Container(
            width: currentStep == 1 ? 12 : 10,
            height: currentStep == 1 ? 12 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentStep == 1 ? AppColors.accentBlue : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
