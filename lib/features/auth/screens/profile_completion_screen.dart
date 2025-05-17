import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/core/navigation/app_routes.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';
import 'package:duckbuck/core/services/firebase/firebase_storage_service.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/theme/app_colors.dart';
import 'package:duckbuck/features/auth/providers/auth_state_provider.dart';

/// Screen for completing user profile after signup
/// Collects user's display name and profile photo
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

  // Services
  late final FirebaseStorageService _storageService;
  late final FirebaseAnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _storageService = serviceLocator<FirebaseStorageService>();
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();

    // Log screen view for analytics
    _analyticsService.logScreenView(
      screenName: 'profile_completion_screen',
      screenClass: 'ProfileCompletionScreen',
    );

    // Add haptic feedback when screen appears
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Move to the next step with animation
  void _nextStep() {
    if (_currentStep == 0) {
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
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
      
      // Move from photo to name step with animation
      setState(() {
        _currentStep = 1;
      });
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
      final user = authProvider.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload to Firebase Storage
      final downloadUrl = await _storageService.uploadProfileImage(
        userId: user.uid,
        imageFile: imageFile,
      );

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
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

      // Log successful profile update
      _analyticsService.logEvent(
        name: 'profile_update_success',
        parameters: {
          'updated_photo': updatingPhoto ? '1' : '0', // Convert boolean to string
          'updated_name': updatingName ? '1' : '0', // Convert boolean to string
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Mark user onboarding as complete in Firestore
      await authProvider.markUserOnboardingComplete();

      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
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
      backgroundColor: AppColors.backgroundBlack.withOpacity(0.8),
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
      child: WillPopScope(
        onWillPop: () async {
          // Always prevent back press during profile completion
          return false;
        },
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
      color: Colors.black.withOpacity(0.7),
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

  /// Build the fixed bottom button area with continue/complete button
  Widget _buildBottomButtonArea(bool isIOS) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundBlack,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _currentStep == 0 
            ? // Continue button for photo step
              isIOS
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    color: _selectedImage != null ? AppColors.accentBlue : Colors.grey.shade700,
                    disabledColor: Colors.grey.shade700,
                    onPressed: _nextStep, // Allow continuing even without photo
                    child: const Text('Continue'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedImage != null ? AppColors.accentBlue : Colors.grey.shade700,
                      disabledBackgroundColor: Colors.grey.shade700,
                      minimumSize: const Size(double.infinity, 50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _nextStep, // Allow continuing even without photo
                    child: const Text('CONTINUE'),
                  )
            : // Complete profile button for name step
              isIOS
                ? CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    color: AppColors.accentBlue,
                    onPressed: _completeProfile,
                    child: const Text('Complete Profile'),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      minimumSize: const Size(double.infinity, 50),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _completeProfile,
                    child: const Text('COMPLETE PROFILE'),
                  ),
      ),
    );
  }
  
  /// Build profile photo selection content (without buttons)
  Widget _buildProfilePhotoContent(bool isIOS) {
    return Column(
      children: [
        Text(
          'Add a Profile Photo',
          style: TextStyle(
            color: Colors.white,
            fontSize: isIOS ? 24 : 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Help your friends recognize you by adding a profile photo',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: isIOS ? 16 : 17,
          ),
        ),
        const SizedBox(height: 32),
        
        // Profile image preview or placeholder
        GestureDetector(
          onTap: () => _pickImage(),
          child: Hero(
            tag: 'profile_image',
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImage == null
                  ? Icon(
                      isIOS ? CupertinoIcons.camera : Icons.add_a_photo_outlined,
                      size: 50,
                      color: Colors.grey.shade400,
                    )
                  : null,
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Photo selection options
        if (_selectedImage != null)
          Column(
            children: [
              // Change photo option
              isIOS 
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text('Change Photo'),
                      onPressed: () => _pickImage(),
                    )
                  : TextButton(
                      child: const Text('CHANGE PHOTO'),
                      onPressed: () => _pickImage(),
                    ),
            ],
          )
        else
          // Select photo buttons with improved design
          Column(
            children: [
              // Take photo button
              isIOS 
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: AppColors.accentBlue,
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.camera, size: 22, color: Colors.white),
                            const SizedBox(width: 10),
                            const Text(
                              'Take Photo',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        onPressed: () => _pickImage(source: ImageSource.camera),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.camera_alt, size: 22),
                        label: const Text(
                          'TAKE PHOTO',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                        onPressed: () => _pickImage(source: ImageSource.camera),
                      ),
                    ),
              
              const SizedBox(height: 16),
              
              // Choose from gallery button
              isIOS 
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accentBlue.withOpacity(0.5), width: 1),
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.photo, size: 22, color: AppColors.accentBlue),
                            const SizedBox(width: 10),
                            Text(
                              'Choose from Library',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.accentBlue),
                            ),
                          ],
                        ),
                        onPressed: () => _pickImage(source: ImageSource.gallery),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.accentBlue, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.photo_library, size: 22, color: AppColors.accentBlue),
                        label: Text(
                          'CHOOSE FROM GALLERY',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.accentBlue, letterSpacing: 0.5),
                        ),
                        onPressed: () => _pickImage(source: ImageSource.gallery),
                      ),
                    ),
            ],
          ),
        
        // Add some bottom padding for scrolling
        const SizedBox(height: 40),
      ],
    );
  }

  /// Build display name content (without buttons)
  Widget _buildDisplayNameContent(bool isIOS) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            'What\'s Your Name?',
            style: TextStyle(
              color: Colors.white,
              fontSize: isIOS ? 24 : 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Enter the name you'd like to use in the app",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: isIOS ? 16 : 17,
            ),
          ),
          const SizedBox(height: 32),
          
          // Name input with platform-specific styling
          isIOS
              ? CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Your name',
                  placeholderStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                  padding: const EdgeInsets.all(16),
                  clearButtonMode: OverlayVisibilityMode.editing,
                  style: const TextStyle(color: Colors.white),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  autocorrect: true,
                )
              : TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(16),
                    hintText: 'Your name',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade800),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade800),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accentBlue),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
          
          // Add some bottom padding for scrolling
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  /// Build step indicator showing progress (photo selection vs. name entry)
  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // First step indicator (Photo)
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentStep == 0 ? AppColors.accentBlue : Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 4),
        
        // Connecting line
        Container(
          width: 16,
          height: 2,
          color: Colors.grey.shade700,
        ),
        const SizedBox(width: 4),
        
        // Second step indicator (Name)
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentStep == 1 ? AppColors.accentBlue : Colors.grey.shade600,
          ),
        ),
      ],
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
            color: isIOS ? CupertinoColors.destructiveRed : Colors.redAccent,
            borderRadius: BorderRadius.circular(isIOS ? 10 : 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
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
