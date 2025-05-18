import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../core/theme/app_colors.dart';

/// Displays authentication options like Google, Apple, and Phone number
class AuthOptionsView extends StatelessWidget {
  /// Callback when Google auth is selected
  final VoidCallback onGoogleSelected;
  
  /// Callback when Apple auth is selected
  final VoidCallback onAppleSelected;
  
  /// Callback when Phone auth is selected
  final VoidCallback onPhoneSelected;
  
  /// Whether Google auth is in loading state
  final bool isGoogleLoading;
  
  /// Whether Apple auth is in loading state
  final bool isAppleLoading;

  const AuthOptionsView({
    super.key,
    required this.onGoogleSelected,
    required this.onAppleSelected,
    required this.onPhoneSelected,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Using platform-specific spacing with increased spacing for cleaner look
    final bool isIOS = Platform.isIOS;
    final double verticalSpacing = isIOS ? 20.0 : 16.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      width: screenWidth,
      padding: EdgeInsets.only(
        top: screenHeight * 0.04,
        bottom: screenHeight * 0.01,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildGoogleButton(),
          SizedBox(height: verticalSpacing),
          _buildAppleButton(),
          SizedBox(height: verticalSpacing),
          _buildPhoneButton(),
        ],
      ),
    );
  }

  // Title is now moved to the BottomSheetHeader component

  Widget _buildGoogleButton() {
    return _buildSocialButton(
      icon: FontAwesomeIcons.google,
      text: 'Continue with Google',
      isLoading: isGoogleLoading,
      onPressed: isGoogleLoading ? null : () {
        HapticFeedback.lightImpact();
        onGoogleSelected();
      },
      backgroundColor: Colors.white,
      textColor: Colors.black87,
    );
  }

  Widget _buildAppleButton() {
    return _buildSocialButton(
      icon: FontAwesomeIcons.apple,
      text: 'Continue with Apple',
      isLoading: isAppleLoading,
      onPressed: isAppleLoading ? null : () {
        HapticFeedback.lightImpact();
        onAppleSelected();
      },
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
  }

  Widget _buildPhoneButton() {
    return _buildSocialButton(
      icon: Icons.phone,
      text: 'Continue with Phone',
      onPressed: () {
        HapticFeedback.lightImpact();
        onPhoneSelected();
      },
      backgroundColor: AppColors.accentBlue,
      textColor: Colors.white,
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String text,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color textColor,
    bool isLoading = false,
  }) {
    final bool isIOS = Platform.isIOS;
    
    // Shared content for loading and button content
    Widget loadingIndicator = SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(textColor),
      ),
    );
    
    Widget buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 14),
        Text(
          text,
          style: TextStyle(
            fontSize: isIOS ? 16 : 17,
            fontWeight: isIOS ? FontWeight.w600 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
    
    if (isIOS) {
      // iOS-style button with updated rounded corners
      return SizedBox(
        width: double.infinity,
        height: 56, // Taller button for better touch target
        child: CupertinoButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28), // More rounded corners for iOS
          child: isLoading ? loadingIndicator : buttonContent,
        ),
      );
    } else {
      // Android-style button with Material Design improvements
      return SizedBox(
        width: double.infinity,
        height: 56, // Taller button for better touch target
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            elevation: 1, // Subtle elevation
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Less rounded for Android
            ),
          ),
          child: isLoading ? loadingIndicator : buttonContent,
        ),
      );
    }
  }
}
