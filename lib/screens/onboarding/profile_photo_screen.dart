import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart'; 
import '../../providers/auth_provider.dart' as auth; 
import 'profile_photo_preview_screen.dart'; 

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  
  // Enhanced gradient for background
  final LinearGradient _backgroundGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9C78E), Color(0xFFD4A76A)],
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animationController.forward();
    
    // Ensure onboarding stage is set correctly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnboardingStage();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return WillPopScope(
      onWillPop: () async => !_isLoading, // Prevent going back during loading
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: _backgroundGradient,
          ),
          child: Stack(
            children: [
              // Background decorative elements
              ..._buildBackgroundElements(),
              
              // Main content
              SafeArea(
                child: Container(
                  height: screenHeight,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),
                      
                      // User profile icon with enhanced animation
                      Container(
                        width: screenWidth * 0.3,
                        height: screenWidth * 0.3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB38B4D).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.add_a_photo,
                          size: 60,
                          color: Color(0xFFB38B4D),
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(duration: 600.ms)
                      .scale(
                        duration: 800.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1.0, 1.0),
                      ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Title with enhanced animation
                      Text(
                        "Add a profile photo",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(duration: 600.ms, delay: 200.ms)
                      .slideY(begin: 0.3, end: 0, duration: 800.ms, curve: Curves.easeOutQuint)
                      .shimmer(
                        duration: 1200.ms,
                        delay: 900.ms,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      
                      SizedBox(height: screenHeight * 0.01),
                      
                      // Subtitle with staggered animation
                      Text(
                        "Help people recognize you",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      )
                      .animate(controller: _animationController)
                      .fadeIn(
                        duration: 600.ms,
                        delay: 400.ms,
                      )
                      .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 800.ms),
                      
                      const Spacer(flex: 2),
                      
                      // Photo source options with better design and animations
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
                            _buildEnhancedPhotoOption(
                              context,
                              animationPath: 'assets/animations/camera.json',
                              label: 'Camera',
                              onTap: () => _getImage(ImageSource.camera),
                              delay: 600.ms,
                            ),
                            SizedBox(width: screenWidth * 0.06),
                            _buildEnhancedPhotoOption(
                              context,
                              animationPath: 'assets/animations/gallery.json',
                              label: 'Gallery',
                              onTap: () => _getImage(ImageSource.gallery),
                              delay: 800.ms,
                            ),
                          ],
                        ),
                      
                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedPhotoOption(
    BuildContext context, {
    required String animationPath,
    required String label,
    required VoidCallback onTap,
    required Duration delay,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.4,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 5),
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
                fontWeight: FontWeight.w600,
                color: Color(0xFFB38B4D),
              ),
            ),
          ],
        ),
      ),
    )
    .animate(controller: _animationController)
    .fadeIn(
      duration: 600.ms,
      delay: delay,
    )
    .slideY(begin: 0.3, end: 0, delay: delay, duration: 800.ms, curve: Curves.easeOutQuint)
    .then(delay: 200.ms)
    .shimmer(
      duration: 1500.ms,
      color: Colors.white.withOpacity(0.2),
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
        // Navigate to preview screen with smooth transition
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProfilePhotoPreviewScreen(
              imagePath: image.path,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Use curve animation for smoother transition
              var curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuint,
              );
              
              return FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
            elevation: 8,
          ),
        );
      }
    }
  }
  
  // Add decorative background elements
  List<Widget> _buildBackgroundElements() {
    final screenSize = MediaQuery.of(context).size;
    
    return [
      // Top right decorative circle
      Positioned(
        top: screenSize.height * 0.1,
        right: -screenSize.width * 0.1,
        child: Container(
          width: screenSize.width * 0.4,
          height: screenSize.width * 0.4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 1000.ms)
        .slideX(begin: 0.3, end: 0, duration: 1200.ms, curve: Curves.easeOutQuint),
        
      // Bottom left decorative shape
      Positioned(
        bottom: -screenSize.width * 0.2,
        left: -screenSize.width * 0.1,
        child: Container(
          width: screenSize.width * 0.7,
          height: screenSize.width * 0.7,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(screenSize.width * 0.3),
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 1000.ms, delay: 200.ms)
        .slideY(begin: 0.2, end: 0, duration: 1200.ms, curve: Curves.easeOutQuint),
      
      // Camera related decorative elements
      Positioned(
        top: screenSize.height * 0.25,
        left: screenSize.width * 0.15,
        child: Transform.rotate(
          angle: -0.3,
          child: Container(
            width: 40,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 600.ms, delay: 300.ms)
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 600.ms, 
          delay: 300.ms,
          curve: Curves.elasticOut,
        ),
        
      Positioned(
        bottom: screenSize.height * 0.3,
        right: screenSize.width * 0.2,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ).animate(controller: _animationController)
        .fadeIn(duration: 600.ms, delay: 400.ms)
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 600.ms, 
          delay: 400.ms,
          curve: Curves.elasticOut,
        ),
    ];
  }
}