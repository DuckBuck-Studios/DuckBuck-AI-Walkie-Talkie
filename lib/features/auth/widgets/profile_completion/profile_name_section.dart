import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_colors.dart';

/// Name section module for profile completion
/// Handles display name input UI and logic as a separate module
class ProfileNameSection extends StatelessWidget {
  final TextEditingController nameController;
  final GlobalKey<FormState> formKey;
  final AnimationController contentAnimationController;
  final Animation<double> contentSlideAnimation;
  final bool isIOS;
  final VoidCallback? onNameChanged;

  const ProfileNameSection({
    super.key,
    required this.nameController,
    required this.formKey,
    required this.contentAnimationController,
    required this.contentSlideAnimation,
    required this.isIOS,
    this.onNameChanged,
  });  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Take minimum space needed
          children: [
            // Section Header with right-to-left slide animation
            AnimatedBuilder(
              animation: contentAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    (1.0 - contentAnimationController.value) * 100, // Slide from right
                    contentSlideAnimation.value,
                  ),
                  child: Opacity(
                    opacity: contentAnimationController.value,
                    child: Column(
                      children: [
                        // Section title with gradient text
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.purple.shade300,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'Step 2: Display Name',
                            style: TextStyle(
                              fontSize: isIOS ? 22 : 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Section subtitle
                        Text(
                          'Choose how you\'d like to be displayed to other users',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: isIOS ? 16 : 17,
                            letterSpacing: 0.3,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Display name input component with right-to-left slide animation
            AnimatedBuilder(
              animation: contentAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    (1.0 - contentAnimationController.value) * 80, // Slide from right, less distance
                    contentSlideAnimation.value,
                  ),
                  child: Opacity(
                    opacity: contentAnimationController.value,
                    child: _buildNameInput(context), // Pass context
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Progress indicator with right-to-left slide animation
            AnimatedBuilder(
              animation: contentAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    (1.0 - contentAnimationController.value) * 60, // Slide from right, even less distance
                    0,
                  ),
                  child: Opacity(
                    opacity: contentAnimationController.value,
                    child: _buildNameStepProgress(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // Name requirements hint with right-to-left slide animation
            AnimatedBuilder(
              animation: contentAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    (1.0 - contentAnimationController.value) * 40, // Slide from right, minimal distance
                    contentSlideAnimation.value * 0.5,
                  ),
                  child: Opacity(
                    opacity: contentAnimationController.value * 0.8,
                    child: _buildNameRequirements(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build progress indicator for name step
  Widget _buildNameStepProgress() {
    final hasValidName = nameController.text.trim().length >= 2;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: hasValidName 
            ? Colors.green.shade600.withValues(alpha: 0.2)
            : AppColors.backgroundBlack.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasValidName 
              ? Colors.green.shade600.withValues(alpha: 0.5)
              : AppColors.textSecondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasValidName 
                ? (isIOS ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle)
                : (isIOS ? CupertinoIcons.person : Icons.person_outline),
            color: hasValidName ? Colors.green.shade400 : AppColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            hasValidName ? 'Name Looks Good' : 'Name Required',
            style: TextStyle(
              color: hasValidName ? Colors.green.shade400 : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build name requirements hint
  Widget _buildNameRequirements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundBlack.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIOS ? CupertinoIcons.info_circle : Icons.info_outline,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Display Name Guidelines',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...const [
            '• At least 2 characters long',
            '• Use your real name or a nickname',
            '• Avoid special characters or numbers',
            '• Keep it friendly and appropriate',
          ].map((requirement) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              requirement,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          )),
        ],
      ),
    );
  }

  /// Build name input field
  Widget _buildNameInput(BuildContext context) {
    return Form(
      key: formKey,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundBlack.withValues(alpha: 0.8),
              AppColors.backgroundBlack.withValues(alpha: 0.4),
            ],
          ),
          border: Border.all(
            color: AppColors.accentBlue.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isIOS
            ? CupertinoTextFormFieldRow(
                controller: nameController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                placeholder: 'Enter your display name',
                textInputAction: TextInputAction.done, // Add Done button
                onEditingComplete: () {
                  // Dismiss keyboard when Done is pressed
                  FocusScope.of(context).unfocus();
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                placeholderStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                ),
                decoration: const BoxDecoration(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a display name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Trigger parent rebuild to update progress indicator
                  onNameChanged?.call();
                },
              )
            : TextFormField(
                controller: nameController,
                textInputAction: TextInputAction.done, // Add Done button
                onEditingComplete: () {
                  // Dismiss keyboard when Done is pressed
                  FocusScope.of(context).unfocus();
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your display name',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a display name';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Trigger parent rebuild to update progress indicator
                  onNameChanged?.call();
                },
              ),
      ),
    );
  }
}
