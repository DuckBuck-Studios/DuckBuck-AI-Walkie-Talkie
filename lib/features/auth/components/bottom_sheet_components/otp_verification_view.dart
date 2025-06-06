import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';

/// Component for entering and verifying OTP code
class OtpVerificationView extends StatelessWidget {
  /// Text controller for the OTP input
  final TextEditingController otpController;
  
  /// Phone number that was verified (for display)
  final String phoneNumber;
  
  /// Callback when the verify button is pressed
  final VoidCallback onVerifyPressed;
  
  /// Callback when request new code is pressed
  final VoidCallback onResendPressed;
  
  /// Callback to go back to the previous screen
  final VoidCallback onBackPressed;
  
  /// Whether loading state is active
  final bool isLoading;
  
  /// Whether resend is in cooldown
  final bool isResendDisabled;
  
  /// Countdown text for resend button
  final String? resendCountdownText;

  const OtpVerificationView({
    super.key,
    required this.otpController,
    required this.phoneNumber,
    required this.onVerifyPressed,
    required this.onResendPressed,
    required this.onBackPressed,
    this.isLoading = false,
    this.isResendDisabled = false,
    this.resendCountdownText,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double verticalSpacing = isIOS ? screenHeight * 0.025 : screenHeight * 0.03;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // Center all content
      children: [
        SizedBox(height: screenHeight * 0.01), // Small top padding
        _buildHeader(),
        SizedBox(height: verticalSpacing),
        _buildOtpInput(),
        SizedBox(height: verticalSpacing),
        _buildVerifyButton(),
        SizedBox(height: isIOS ? 16 : 20),
        _buildResendOption(),
        SizedBox(height: isIOS ? 16 : 20),
        _buildBackButton(),
        SizedBox(height: isIOS ? 12 : 16),
      ],
    );
  }

  Widget _buildHeader() {
    final bool isIOS = Platform.isIOS;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        'Enter the code sent to $phoneNumber',
        style: TextStyle(
          fontSize: isIOS ? 16 : 17,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOtpInput() {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        width: double.infinity,
        child: CupertinoTextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 28, // Larger font for better visibility
            fontWeight: FontWeight.w600,
            letterSpacing: 18, // More spacing between characters
            color: Colors.white,
          ),
          placeholder: '••••••',
          placeholderStyle: const TextStyle(
            fontSize: 28,
            letterSpacing: 18,
            color: AppColors.textTertiary,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.accentBlue.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        width: double.infinity,
        child: TextField(
          controller: otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 28, // Larger font for better visibility
            fontWeight: FontWeight.w600,
            letterSpacing: 18, // More spacing between characters
            color: Colors.white,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: const TextStyle(
              fontSize: 28,
              letterSpacing: 18,
              color: AppColors.textTertiary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.accentBlue.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.accentBlue.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.accentBlue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
        ),
      );
    }
  }

  Widget _buildVerifyButton() {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        height: 56, // Taller button for better touch target
        child: CupertinoButton(
          onPressed: isLoading ? null : onVerifyPressed,
          color: AppColors.accentBlue,
          borderRadius: BorderRadius.circular(28), // More rounded corners for iOS
          padding: EdgeInsets.zero,
          disabledColor: AppColors.accentBlue.withValues(alpha: 0.5),
          child: isLoading
              ? const CupertinoActivityIndicator(
                  color: Colors.white,
                )
              : const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 17, // Slightly larger text
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 56, // Taller button for better touch target
        child: ElevatedButton(
          onPressed: isLoading ? null : onVerifyPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            elevation: 1, // Subtle elevation
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Less rounded for Android
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5, // Slightly thicker
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 17, // Slightly larger text
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }
  }

  Widget _buildResendOption() {
    final bool isIOS = Platform.isIOS;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Didn\'t receive the code? ',
          style: TextStyle(
            fontSize: isIOS ? 14 : 15,
            color: AppColors.textSecondary,
          ),
        ),
        if (isIOS)
          CupertinoButton(
            onPressed: isResendDisabled ? null : onResendPressed,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            child: isLoading && isResendDisabled ? 
              // Show loading indicator for iOS
              const CupertinoActivityIndicator(radius: 8, color: AppColors.accentBlue) :
              Text(
                resendCountdownText ?? 'Resend',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isResendDisabled
                      ? AppColors.textTertiary
                      : AppColors.accentBlue,
                ),
              ),
          )
        else
          isLoading && isResendDisabled ?
            // Show loading indicator for Android
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
              ),
            ) :
            TextButton(
              onPressed: isResendDisabled ? null : onResendPressed,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
                foregroundColor: AppColors.accentBlue,
              ),
              child: Text(
                resendCountdownText ?? 'Resend',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isResendDisabled
                      ? AppColors.textTertiary
                      : AppColors.accentBlue,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildBackButton() {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      return CupertinoButton(
        onPressed: onBackPressed,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.back,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Back',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    } else {
      return TextButton.icon(
        onPressed: onBackPressed,
        icon: const Icon(
          Icons.arrow_back,
          size: 18,
          color: AppColors.textSecondary,
        ),
        label: const Text(
          'Back',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
      );
    }
  }
}
