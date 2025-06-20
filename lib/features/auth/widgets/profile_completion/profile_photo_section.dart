import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_colors.dart';

/// Photo section module for profile completion
/// Handles photo selection UI and logic as a separate module
class ProfilePhotoSection extends StatelessWidget {
  final File? selectedImage;
  final Function(File?) onImageSelected;
  final Function(String) onError;
  final AnimationController photoAnimationController;
  final Animation<double> photoScaleAnimation;
  final Animation<double> photoSlideAnimation;
  final Animation<double> photoFadeAnimation;
  final Animation<double> photoShimmerAnimation;
  final bool isIOS;
  final VoidCallback? onEditPhoto;

  const ProfilePhotoSection({
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
    this.onEditPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Section Header
          AnimatedBuilder(
            animation: photoAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, photoSlideAnimation.value),
                child: Opacity(
                  opacity: photoFadeAnimation.value,
                  child: Column(
                    children: [
                      // Section title with gradient text
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.blue.shade300,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          'Step 1: Profile Photo',
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
                        selectedImage == null 
                            ? 'Add a photo so your friends can recognize you'
                            : 'Great! Your profile photo looks perfect',
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
          
          // Photo selector component
          AnimatedBuilder(
            animation: photoAnimationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, photoSlideAnimation.value),
                child: Transform.scale(
                  scale: photoScaleAnimation.value,
                  child: Opacity(
                    opacity: photoFadeAnimation.value,
                    child: _buildPhotoDisplay(),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Progress indicator for photo step
          AnimatedBuilder(
            animation: photoAnimationController,
            builder: (context, child) {
              return Opacity(
                opacity: photoFadeAnimation.value,
                child: _buildPhotoStepProgress(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Build progress indicator for photo step
  Widget _buildPhotoStepProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selectedImage != null 
            ? Colors.green.shade600.withValues(alpha: 0.2)
            : AppColors.backgroundBlack.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedImage != null 
              ? Colors.green.shade600.withValues(alpha: 0.5)
              : AppColors.textSecondary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selectedImage != null 
                ? (isIOS ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle)
                : (isIOS ? CupertinoIcons.camera : Icons.camera_alt_outlined),
            color: selectedImage != null ? Colors.green.shade400 : AppColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            selectedImage != null ? 'Photo Selected' : 'Photo Required',
            style: TextStyle(
              color: selectedImage != null ? Colors.green.shade400 : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build photo display with tap to select functionality
  Widget _buildPhotoDisplay() {
    return Center(
      child: Stack(
        children: [
          // Main photo container
          Hero(
            tag: 'user_profile_photo_hero',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              width: 160,
              height: 160,
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
                image: selectedImage != null
                    ? DecorationImage(
                        image: FileImage(selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: selectedImage == null
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        isIOS ? CupertinoIcons.add : Icons.add,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    )
                  : null,
            ),
          ),
          
          // Edit icon overlay when photo is selected
          if (selectedImage != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  // Call the edit photo callback
                  onEditPhoto?.call();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentBlue,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isIOS ? CupertinoIcons.pen : Icons.edit,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
