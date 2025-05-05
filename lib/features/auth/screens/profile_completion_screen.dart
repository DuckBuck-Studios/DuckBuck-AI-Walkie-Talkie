import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  int _currentStep = 0; // 0 = name, 1 = photo

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

    // Add haptic feedback when screen appears
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Move to the next step
  void _nextStep() {
    if (_currentStep == 0) {
      // Validate name before proceeding
      if (_formKey.currentState!.validate()) {
        setState(() {
          _currentStep = 1;
        });
        HapticFeedback.mediumImpact();
      }
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
        _currentStep = 0;
        _errorMessage = 'Please enter your name';
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

      // Track analytics event
      _analyticsService.logEvent(
        name: 'profile_completed',
        parameters: {
          'has_photo':
              _selectedImage != null
                  ? 'yes'
                  : 'no', // Convert boolean to string
          'display_name_length': displayName.length,
        },
      );

      // Navigate to home screen
      if (mounted) {
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
        );
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

  // Skip photo selection
  void _skipPhoto() {
    _completeProfile();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button navigation
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundBlack,
        appBar: AppBar(
          title: Text(_currentStep == 0 ? 'Your Name' : 'Profile Photo'),
          backgroundColor: AppColors.surfaceBlack,
          automaticallyImplyLeading:
              _currentStep > 0, // Show back button only on photo step
          leading:
              _currentStep > 0
                  ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _previousStep,
                  )
                  : null,
          elevation: 0,
        ),
        body: SafeArea(
          child:
              _isLoading
                  ? _buildLoadingState()
                  : _currentStep == 0
                  ? _buildNameStep()
                  : _buildPhotoStep(),
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
          const CircularProgressIndicator(color: AppColors.accentBlue),
          const SizedBox(height: 24),
          Text(
            'Setting up your profile...',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // Step 1: Name input
  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'What should we call you?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 12),

            Text(
              'This will be displayed to other users in the app.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 40),

            // Name input field
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accentBlue, width: 2),
                ),
                labelStyle: TextStyle(color: AppColors.textSecondary),
                hintStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceBlack,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _nextStep(),
              autofocus: true,
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[300], fontSize: 14),
              ),
            ],

            const Spacer(),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          ],
        ),
      ),
    );
  }

  // Step 2: Photo selection
  Widget _buildPhotoStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      // Wrap the Column with SingleChildScrollView to handle overflow
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Text(
              'Add a profile photo',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 12),

            Text(
              'Choose a photo to personalize your profile',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 40),

            // Profile image preview
            _buildProfileImagePreview().animate().fadeIn(
              duration: 400.ms,
              delay: 200.ms,
            ),

            const SizedBox(height: 40),

            // Photo selection buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceBlack,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.borderColor),
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
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceBlack,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.borderColor),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[300], fontSize: 14),
              ),
            ],

            // Instead of using Spacer() which can cause overflow,
            // use a fixed height SizedBox with enough space
            const SizedBox(height: 40),

            // Action buttons
            Column(
              children: [
                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedImage != null ? _completeProfile : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.accentBlue.withOpacity(
                        0.5,
                      ),
                    ),
                    child: const Text(
                      'Complete Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Skip button
                TextButton(
                  onPressed: _skipPhoto,
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Add some padding at the bottom to ensure there's space on all screens
                const SizedBox(height: 20),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }

  // Profile image preview widget
  Widget _buildProfileImagePreview() {
    return Center(
      child: Stack(
        children: [
          // Profile image container
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlack,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    _selectedImage != null
                        ? AppColors.accentBlue
                        : AppColors.borderColor,
                width: 2,
              ),
              image:
                  _selectedImage != null
                      ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                _selectedImage == null
                    ? Icon(
                      Icons.person,
                      size: 80,
                      color: AppColors.textTertiary,
                    )
                    : null,
          ),

          // Edit button overlay
          if (_selectedImage != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: _pickImage,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
