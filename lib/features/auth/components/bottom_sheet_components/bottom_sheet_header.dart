import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_colors.dart';

/// Reusable header component for auth bottom sheets
class BottomSheetHeader extends StatelessWidget {
  /// Primary title text
  final String title;
  
  /// Optional subtitle text
  final String? subtitle;
  
  /// Whether the header should show a close button
  final bool showCloseButton;
  
  /// Callback when close button is pressed
  final VoidCallback? onClose;

  const BottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showCloseButton = true,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    return Stack(
      children: [
        // Header content with centered green bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Only show title if we really need it (will be hidden for auth options)
            if (title.isNotEmpty && title != 'Sign in to DuckBuck')
              Text(
                title,
                style: TextStyle(
                  fontSize: isIOS ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            
            // Optional subtitle
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: isIOS ? 13 : 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        
        // Optional close button
        if (showCloseButton)
          Positioned(
            top: 8,
            right: 0,
            child: isIOS 
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onClose,
                  child: const Icon(
                    CupertinoIcons.clear,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                )
              : IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
                  splashRadius: 20,
                ),
          ),
      ],
    );
  }
}
