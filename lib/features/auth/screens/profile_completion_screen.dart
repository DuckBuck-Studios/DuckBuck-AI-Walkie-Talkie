import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isFullscreenPreview = false;
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
      
      // Move from photo to name step with animation
      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      // Complete profile
      _completeProfile();
    }
  }

  // Go back to the previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      HapticFeedback.mediumImpact();
    }
  }
  
  // Toggle fullscreen preview
  void _toggleFullscreenPreview() {
    if (_selectedImage != null) {
      setState(() {
        _isFullscreenPreview = !_isFullscreenPreview;
      });
      HapticFeedback.mediumImpact();
    }
  }

  // Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  // Take a photo with camera
  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedImage = File(photo.path);
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      setState(() {
        _errorMessage = 'Failed to take photo: $e';
      });
    }
  }

  // Complete profile and navigate to home
  Future<void> _completeProfile() async {
    // Validate name
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _currentStep = 1;
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    // Validate photo (now mandatory)
    if (_selectedImage == null) {
      setState(() {
        _currentStep = 0;
        _errorMessage = 'Please select a profile photo';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final displayName = _nameController.text.trim();
      String? photoURL;

      // Upload image if selected
      if (_selectedImage != null) {
        photoURL = await _uploadProfileImage(_selectedImage!);
      }

      // Update user profile
      final authProvider = Provider.of<AuthStateProvider>(
        context,
        listen: false,
      );

      await authProvider.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
      );

      // IMPORTANT: Mark user onboarding as complete (removes isNewUser flag)
      await authProvider.markUserOnboardingComplete();
      debugPrint('✅ User onboarding marked as complete');

      // Track analytics event
      _analyticsService.logEvent(
        name: 'profile_completed',
        parameters: {
          'has_photo': _selectedImage != null ? 'yes' : 'no',
          'display_name_length': displayName.length,
        },
      );

      // Navigate to home screen with animation
      if (mounted) {
        // First animate the current screen
        Future.delayed(const Duration(milliseconds: 300), () {
          // Then navigate to home
          AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
            arguments: {
              'animated': true, // Let the home screen know to animate in
            },
          );
        });
      }
    } catch (e) {
      debugPrint('Error completing profile: $e');
      setState(() {
        _errorMessage = 'Failed to complete profile: $e';
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button navigation
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black, // Pure black background
        appBar: AppBar(
          backgroundColor: Colors.black,
          automaticallyImplyLeading: _currentStep > 0, // Show back button only on name step
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _previousStep,
                )
              : null,
          elevation: 0,
          toolbarHeight: 0, // Minimize app bar height
        ),
        body: SafeArea(
          child: _isLoading
              ? _buildLoadingState()
              : _isFullscreenPreview && _selectedImage != null
                  ? _buildFullscreenPreview()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _currentStep == 0
                          ? _buildPhotoStep()
                          : _buildNameStep(),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: _currentStep == 0 
                                  ? const Offset(-1, 0) 
                                  : const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutQuart,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                    ).animate().fadeIn(duration: 300.ms),
        ),
      ),
    );
  }

  // Loading indicator
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accentBlue),
          const SizedBox(height: 24),
          Text(
            'Setting up your profile...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // Step 2: Name input (now second)
  Widget _buildNameStep() {
    return Container(
      color: Colors.black,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top section with profile photo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
              color: Colors.black,
              child: Column(
                children: [
                  // Profile photo with green circle
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Green circle
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accentBlue, // Green circle
                            width: 3,
                          ),
                        ),
                      ),
                      
                      // Profile photo
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey[600],
                              )
                            : null,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Change photo button
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_camera_rounded, size: 16),
                    label: Text(
                      _selectedImage != null ? 'Change Photo' : 'Add Photo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentBlue, // Green text
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content with name input
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'What should we call you?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            
                    const SizedBox(height: 16),
            
                    Text(
                      'This name will be displayed to other users in the app.',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                    ),
            
                    const SizedBox(height: 40),
            
                    // Name input field
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'Enter your full name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.accentBlue.withOpacity(0.5), // Green border
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.accentBlue, // Green border when focused
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.accentBlue.withOpacity(0.8),
                        ),
                        suffixIcon: _nameController.text.isNotEmpty
                            ? Icon(
                                Icons.check_circle,
                                color: AppColors.accentBlue,
                              )
                            : null,
                        labelStyle: TextStyle(
                          color: Colors.grey[400],
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: Colors.black,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          if (_errorMessage != null && _errorMessage!.contains('name')) {
                            _errorMessage = null;
                          }
                        });
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _completeProfile(),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom section with complete button
            Container(
              padding: const EdgeInsets.all(24.0),
              color: Colors.black,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[300], size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[300], fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
            
                  // Complete button with green accent
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _completeProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue, // Green button
                        foregroundColor: Colors.black, // Black text
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Complete Profile',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 1: Photo selection (now first)
  Widget _buildPhotoStep() {
    return Container(
      color: Colors.black, // Pure black background
      child: Column(
        children: [
          const SizedBox(height: 60),
          
          // Welcome header
          Text(
            'Welcome to DuckBuck',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 60),
          
          // Profile image preview with green circle
          Expanded(
            child: _buildProfileImagePreview(),
          ),
          
          const SizedBox(height: 20),
          
          // Photo selection buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_rounded, size: 24),
                    label: const Text('Gallery', 
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, // Black button
                      foregroundColor: Colors.white, // White text
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.accentBlue, // Green border
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Camera button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 24),
                    label: const Text('Camera',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black, // Black button
                      foregroundColor: Colors.white, // White text
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: AppColors.accentBlue, // Green border
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[300], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Continue button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _selectedImage != null ? _nextStep : null, // Button disabled if no photo
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue, // Green button
                  foregroundColor: Colors.black, // Black text
                  disabledBackgroundColor: AppColors.accentBlue.withOpacity(0.4),
                  disabledForegroundColor: Colors.black.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: _selectedImage != null 
                          ? Colors.black 
                          : Colors.black.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Profile image preview with green circle
  Widget _buildProfileImagePreview() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Green circle
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentBlue, // Green circle
                width: 3,
              ),
            ),
          ),
            
          // Profile image container
          GestureDetector(
            onTap: _selectedImage != null ? _toggleFullscreenPreview : _pickImage,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withOpacity(0.3), // Green glow
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 2,
                ),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          size: 60,
                          color: AppColors.accentBlue.withOpacity(0.8), // Green icon
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),

          // Photo required indicator
          if (_selectedImage == null)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accentBlue.withOpacity(0.5), // Green border
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.accentBlue, // Green icon
                      size: 16, 
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'A profile photo is required',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Fullscreen image preview
  Widget _buildFullscreenPreview() {
    return GestureDetector(
      onTap: _toggleFullscreenPreview,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Black background
          Container(
            color: Colors.black,
          ),
          
          // Image with border
          Container(
            margin: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.accentBlue.withOpacity(0.5), // Green border
                width: 1,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          
          // Top bar with title and controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.black,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        // Edit button
                        IconButton(
                          icon: Icon(Icons.edit, color: AppColors.accentBlue, size: 24), // Green icon
                          onPressed: () {
                            _toggleFullscreenPreview();
                            _pickImage();
                          },
                        ),
                        const SizedBox(width: 8),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 24),
                          onPressed: _toggleFullscreenPreview,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom bar with accept button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: Colors.black,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: _toggleFullscreenPreview,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue, // Green button
                      foregroundColor: Colors.black, // Black text
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
