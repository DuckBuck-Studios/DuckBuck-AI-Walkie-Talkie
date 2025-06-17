import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Complete profile button with premium styling
class CompleteProfileButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isIOS;

  const CompleteProfileButton({
    super.key,
    required this.onPressed,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade600,
            Colors.blue.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isIOS
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              onPressed: () {
                HapticFeedback.heavyImpact();
                onPressed();
              },
              child: const Text(
                'Complete Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 56),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                onPressed();
              },
              child: const Text(
                'COMPLETE PROFILE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
    )
    .animate(delay: 400.milliseconds)
    .fadeIn(duration: 800.milliseconds)
    .slideY(begin: 0.5, end: 0)
    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0));
  }
}
