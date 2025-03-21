import 'package:flutter/material.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import '../../services/user_service.dart'; 
import '../Home/home_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as auth;
import 'package:lottie/lottie.dart';  // Add this import at the top

class ProfilePhotoPreviewScreen extends StatefulWidget {
  final String imagePath;

  const ProfilePhotoPreviewScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ProfilePhotoPreviewScreen> createState() => _ProfilePhotoPreviewScreenState();
}

class _ProfilePhotoPreviewScreenState extends State<ProfilePhotoPreviewScreen> {
  bool _isLoading = false;
  String _progressMessage = '';
  // Create a direct instance of UserService instead of using Provider
  final UserService _userService = UserService();

  Future<void> _setProfilePhoto() async {
    setState(() {
      _isLoading = true;
      _progressMessage = 'Preparing image...';
    });

    try {
      // Get the current user ID directly from UserService
      final userId = _userService.currentUserId;
      
      if (userId == null) {
        _showErrorMessage('User not logged in. Please sign in again.');
        return;
      }
      
      setState(() {
        _progressMessage = 'Saving profile photo...';
      });
      
      // Upload the profile image using direct instance
      final success = await _userService.uploadAndUpdatePhoto(
        userId, 
        File(widget.imagePath),
      );
      
      if (!success) {
        _showErrorMessage('Failed to upload profile photo. Please check your internet connection and try again.');
        return;
      }
      
      // Set onboarding as completed in Firestore metadata
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Get the current user metadata
      final currentMetadata = authProvider.userModel?.metadata ?? {};
      
      // Create a clean metadata object with only essential user data
      final cleanMetadata = {
        'dateOfBirth': currentMetadata['dateOfBirth'],
        'gender': currentMetadata['gender'],
        'current_onboarding_stage': 'completed'  // Mark onboarding as complete
      };
      
      // Update the user profile with clean metadata
      await authProvider.updateUserProfile(
        metadata: cleanMetadata,
      );
      
      setState(() {
        _progressMessage = 'Profile photo saved!';
      });

      // Refresh user model to ensure it has the latest data
      await authProvider.refreshUserModel();
      
      setState(() {
        _progressMessage = 'Profile photo saved!';
      });
      
      // Add a small delay to show success before navigating
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate to home screen with animation if mounted, clearing all previous screens
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child.animate().fade().scale(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to set profile photo: ${e.toString()}';
      print('Error in _setProfilePhoto: $errorMessage');
      _showErrorMessage(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    print('Showing error message: $message');
    
    // Instead of using a SnackBar which can have positioning issues,
    // show a custom error message at the top of the screen
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade800,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        )
        .animate()
        .scale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Use a more responsive layout approach without fixed positioning
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Image container (takes most of the screen)
                Expanded(
                  child: Center(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                    )
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 300),
                    ),
                  ),
                ),
                
                // Bottom action buttons with vertical layout
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 24.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Set button (on top)
                      DuckBuckButton(
                        text: 'Set',
                        onTap: _isLoading ? () {} : _setProfilePhoto,
                        color: const Color(0xFFD4A76A),
                        borderColor: const Color(0xFFB38B4D),
                        textColor: Colors.white,
                        height: 55,
                        width: double.infinity,
                        alignment: MainAxisAlignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                        isLoading: _isLoading,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Cancel button (below)
                      DuckBuckButton(
                        text: 'Cancel',
                        onTap: _isLoading ? () {} : () => Navigator.of(context).pop(),
                        color: Colors.grey.shade800,
                        borderColor: Colors.grey.shade600,
                        textColor: Colors.white,
                        height: 55,
                        width: double.infinity,
                        alignment: MainAxisAlignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                        isLoading: false,
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                  )
                  .slideY(begin: 0.3, end: 0),
                ),
              ],
            ),
            
            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: Lottie.asset(
                            'assets/animations/loading.json',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _progressMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 200)),
              ),
          ],
        ),
      ),
    );
  }
}