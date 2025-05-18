import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../../../core/theme/app_colors.dart';

/// Component for entering and verifying phone number
class PhoneVerificationView extends StatelessWidget {
  /// Text controller for the phone number input
  final TextEditingController phoneController;
  
  /// The currently selected country code (e.g., +1, +91)
  final String countryCode;
  
  /// Callback when country code is changed
  final Function(String) onCountryCodeChanged;
  
  /// Callback when the verify button is pressed
  final VoidCallback onVerifyPressed;
  
  /// Callback to go back to the previous screen
  final VoidCallback onBackPressed;
  
  /// Whether loading state is active
  final bool isLoading;

  const PhoneVerificationView({
    super.key,
    required this.phoneController,
    required this.countryCode,
    required this.onCountryCodeChanged,
    required this.onVerifyPressed,
    required this.onBackPressed,
    this.isLoading = false,
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
        _buildPhoneInput(context),
        SizedBox(height: verticalSpacing),
        _buildVerifyButton(),
        SizedBox(height: isIOS ? 20 : 24),
        _buildBackButton(),
        SizedBox(height: isIOS ? 12 : 16),
      ],
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        'We\'ll send you a verification code',
        style: TextStyle(
          fontSize: 16,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    // Common country code picker configuration
    Widget countryCodeSelector = CountryCodePicker(
      onChanged: (CountryCode code) {
        onCountryCodeChanged(code.dialCode ?? '+1');
      },
      initialSelection: 'US',
      showCountryOnly: false,
      showOnlyCountryWhenClosed: false,
      alignLeft: false,
      padding: EdgeInsets.zero,
      textStyle: TextStyle(
        fontSize: isIOS ? 15 : 16,
        color: AppColors.textPrimary,
      ),
      dialogTextStyle: TextStyle(
        fontSize: isIOS ? 15 : 16,
        color: AppColors.textPrimary,
      ),
      searchStyle: TextStyle(
        fontSize: isIOS ? 15 : 16,
        color: AppColors.textPrimary,
      ),
      dialogSize: const Size(320, 500),
      comparator: (a, b) => a.name!.compareTo(b.name!),
      flagDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
      ),
      boxDecoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
    );
    
    // Platform-specific text field
    Widget phoneInputField;
    if (isIOS) {
      phoneInputField = Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CupertinoTextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
            placeholder: 'Phone number',
            placeholderStyle: const TextStyle(
              fontSize: 15,
              color: AppColors.textTertiary,
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: null,  // No border as it's handled by the container
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ),
      );
    } else {
      phoneInputField = Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Phone number',
              hintStyle: TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              LengthLimitingTextInputFormatter(10),
            ],
          ),
        ),
      );
    }
    
    return Container(
      height: 56, // Taller for better touch target
      decoration: BoxDecoration(
        color: isIOS ? Colors.black : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(isIOS ? 12 : 16),
        border: Border.all(
          color: AppColors.accentBlue.withOpacity(0.3), // Subtle accent border
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Country code picker with better padding
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: countryCodeSelector,
          ),
          
          // Vertical divider with improved styling
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.accentBlue.withOpacity(0.2),
          ),
          
          // Phone number input field
          phoneInputField,
        ],
      ),
    );
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
          disabledColor: AppColors.accentBlue.withOpacity(0.5),
          child: isLoading
              ? const CupertinoActivityIndicator(
                  color: Colors.white,
                )
              : const Text(
                  'Send Code',
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
                  'Send Code',
                  style: TextStyle(
                    fontSize: 17, // Slightly larger text
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }
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
