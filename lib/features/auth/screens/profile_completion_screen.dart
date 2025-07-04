import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
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

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  // Step tracking
  int _currentStep = 0; // 0 = photo, 1 = name

  // Form controllers and state
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;

  // Repository and Services
  late final UserRepository _userRepository;
  late final LoggerService _logger;

  @override
  void initState() {
    super.initState();

    // Initialize repository and services
    _userRepository = serviceLocator<UserRepository>();
    _logger = serviceLocator<LoggerService>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Move to the next step with simple feedback
  void _nextStep() async {
    if (_currentStep == 0) {
      if (_selectedImage == null) {
        // Show photo selection options
        _showPhotoSelectionOptions();
        return;
      }
      
      // Simple haptic feedback
      HapticFeedback.lightImpact();
      
      // Move from photo to name step
      setState(() {
        _currentStep = 1;
      });
      
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

      // Generate and save FCM token for push notifications after profile completion
      final currentUser = _userRepository.currentUser;
      if (currentUser != null) {
        try {
          _logger.i('ProfileCompletion', 'Generating FCM token for user: ${currentUser.uid}');
          await _userRepository.generateAndSaveFcmToken(currentUser.uid);
          _logger.i('ProfileCompletion', 'FCM token generated and saved successfully');
        } catch (e) {
          // Log error but don't fail the profile completion process
          _logger.e('ProfileCompletion', 'Failed to generate FCM token (non-critical): ${e.toString()}');
        }

        // Mark user onboarding as complete using UserRepository
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

  /// Navigate to home screen with simple transition
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavigation(),
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
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Current step UI content with simple transitions
                              Flexible(
                                child: Container(
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width - 48,
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
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
                    
                    // Fixed bottom button area
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

  /// Build the fixed bottom button area
  Widget _buildBottomButtonArea(bool isIOS) {
    return Container(
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
        ),
      ),
    );
  }
}
