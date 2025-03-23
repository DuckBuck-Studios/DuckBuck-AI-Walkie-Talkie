import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../widgets/animated_background.dart';
import 'profile_photo_preview_screen.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure onboarding stage is set correctly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingStage();
    });
  }

  // Check and update onboarding stage if needed
  Future<void> _checkOnboardingStage() async {
    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
    final stage = await authProvider.getOnboardingStage();
    
    // If we're not at the profilePhoto stage, update it
    if (stage != auth.OnboardingStage.profilePhoto) {
      await authProvider.updateOnboardingStage(auth.OnboardingStage.profilePhoto);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent going back
      child: Scaffold(
        body: DuckBuckAnimatedBackground(
          child: SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Camera icon
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A76A).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 60,
                      color: Color(0xFFD4A76A),
                    ),
                  )
                  .animate()
                  .scale(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  
                  // Title and subtitle
                  Text(
                    "Set your profile photo",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(begin: 0.3, end: 0),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  
                  Text(
                    "Add a photo to help others recognize you",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 200),
                  ),
                  
                  const Spacer(flex: 4),
                  
                  // Choose profile picture button - move to bottom of screen
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 30.0, 
                        right: 30.0, 
                        bottom: 30.0
                      ),
                      child: DuckBuckButton(
                        text: 'Choose profile picture',
                        onTap: _showImageSourceBottomSheet,
                        color: const Color(0xFFD4A76A),
                        borderColor: const Color(0xFFB38B4D),
                        textColor: Colors.white,
                        alignment: MainAxisAlignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          letterSpacing: 0.5,
                        ),
                        height: 55,
                        width: double.infinity,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Pick an image
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedImage == null) {
        return;
      }
      
      // Navigate to preview screen
      if (mounted) {
        // Navigate to the preview screen with just a pushReplacement
        // The preview screen will handle completing onboarding and navigating to home
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProfilePhotoPreviewScreen(
              imagePath: pickedImage.path,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Unable to access image. Please try again.');
      print('Profile photo error: $e');
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            const Text(
              'Choose an option',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A76A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFFD4A76A),
                ),
              ),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropImage(ImageSource.camera);
              },
            ),
            
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A76A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: Color(0xFFD4A76A),
                ),
              ),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndCropImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}