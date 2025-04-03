import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../screens/Home/home_screen.dart';
import 'profile_photo_preview_screen.dart';
import '../../widgets/animated_background.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  bool _isLoading = false;

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
      onWillPop: () async => !_isLoading, // Prevent going back during loading
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
                  
                  // User profile icon
                  Container(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: MediaQuery.of(context).size.width * 0.3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A76A).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_a_photo,
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
                    "Add a profile photo",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 500))
                  .slideY(begin: 0.3, end: 0),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  
                  Text(
                    "Help people recognize you",
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
                  
                  const Spacer(flex: 2),
                  
                  // Photo source options with Lottie animations
                  _isLoading 
                  ? Center(
                      child: Container(
                        height: 100,
                        width: 100,
                        alignment: Alignment.center,
                        child: Lottie.asset(
                          'assets/animations/loading1.json',
                          width: 100,
                          height: 100,
                          repeat: true,
                          animate: true,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLottiePhotoOption(
                          context,
                          animationPath: 'assets/animations/camera.json',
                          label: 'Camera',
                          onTap: () => _getImage(ImageSource.camera),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.06),
                        _buildLottiePhotoOption(
                          context,
                          animationPath: 'assets/animations/gallery.json',
                          label: 'Gallery',
                          onTap: () => _getImage(ImageSource.gallery),
                        ),
                      ],
                    )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 500),
                    delay: const Duration(milliseconds: 300),
                  )
                  .slideY(begin: 0.2, end: 0),
                  
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLottiePhotoOption(
    BuildContext context, {
    required String animationPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              width: 120,
              child: Lottie.asset(
                animationPath,
                repeat: true,
                animate: true,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8B4513),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    if (_isLoading) return;
    
    try {
      setState(() => _isLoading = true);
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (image != null && mounted) {
        // Navigate to preview screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilePhotoPreviewScreen(
              imagePath: image.path,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}