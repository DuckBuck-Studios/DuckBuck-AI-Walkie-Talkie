import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget for display name input with premium styling
class DisplayNameInput extends StatelessWidget {
  final TextEditingController nameController;
  final GlobalKey<FormState> formKey;
  final AnimationController contentAnimationController;
  final Animation<double> contentSlideAnimation;
  final bool isIOS;

  const DisplayNameInput({
    super.key,
    required this.nameController,
    required this.formKey,
    required this.contentAnimationController,
    required this.contentSlideAnimation,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: contentAnimationController,
      builder: (context, child) {
        final slideValue = contentSlideAnimation.value;
        
        return Transform.translate(
          offset: Offset(0, slideValue),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                // Premium animated title
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.blue.shade300,
                      Colors.purple.shade300,
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    'What\'s Your Name?',
                    style: TextStyle(
                      fontSize: isIOS ? 28 : 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                )
                .animate(delay: 100.milliseconds)
                .fadeIn(duration: 600.milliseconds)
                .slideY(begin: 0.3, end: 0),
                
                const SizedBox(height: 12),
                
                // Subtitle with elegant animation
                Text(
                  "Enter the name you'd like to use in the app",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: isIOS ? 16 : 17,
                    letterSpacing: 0.3,
                  ),
                )
                .animate(delay: 200.milliseconds)
                .fadeIn(duration: 600.milliseconds)
                .slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 40),
                
                // Premium styled name input
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: isIOS
                      ? CupertinoTextField(
                          controller: nameController,
                          placeholder: 'Your name',
                          placeholderStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 18,
                            letterSpacing: 0.3,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          padding: const EdgeInsets.all(20),
                          clearButtonMode: OverlayVisibilityMode.editing,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey.shade900,
                                Colors.grey.shade800.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade700,
                              width: 1,
                            ),
                          ),
                          autocorrect: true,
                        )
                      : TextFormField(
                          controller: nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(20),
                            hintText: 'Your name',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 18,
                              letterSpacing: 0.3,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade900,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade700),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.shade700),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppColors.accentBlue,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.red.shade400,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.red.shade400,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                )
                .animate(delay: 300.milliseconds)
                .fadeIn(duration: 700.milliseconds)
                .slideY(begin: 0.3, end: 0)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0)),
                
                // Add some bottom padding for scrolling
                const SizedBox(height: 60),
              ],
            ),
          ),
        );
      },
    );
  }
}
