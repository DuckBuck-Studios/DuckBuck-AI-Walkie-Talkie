
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'call_screen_constants.dart';

/// Individual call control button widget with platform-specific appearance
/// Supports different states: active, inactive, and end call with iOS/Android styling
class CallControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final bool isEndCall;
  final bool isIOS;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.isActive,
    required this.size,
    required this.iconSize,
    required this.onTap,
    required this.isIOS,
    this.isEndCall = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    
    if (isIOS) {
      return CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: buttonStyle.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: buttonStyle.borderColor,
              width: 1.5,
            ),
            boxShadow: buttonStyle.shadows,
          ),
          child: Icon(
            icon,
            color: buttonStyle.iconColor,
            size: iconSize,
          ),
        ),
      );
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: buttonStyle.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: buttonStyle.borderColor,
              width: 1.5,
            ),
            boxShadow: buttonStyle.shadows,
          ),
          child: Icon(
            icon,
            color: buttonStyle.iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  /// Generate button styling based on state
  ({
    Color backgroundColor,
    Color iconColor,
    Color borderColor,
    List<BoxShadow> shadows,
  }) _getButtonStyle() {
    Color backgroundColor;
    Color iconColor;
    Color borderColor;
    List<BoxShadow> shadows;
    
    if (isEndCall) {
      backgroundColor = Colors.red.shade600;
      iconColor = Colors.white;
      borderColor = Colors.red.withValues(alpha: CallScreenConstants.lightShadowOpacity);
      shadows = [
        BoxShadow(
          color: Colors.red.withValues(alpha: CallScreenConstants.mediumShadowOpacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: CallScreenConstants.lightShadowOpacity),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isActive) {
      backgroundColor = Colors.white;
      iconColor = Colors.black87;
      borderColor = Colors.white.withValues(alpha: 0.1);
      shadows = [
        BoxShadow(
          color: Colors.white.withValues(alpha: CallScreenConstants.lightShadowOpacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      backgroundColor = Colors.white.withValues(alpha: 0.15);
      iconColor = Colors.white;
      borderColor = Colors.white.withValues(alpha: 0.1);
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: CallScreenConstants.lightShadowOpacity),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    }
    
    return (
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      borderColor: borderColor,
      shadows: shadows,
    );
  }
}
