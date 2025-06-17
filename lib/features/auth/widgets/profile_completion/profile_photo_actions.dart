import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';

/// Widget for photo action buttons (camera, gallery, continue)
class ProfilePhotoActions extends StatelessWidget {
  final File? selectedImage;
  final Function(ImageSource) onImagePicked;
  final VoidCallback onContinue;
  final bool isIOS;

  const ProfilePhotoActions({
    super.key,
    required this.selectedImage,
    required this.onImagePicked,
    required this.onContinue,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Take photo button with gradient and animations
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.accentBlue,
                AppColors.accentBlue.withValues(alpha: 0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentBlue.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isIOS
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.camera,
                        size: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Take Photo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onImagePicked(ImageSource.camera);
                  },
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 24),
                  label: const Text(
                    'TAKE PHOTO',
                    style: TextStyle(
                      letterSpacing: 1.0,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    onImagePicked(ImageSource.camera);
                  },
                ),
        )
        .animate(delay: 100.milliseconds)
        .fadeIn(duration: 600.milliseconds)
        .slideY(begin: 0.3, end: 0),
        
        const SizedBox(height: 16),
        
        // Choose from gallery button with premium styling
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade800.withValues(alpha: 0.8),
                Colors.grey.shade900.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: AppColors.accentBlue.withValues(alpha: 0.5), 
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isIOS
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.photo_on_rectangle,
                        size: 24,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onImagePicked(ImageSource.gallery);
                  },
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: Icon(Icons.photo_library_rounded, size: 24, color: AppColors.accentBlue),
                  label: Text(
                    'CHOOSE FROM GALLERY',
                    style: TextStyle(
                      letterSpacing: 1.0,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onImagePicked(ImageSource.gallery);
                  },
                ),
        )
        .animate(delay: 200.milliseconds)
        .fadeIn(duration: 600.milliseconds)
        .slideY(begin: 0.3, end: 0),
        
        const SizedBox(height: 16),
        
        // Continue button with dynamic styling based on photo selection
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selectedImage != null 
              ? LinearGradient(
                  colors: [
                    Colors.green.shade500,
                    Colors.green.shade600,
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.grey.shade800,
                    Colors.grey.shade900,
                  ],
                ),
            boxShadow: selectedImage != null ? [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ] : null,
          ),
          child: isIOS
              ? CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.transparent,
                  disabledColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: selectedImage != null ? () {
                    HapticFeedback.mediumImpact();
                    onContinue();
                  } : null,
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: selectedImage != null ? Colors.white : Colors.grey.shade500,
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
                  onPressed: selectedImage != null ? () {
                    HapticFeedback.mediumImpact();
                    onContinue();
                  } : null,
                  child: Text(
                    'CONTINUE',
                    style: TextStyle(
                      letterSpacing: 1.0,
                      color: selectedImage != null ? Colors.white : Colors.grey.shade500,
                    ),
                  ),
                ),
        )
        .animate(delay: 300.milliseconds)
        .fadeIn(duration: 600.milliseconds)
        .slideY(begin: 0.3, end: 0),
      ],
    );
  }
}
