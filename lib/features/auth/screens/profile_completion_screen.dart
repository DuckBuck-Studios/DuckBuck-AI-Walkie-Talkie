import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';
import 'package:duckbuck/core/services/firebase/firebase_storage_service.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/services/notifications/notifications_service.dart';
import 'package:duckbuck/core/services/logger/logger_service.dart';
import 'package:duckbuck/core/theme/app_colors.dart';
import 'package:duckbuck/features/auth/providers/auth_state_provider.dart';
import 'package:duckbuck/core/services/auth/auth_security_manager.dart';
import 'package:duckbuck/features/main_navigation.dart';

/// Screen for completing user profile after signup
/// Collects user's display name and profile photo
class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> 
    with TickerProviderStateMixin {
  // Step tracking
  int _currentStep = 0; // 0 = photo, 1 = name

  // Form controllers and state
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;

  // Premium Animation Controllers
  late AnimationController _stepTransitionController;
  late AnimationController _photoAnimationController;
  late AnimationController _contentAnimationController;
  late AnimationController _loadingAnimationController;
  
  // Sophisticated Animations
  late Animation<double> _photoScaleAnimation;
  late Animation<double> _photoSlideAnimation;
  late Animation<double> _photoFadeAnimation;
  late Animation<double> _photoShimmerAnimation;
  late Animation<double> _contentSlideAnimation;
  late Animation<Offset> _buttonSlideAnimation;

  // Services
  late final FirebaseStorageService _storageService;
  late final FirebaseAnalyticsService _analyticsService;
  late final LoggerService _logger;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _storageService = serviceLocator<FirebaseStorageService>();
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();
    _logger = serviceLocator<LoggerService>();

    // Initialize premium animation controllers
    _stepTransitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _photoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create sophisticated animations
    _photoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _photoAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _photoSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _photoAnimationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutExpo),
    ));
    
    _photoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _photoAnimationController,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
    ));
    
    _photoShimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _photoAnimationController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
    ));
    
    _contentSlideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOutExpo,
    ));
    
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
    ));

    // Start initial animations
    _startInitialAnimations();

    // Log screen view for analytics
    _analyticsService.logScreenView(
      screenName: 'profile_completion_screen',
      screenClass: 'ProfileCompletionScreen',
    );

    // Premium haptic feedback sequence
    _performPremiumHaptics();
  }

  /// Perform sophisticated haptic feedback sequence
  void _performPremiumHaptics() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.lightImpact();
  }

  /// Start initial premium animations
  void _startInitialAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _contentAnimationController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _photoAnimationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stepTransitionController.dispose();
    _photoAnimationController.dispose();
    _contentAnimationController.dispose();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  // Move to the next step with premium animation
  void _nextStep() async {
    if (_currentStep == 0) {
      // Add sophisticated haptic feedback sequence
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      HapticFeedback.lightImpact();
      
      // Log navigation to name step
      _analyticsService.logEvent(
        name: 'profile_completion_next_step',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Log screen view for name step
      _analyticsService.logScreenView(
        screenName: 'profile_name_entry',
        screenClass: 'ProfileCompletionScreen',
      );
      
      // Start sophisticated step transition animation
      _stepTransitionController.forward();
      
      // Move from photo to name step with animation
      setState(() {
        _currentStep = 1;
      });
      
      // Start content animations for the name step
      await Future.delayed(const Duration(milliseconds: 300));
      _contentAnimationController.reset();
      _contentAnimationController.forward();
      
    } else if (_currentStep == 1) {
      // Complete profile
      _completeProfile();
    }
  }
  


  /// Pick image from gallery or camera
  Future<void> _pickImage({ImageSource? source}) async {
    try {
      // If no specific source provided, show bottom sheet to choose
      final ImageSource imageSource = source ?? ImageSource.gallery;

      // Log which source was selected
      _analyticsService.logEvent(
        name: 'profile_photo_source',
        parameters: {'source': imageSource == ImageSource.camera ? 'camera' : 'gallery'},
      );

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
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        
        // Log successful photo selection
        _analyticsService.logEvent(
          name: 'profile_photo_selected',
          parameters: {'source': imageSource == ImageSource.camera ? 'camera' : 'gallery'},
        );
        
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Handle errors (permissions, etc.)
      setState(() {
        _errorMessage = 'Could not select image: $e';
      });
      
      // Log photo selection failure
      _analyticsService.logEvent(
        name: 'profile_photo_error',
        parameters: {'error': e.toString()},
      );
    }
  }

  // Upload profile image to Firebase Storage
  Future<String> _uploadProfileImage(File imageFile) async {
    try {
      final authProvider = Provider.of<AuthStateProvider>(
        context,
        listen: false,
      );
      
      // Try to get user with different methods to ensure we have a valid user
      // First try with cache-optimized method that's more reliable during transitions
      var user = await authProvider.getCurrentUserWithCache();
      
      // If that fails, try the direct property access as fallback
      if (user == null) {
        user = authProvider.currentUser;
        _logger.d('ProfileCompletion', 'Fallback to direct currentUser access');
      }

      // If still null, try to ensure we have a valid token which might trigger auth state update
      if (user == null) {
        _logger.w('ProfileCompletion', 'User not available, attempting to ensure valid token');
        // Get the auth service directly as a last resort
        final authSecurityManager = serviceLocator<AuthSecurityManager>();
        await authSecurityManager.ensureValidToken();
        // Try once more after token refresh
        user = authProvider.currentUser;
      }

      if (user == null) {
        throw Exception('User not authenticated - unable to retrieve user information');
      }

      _logger.i('ProfileCompletion', 'Uploading image for user: ${user.uid}');
      
      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadProfileImage(
        userId: user.uid,
        imageFile: imageFile,
      );

      return downloadUrl;
    } catch (e) {
      _logger.e('ProfileCompletion', 'Error uploading profile image: $e');
      rethrow;
    }
  }

  /// Complete the profile setup process
  Future<void> _completeProfile() async {
    // Validate form if on name step
    if (_currentStep == 1 && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Keep track of what we're updating
      final bool updatingPhoto = _selectedImage != null;
      final bool updatingName = _nameController.text.trim().isNotEmpty;
      
      // Log info about what's being updated
      _analyticsService.logEvent(
        name: 'profile_update_attempt',
        parameters: {
          'updating_photo': updatingPhoto ? '1' : '0', // Convert boolean to string
          'updating_name': updatingName ? '1' : '0', // Convert boolean to string
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Get the current auth provider
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

      // Upload profile image if selected
      String? photoURL;
      if (updatingPhoto) {
        // Upload the file to Firebase Storage
        photoURL = await _uploadProfileImage(_selectedImage!);
      }

      // Update the user profile
      await authProvider.updateProfile(
        displayName: updatingName ? _nameController.text.trim() : null,
        photoURL: photoURL,
      );

      // Mark user onboarding as complete in Firestore
      await authProvider.markUserOnboardingComplete();
      
      // Send welcome email for new social auth users without blocking the UI flow
      // Use the more reliable cached user retrieval method to prevent null user issues
      final user = await authProvider.getCurrentUserWithCache() ?? authProvider.currentUser;
      if (user != null && user.metadata != null && 
          (user.metadata!['authMethod'] == 'google' || user.metadata!['authMethod'] == 'apple')) {
        
        // Get updated user name (preferring the manually entered name)
        final userName = updatingName ? _nameController.text.trim() : (user.displayName ?? 'User');
        final userEmail = user.email ?? '';
        final userMetadata = user.metadata;
        
        // Fire and forget email sending in the background using the centralized email service
        Future(() {
          try {
            // Get service locator instance to access notifications service
            final notificationsService = serviceLocator<NotificationsService>();
            
            // Send welcome email with updated user info (fire-and-forget)
            notificationsService.sendWelcomeEmail(
              email: userEmail,
              username: userName,
              metadata: userMetadata,
            );
            
            // Log welcome email attempt
            _analyticsService.logEvent(
              name: 'welcome_email_sent',
              parameters: {
                'auth_method': userMetadata!['authMethod'] ?? 'unknown',
                'has_custom_name': updatingName ? '1' : '0',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
            
            _logger.i('ProfileCompletion', 'Welcome email sent to $userEmail with name: $userName');
          } catch (e) {
            _logger.e('ProfileCompletion', 'Error sending welcome email: $e');
          }
        });
      }

      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });

      // Navigate to home screen with premium transition
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => 
              const MainNavigation(),
            transitionDuration: const Duration(milliseconds: 1200),
            reverseTransitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              // Premium "profile completion" to "home" celebration transition
              return Stack(
                children: [
                  // Celebration gradient background
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 2.0 * animation.value,
                            colors: [
                              Colors.green.shade400.withValues(alpha: animation.value * 0.3),
                              Colors.blue.shade600.withValues(alpha: animation.value * 0.2),
                              Colors.purple.shade800.withValues(alpha: animation.value * 0.1),
                              Colors.black,
                            ],
                            stops: [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Floating particles effect
                  ...List.generate(12, (index) {
                    final delay = (index * 0.05);
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final animationWithDelay = Curves.easeOutExpo.transform(
                          (animation.value - delay).clamp(0.0, 1.0),
                        );
                        return Positioned(
                          left: 50.0 + (index * 30) * animationWithDelay,
                          top: 100.0 + (index % 3 * 150) * animationWithDelay,
                          child: Opacity(
                            opacity: animationWithDelay * (1 - animationWithDelay),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: [
                                  Colors.amber.shade300,
                                  Colors.green.shade300,
                                  Colors.blue.shade300,
                                ][index % 3],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  
                  // Main content with celebration scale and slide
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..scale(
                        0.7 + (animation.value * 0.3), // Scale from 70% to 100%
                      )
                      ..translate(
                        0.0,
                        (1 - animation.value) * 150, // Slide up from bottom
                        0.0,
                      ),
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                      ),
                      child: child,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    } catch (e) {
      // Log error
      _analyticsService.logEvent(
        name: 'profile_update_error',
        parameters: {'error': e.toString()},
      );

      // Show error message
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update profile: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: isIOS 
          ? _buildCupertinoAppBar(isDarkMode)
          : _buildMaterialAppBar(isDarkMode),
      backgroundColor: AppColors.backgroundBlack,
      body: _isLoading
          ? _buildPlatformSpecificLoadingIndicator(isIOS)
          : _buildMainContent(isIOS),
    );
  }

  /// Build platform-specific loading indicator
  Widget _buildPlatformSpecificLoadingIndicator(bool isIOS) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isIOS 
              ? const CupertinoActivityIndicator(radius: 16)
              : const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.white,
              fontSize: isIOS ? 16 : 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Build Cupertino-style app bar for iOS
  PreferredSizeWidget _buildCupertinoAppBar(bool isDarkMode) {
    return CupertinoNavigationBar(
      backgroundColor: AppColors.backgroundBlack.withValues(alpha: 0.8),
      border: Border.all(color: Colors.transparent),
      // No leading navigator buttons
      automaticallyImplyLeading: false,
      middle: const Text(
        'Complete Your Profile',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ) as PreferredSizeWidget;
  }

  /// Build Material-style app bar for Android
  PreferredSizeWidget _buildMaterialAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: AppColors.backgroundBlack,
      elevation: 0,
      centerTitle: true,
      // No back button
      automaticallyImplyLeading: false,
      title: const Text(
        'Complete Your Profile',
        style: TextStyle(
          color: Colors.white, 
          fontWeight: FontWeight.w600,
        ),
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  /// Build main content based on current step with memory optimizations
  Widget _buildMainContent(bool isIOS) {
    return RepaintBoundary(
      child: PopScope(
        canPop: false, // Always prevent back press during profile completion
        child: SafeArea(
          child: Stack(
            children: [
              // Main content with conditional steps
              Positioned.fill(
                child: Column(
                  children: [
                    // Scrollable Content Area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              
                              // Step indicator
                              _buildStepIndicator(),
                              
                              const SizedBox(height: 32),
                              
                              // Current step UI content only (without buttons)
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: _currentStep == 0
                                    ? _buildProfilePhotoContent(isIOS)
                                    : _buildDisplayNameContent(isIOS),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Fixed bottom button area
                    _buildBottomButtonArea(isIOS),
                  ],
                ),
              ),
              
              // Error message overlay if exists
              if (_errorMessage != null) _buildErrorMessage(isIOS),
              
              // Loading overlay if loading
              if (_isLoading) _buildLoadingOverlay(isIOS),
            ],
          ),
        ),
      ),
    );
  }

  /// Build platform-specific loading overlay
  Widget _buildLoadingOverlay(bool isIOS) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isIOS
                ? const CupertinoActivityIndicator(radius: 16)
                : const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Setting up your profile...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isIOS ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the fixed bottom button area with premium animations and continue/complete button
  Widget _buildBottomButtonArea(bool isIOS) {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (context, child) {
        return SlideTransition(
          position: _buttonSlideAnimation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.backgroundBlack.withValues(alpha: 0.0),
                  AppColors.backgroundBlack.withValues(alpha: 0.8),
                  AppColors.backgroundBlack,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: _currentStep == 0 
                  ? // Photo step - always show all three buttons with premium styling
                    Column(
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
                                      const Icon(CupertinoIcons.camera_fill, size: 24, color: Colors.white),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Take Photo',
                                        style: TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    _pickImage(source: ImageSource.camera);
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
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w700, 
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    _pickImage(source: ImageSource.camera);
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
                                      Icon(CupertinoIcons.photo_fill, size: 24, color: AppColors.accentBlue),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Choose from Library',
                                        style: TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.w500, 
                                          color: AppColors.accentBlue,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _pickImage(source: ImageSource.gallery);
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
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w600, 
                                      color: AppColors.accentBlue, 
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _pickImage(source: ImageSource.gallery);
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
                            gradient: _selectedImage != null 
                              ? LinearGradient(
                                  colors: [
                                    Colors.green.shade600,
                                    Colors.green.shade500,
                                  ],
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.grey.shade700,
                                    Colors.grey.shade800,
                                  ],
                                ),
                            boxShadow: _selectedImage != null ? [
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
                                  onPressed: _selectedImage != null ? () {
                                    HapticFeedback.mediumImpact();
                                    _nextStep();
                                  } : null,
                                  child: Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedImage != null ? Colors.white : Colors.grey.shade500,
                                      letterSpacing: 0.5,
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
                                  onPressed: _selectedImage != null ? () {
                                    HapticFeedback.mediumImpact();
                                    _nextStep();
                                  } : null,
                                  child: Text(
                                    'CONTINUE',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedImage != null ? Colors.white : Colors.grey.shade500,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                        )
                        .animate(delay: 300.milliseconds)
                        .fadeIn(duration: 600.milliseconds)
                        .slideY(begin: 0.3, end: 0),
                      ],
                    )
                  : // Name step - show complete profile button with premium styling
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade600,
                            Colors.blue.shade600,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: isIOS
                          ? CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                _completeProfile();
                              },
                              child: const Text(
                                'Complete Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
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
                              onPressed: () {
                                HapticFeedback.heavyImpact();
                                _completeProfile();
                              },
                              child: const Text(
                                'COMPLETE PROFILE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                    )
                    .animate(delay: 400.milliseconds)
                    .fadeIn(duration: 800.milliseconds)
                    .slideY(begin: 0.5, end: 0)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0)),
            ),
          ),
        );
      },
    );
  }
  
  /// Build profile photo selection content (without buttons) with premium animations
  Widget _buildProfilePhotoContent(bool isIOS) {
    return AnimatedBuilder(
      animation: _photoAnimationController,
      builder: (context, child) {
        final slideValue = _photoSlideAnimation.value;
        final scaleValue = _photoScaleAnimation.value;
        final fadeValue = _photoFadeAnimation.value;
        final shimmerValue = _photoShimmerAnimation.value;
        
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
                      _selectedImage == null 
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
                          gradient: _selectedImage != null 
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
                              color: (_selectedImage != null ? Colors.blue : Colors.purple)
                                  .withValues(alpha: 0.4),
                              blurRadius: 25,
                              offset: const Offset(0, 15),
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(-8, -8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(8, 8),
                            ),
                          ],
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Stack(
                                children: [
                                  // Background shimmer effect
                                  if (shimmerValue > 0)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment(-1.0 + (shimmerValue * 2), -1.0),
                                            end: Alignment(1.0 + (shimmerValue * 2), 1.0),
                                            colors: [
                                              Colors.transparent,
                                              Colors.white.withValues(alpha: 0.2),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  
                                  // Camera icon with bounce animation
                                  Center(
                                    child: Transform.scale(
                                      scale: 1.0 + (shimmerValue * 0.1),
                                      child: Icon(
                                        isIOS ? CupertinoIcons.camera_fill : Icons.add_a_photo_rounded,
                                        size: 60,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : // Selected image overlay with subtle effects
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.1),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.edit,
                                    size: 30,
                                    color: Colors.white,
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
                  if (_selectedImage == null)
                    SizedBox(
                      height: 100,
                      child: Stack(
                        children: List.generate(6, (index) {
                          return Positioned(
                            left: 50.0 + (index * 40) + (shimmerValue * 20),
                            top: 20.0 + (index % 2 * 40) + (shimmerValue * 15),
                            child: Container(
                              width: 4 + (shimmerValue * 2),
                              height: 4 + (shimmerValue * 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: [
                                  Colors.blue.shade300,
                                  Colors.purple.shade300,
                                  Colors.pink.shade300,
                                ][index % 3].withValues(alpha: 0.6 * fadeValue),
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

  /// Build display name content (without buttons) with premium animations
  Widget _buildDisplayNameContent(bool isIOS) {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (context, child) {
        final slideValue = _contentSlideAnimation.value;
        
        return Transform.translate(
          offset: Offset(0, slideValue),
          child: Form(
            key: _formKey,
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
                          controller: _nameController,
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
                          controller: _nameController,
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
  
  /// Build step indicator with premium animations showing progress (photo selection vs. name entry)
  Widget _buildStepIndicator() {
    return AnimatedBuilder(
      animation: _stepTransitionController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First step indicator (Photo) with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: _currentStep == 0 ? 12 : 10,
                height: _currentStep == 0 ? 12 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentStep == 0 ? AppColors.accentBlue : Colors.grey.shade600,
                  boxShadow: _currentStep == 0 ? [
                    BoxShadow(
                      color: AppColors.accentBlue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
              )
              .animate()
              .scale(
                duration: 300.milliseconds,
                curve: Curves.elasticOut,
              ),
              
              const SizedBox(width: 8),
              
              // Step labels
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: _currentStep == 0 ? Colors.white : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: _currentStep == 0 ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                child: const Text('PHOTO'),
              ),
              
              const SizedBox(width: 8),
              
              // Connecting line with gradient animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    colors: _currentStep == 1 
                      ? [AppColors.accentBlue, Colors.grey.shade600]
                      : [Colors.grey.shade700, Colors.grey.shade700],
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Step labels
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  color: _currentStep == 1 ? Colors.white : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: _currentStep == 1 ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
                child: const Text('NAME'),
              ),
              
              const SizedBox(width: 8),
              
              // Second step indicator (Name) with animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: _currentStep == 1 ? 12 : 10,
                height: _currentStep == 1 ? 12 : 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentStep == 1 ? AppColors.accentBlue : Colors.grey.shade600,
                  boxShadow: _currentStep == 1 ? [
                    BoxShadow(
                      color: AppColors.accentBlue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
              )
              .animate()
              .scale(
                duration: 300.milliseconds,
                curve: Curves.elasticOut,
              ),
            ],
          ),
        );
      },
    );
  }
  


  /// Build platform-specific error message
  Widget _buildErrorMessage(bool isIOS) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.destructiveRed,
            borderRadius: BorderRadius.circular(isIOS ? 10 : 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                icon: Icon(
                  isIOS ? CupertinoIcons.clear_circled : Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.milliseconds),
      ),
    );
  }
}
