import 'package:flutter/material.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import '../../services/user_service.dart'; 
import '../Home/home_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as auth;
import 'package:lottie/lottie.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';

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
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
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
                      Container(
                        width: double.infinity,
                        height: 65,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: NeoPopButton(
                          color: const Color(0xFFD4A76A),
                          onTapUp: _isLoading ? () {} : _setProfilePhoto,
                          onTapDown: () {},
                          border: Border.all(
                            color: const Color(0xFFB38B4D),
                            width: 1.5,
                          ),
                          depth: 10,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Set',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Cancel button (below)
                      Container(
                        width: double.infinity,
                        height: 65,
                        child: NeoPopButton(
                          color: Colors.grey.shade800,
                          onTapUp: _isLoading ? () {} : () => Navigator.of(context).pop(),
                          onTapDown: () {},
                          border: Border.all(
                            color: Colors.grey.shade600,
                            width: 1.5,
                          ),
                          depth: 10,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Cancel',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
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
            
            // Optimized Loading Overlay with loading1.json
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD4A76A).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Single loading1.json animation
                        Container(
                          height: 120,
                          width: 120,
                          child: Lottie.asset(
                            'assets/animations/loading1.json',
                            repeat: true,
                            animate: true,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Progress message
                        Text(
                          _progressMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: const Duration(milliseconds: 250)),
          ],
        ),
      ),
    );
  }
}