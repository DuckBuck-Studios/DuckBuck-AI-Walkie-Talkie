import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget for handling profile photo selection
/// Provides camera and gallery options with premium UI
class ProfilePhotoSelector extends StatelessWidget {
  final File? selectedImage;
  final Function(File?) onImageSelected;
  final Function(String) onError;
  final AnimationController photoAnimationController;
  final Animation<double> photoScaleAnimation;
  final Animation<double> photoSlideAnimation;
  final Animation<double> photoFadeAnimation;
  final Animation<double> photoShimmerAnimation;
  final bool isIOS;

  const ProfilePhotoSelector({
    super.key,
    required this.selectedImage,
    required this.onImageSelected,
    required this.onError,
    required this.photoAnimationController,
    required this.photoScaleAnimation,
    required this.photoSlideAnimation,
    required this.photoFadeAnimation,
    required this.photoShimmerAnimation,
    required this.isIOS,
  });

  /// Pick image from gallery or camera
  Future<void> _pickImage({ImageSource? source}) async {
    try {
      // If no specific source provided, show bottom sheet to choose
      final ImageSource imageSource = source ?? ImageSource.gallery;

      // Use image picker to select image with optimized settings
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: imageSource,
        maxWidth: 800, // Optimized size for better memory management
        maxHeight: 800, // Optimized size for better memory management
        imageQuality: 80, // Slightly more compressed for better performance
        requestFullMetadata: false, // Skip metadata for faster loading
        preferredCameraDevice: imageSource == ImageSource.camera ? CameraDevice.front : CameraDevice.front, // Prefer front camera for profile photos
      );

      if (pickedFile != null) {
        onImageSelected(File(pickedFile.path));
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Handle errors (permissions, etc.)
      onError('Could not select image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: photoAnimationController,
      builder: (context, child) {
        final slideValue = photoSlideAnimation.value;
        final scaleValue = photoScaleAnimation.value;
        final fadeValue = photoFadeAnimation.value;
        final shimmerValue = photoShimmerAnimation.value;
        
        return Transform.translate(
          offset: Offset(0, slideValue),
          child: Transform.scale(
            scale: scaleValue,
            child: Opacity(
              opacity: fadeValue,
              child: Column(
                children: [
                  // Title with premium typography
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.8),
                        Colors.blue.shade300,
                      ],
                      stops: [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      'Add a Profile Photo',
                      style: TextStyle(
                        fontSize: isIOS ? 28 : 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Subtitle with shimmer effect
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: fadeValue),
                      fontSize: isIOS ? 16 : 17,
                      letterSpacing: 0.3,
                    ),
                    child: Text(
                      selectedImage == null 
                          ? 'Help your friends recognize you by adding a profile photo'
                          : 'Looking great! Use the buttons below to change your photo if needed.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Profile image with sophisticated animations
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _pickImage();
                    },
                    child: Hero(
                      tag: 'user_profile_photo_hero', // Unique hero tag for cross-screen transitions
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: selectedImage != null 
                            ? null 
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade400.withValues(alpha: 0.8),
                                  Colors.purple.shade400.withValues(alpha: 0.8),
                                  Colors.pink.shade300.withValues(alpha: 0.6),
                                ],
                              ),
                          boxShadow: [
                            BoxShadow(
                              color: (selectedImage != null ? Colors.blue : Colors.purple)
                                  .withValues(alpha: 0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 15),
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(-8, -8),
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(8, 8),
                              spreadRadius: 1,
                            ),
                          ],
                          image: selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: selectedImage == null
                            ? Stack(
                                children: [
                                  // Plus icon with glow effect
                                  Center(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.add,
                                        size: 36,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                  
                                  // Rotating sparkle overlay
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: photoAnimationController,
                                      builder: (context, _) {
                                        return Transform.rotate(
                                          angle: shimmerValue * 6.28, // Full rotation
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: SweepGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.white.withValues(alpha: shimmerValue * 0.3),
                                                  Colors.transparent,
                                                  Colors.blue.withValues(alpha: shimmerValue * 0.2),
                                                  Colors.transparent,
                                                ],
                                                stops: const [0.0, 0.2, 0.4, 0.6, 1.0],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : // Selected image overlay with subtle effects
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.1),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  )
                  .animate(delay: 200.milliseconds)
                  .shimmer(
                    duration: 2000.milliseconds, 
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Floating particles animation around photo
                  if (selectedImage == null)
                    SizedBox(
                      height: 100,
                      child: Stack(
                        children: List.generate(6, (index) {
                          return Positioned(
                            left: 50.0 + (index * 40) + (shimmerValue * 20),
                            top: 20.0 + (index % 2 * 40) + (shimmerValue * 15),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: [
                                  Colors.blue.shade300,
                                  Colors.purple.shade300,
                                  Colors.pink.shade300,
                                ][index % 3].withValues(alpha: fadeValue * 0.6),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  
                  // Add some bottom padding for scrolling
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
