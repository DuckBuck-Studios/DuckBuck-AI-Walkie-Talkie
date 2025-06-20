import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/user_repository.dart';
import '../../main_navigation.dart';
import '../widgets/profile_completion/profile_step_indicator.dart';
import '../widgets/profile_completion/profile_photo_section.dart';
import '../widgets/profile_completion/profile_name_section.dart';
  
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

  // Repository and Services
  late final UserRepository _userRepository;
  late final LoggerService _logger;

  @override
  void initState() {
    super.initState();

    // Initialize repository and services
    _userRepository = serviceLocator<UserRepository>();
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
      if (_selectedImage == null) {
        // Show photo selection options
        _showPhotoSelectionOptions();
        return;
      }
      
      // Add sophisticated haptic feedback sequence
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      HapticFeedback.lightImpact();
      
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

  /// Show photo selection options (camera or gallery)
  void _showPhotoSelectionOptions() {
    final isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (BuildContext context) => CupertinoActionSheet(
          title: const Text('Select Profile Photo'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _onImageSelected(ImageSource.camera);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.camera, size: 20),
                  SizedBox(width: 8),
                  Text('Take Photo'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _onImageSelected(ImageSource.gallery);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.photo, size: 20),
                  SizedBox(width: 8),
                  Text('Choose from Gallery'),
                ],
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.backgroundBlack,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Profile Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _onImageSelected(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _onImageSelected(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    }
  }

  /// Handle image selection from camera or gallery
  void _onImageSelected(ImageSource source) async {
    try {
      // Use image picker to select image with optimized settings
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800, // Optimized size for better memory management
        maxHeight: 800, // Optimized size for better memory management
        imageQuality: 80, // Slightly more compressed for better performance
        requestFullMetadata: false, // Skip metadata for faster loading
        preferredCameraDevice: source == ImageSource.camera ? CameraDevice.front : CameraDevice.front, // Prefer front camera for profile photos
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Handle errors (permissions, etc.)
      setState(() {
        _errorMessage = 'Could not select image: $e';
      });
    }
  }

  /// Complete the profile setup process using UserRepository
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

      // Upload profile image if selected (using UserRepository)
      String? photoURL;
      if (updatingPhoto) {
        // Upload through the repository which handles analytics internally
        photoURL = await _uploadProfileImage();
      }

      // Update the user profile through UserRepository
      await _userRepository.updateProfile(
        displayName: updatingName ? _nameController.text.trim() : null,
        photoURL: photoURL,
      );

      // Mark user onboarding as complete using UserRepository
      final currentUser = _userRepository.currentUser;
      if (currentUser != null) {
        await _userRepository.markUserOnboardingComplete(currentUser.uid);
      }
      
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });

      // Navigate to home screen with premium transition
      if (mounted) {
        _navigateToHome();
      }
    } catch (e) {
      // Show error message
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update profile: $e';
      });
    }
  }

  /// Upload profile image through UserRepository
  Future<String> _uploadProfileImage() async {
    final user = await _userRepository.getCurrentUser();
    
    if (user == null) {
      throw Exception('User not authenticated - unable to upload profile image');
    }

    if (_selectedImage == null) {
      throw Exception('No image selected for upload');
    }

    _logger.i('ProfileCompletion', 'Uploading image for user: ${user.uid}');
    
    // Upload through the UserRepository 
    return await _userRepository.uploadProfilePhoto(
      userId: user.uid,
      imageFile: _selectedImage!,
    );
  }

  /// Navigate to home screen with premium transition
  void _navigateToHome() {
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
                              Colors.blue.shade300,
                              Colors.purple.shade300,
                              Colors.green.shade300,
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
            'Setting up your profile...',
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height - 200,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              
                              // Step indicator
                              ProfileStepIndicator(
                                currentStep: _currentStep,
                                stepTransitionController: _stepTransitionController,
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Current step UI content with smooth transitions
                              Flexible(
                                child: Container(
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width - 48,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 600),
                                  switchInCurve: Curves.easeOutExpo,
                                  switchOutCurve: Curves.easeInExpo,
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    // Right to left slide transition with overflow clipping
                                    final slideAnimation = Tween<Offset>(
                                      begin: const Offset(0.3, 0.0), // Reduced slide distance
                                      end: Offset.zero, // End at center
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutExpo,
                                    ));
                                    
                                    // Fade transition for smooth overlay
                                    final fadeAnimation = Tween<double>(
                                      begin: 0.0,
                                      end: 1.0,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                                    ));
                                    
                                    return ClipRect(
                                      child: SlideTransition(
                                        position: slideAnimation,
                                        child: FadeTransition(
                                          opacity: fadeAnimation,
                                          child: child,
                                        ),
                                      ),
                                    );
                                  },
                                  layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                                    return SizedBox(
                                      width: MediaQuery.of(context).size.width - 48, // Account for padding
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        clipBehavior: Clip.hardEdge, // Prevent overflow
                                        children: <Widget>[
                                          ...previousChildren,
                                          if (currentChild != null) currentChild,
                                        ],
                                      ),
                                    );
                                  },
                                  child: _currentStep == 0
                                    ? ProfilePhotoSection(
                                        key: const Key('photo_step'),
                                        selectedImage: _selectedImage,
                                        onImageSelected: (file) {
                                          if (file != null) {
                                            setState(() {
                                              _selectedImage = file;
                                            });
                                          }
                                        },
                                        onError: (error) {
                                          setState(() {
                                            _errorMessage = error;
                                          });
                                        },
                                        photoAnimationController: _photoAnimationController,
                                        photoScaleAnimation: _photoScaleAnimation,
                                        photoSlideAnimation: _photoSlideAnimation,
                                        photoFadeAnimation: _photoFadeAnimation,
                                        photoShimmerAnimation: _photoShimmerAnimation,
                                        isIOS: isIOS,
                                        onEditPhoto: () {
                                          // Show photo selection options when edit icon is tapped
                                          _showPhotoSelectionOptions();
                                        },
                                      )
                                    : ProfileNameSection(
                                        key: const Key('name_step'),
                                        nameController: _nameController,
                                        formKey: _formKey,
                                        contentAnimationController: _contentAnimationController,
                                        contentSlideAnimation: _contentSlideAnimation,
                                        isIOS: isIOS,
                                        onNameChanged: () {
                                          setState(() {
                                            // Trigger rebuild to update progress indicators
                                          });
                                        },
                                      ),
                                  ),
                                ),
                              ),
                              
                              // Add bottom padding to ensure content doesn't get cut off
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Fixed bottom button area with proper SafeArea
                    _buildBottomButtonArea(isIOS),
                  ],
                ),
              ),
              
              // Error message overlay if exists
              if (_errorMessage != null) _buildErrorMessage(isIOS),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the fixed bottom button area with premium animations
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
            ),
            child: SafeArea(
              top: false,
              child: _buildUnifiedActionButton(isIOS),
            ),
          ),
        );
      },
    );
  }

  /// Build unified action button that handles both steps
  Widget _buildUnifiedActionButton(bool isIOS) {
    String buttonText;
    IconData buttonIcon;
    Color buttonColor1, buttonColor2;
    
    if (_currentStep == 0) {
      if (_selectedImage == null) {
        buttonText = 'Select Photo';
        buttonIcon = isIOS ? CupertinoIcons.camera : Icons.camera_alt;
        buttonColor1 = AppColors.accentBlue;
        buttonColor2 = AppColors.accentBlue.withValues(alpha: 0.8);
      } else {
        buttonText = 'Continue';
        buttonIcon = isIOS ? CupertinoIcons.arrow_right : Icons.arrow_forward;
        buttonColor1 = Colors.green.shade600;
        buttonColor2 = Colors.green.shade700;
      }
    } else {
      buttonText = 'Complete Profile';
      buttonIcon = isIOS ? CupertinoIcons.checkmark : Icons.check;
      buttonColor1 = Colors.purple.shade600;
      buttonColor2 = Colors.blue.shade600;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [buttonColor1, buttonColor2],
        ),
      ),
      child: isIOS
          ? CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _nextStep();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(buttonIcon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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
              icon: Icon(buttonIcon, size: 20, color: Colors.white),
              label: Text(
                buttonText.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                _nextStep();
              },
            ),
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
