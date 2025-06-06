
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import 'call_control_button.dart';
import 'call_screen_constants.dart';
import 'platform_icons.dart';

/// Container widget for call control buttons with responsive layout
/// Includes mute, end call, and speaker controls with animations
class CallControlsContainer extends StatelessWidget {
  final bool isIOS;

  const CallControlsContainer({
    super.key,
    required this.isIOS,
  });

  @override
  Widget build(BuildContext context) {
    final buttonMetrics = _getButtonMetrics(context);
    
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        return Container(
          margin: _getControlsMargin(context),
          padding: _getControlsPadding(),
          decoration: _getControlsDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mute button
              CallControlButton(
                icon: callProvider.isMuted 
                    ? PlatformIcons.getMicOffIcon(isIOS)
                    : PlatformIcons.getMicIcon(isIOS),
                isActive: callProvider.isMuted,
                size: buttonMetrics.buttonSize,
                iconSize: buttonMetrics.iconSize,
                onTap: callProvider.toggleMute,
                isIOS: isIOS,
              )
              .animate()
              .scale(
                duration: CallScreenConstants.scaleButtonDuration,
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.0, 1.0),
                curve: Curves.easeInOut,
              ),
              
              SizedBox(width: buttonMetrics.spacing),
              
              // End call button
              CallControlButton(
                icon: PlatformIcons.getCallEndIcon(isIOS),
                isActive: false,
                isEndCall: true,
                size: buttonMetrics.buttonSize,
                iconSize: buttonMetrics.iconSize,
                onTap: callProvider.endCall,
                isIOS: isIOS,
              )
              .animate()
              .scale(
                duration: CallScreenConstants.elasticButtonDuration,
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.0, 1.0),
                curve: Curves.elasticOut,
              ),
              
              SizedBox(width: buttonMetrics.spacing),
              
              // Speaker button
              CallControlButton(
                icon: callProvider.isSpeakerOn 
                    ? PlatformIcons.getSpeakerOnIcon(isIOS)
                    : PlatformIcons.getSpeakerOffIcon(isIOS),
                isActive: callProvider.isSpeakerOn,
                size: buttonMetrics.buttonSize,
                iconSize: buttonMetrics.iconSize,
                onTap: callProvider.toggleSpeaker,
                isIOS: isIOS,
              )
              .animate()
              .scale(
                duration: CallScreenConstants.scaleButtonDuration,
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.0, 1.0),
                curve: Curves.easeInOut,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Calculate responsive button metrics
  ({double buttonSize, double iconSize, double spacing}) _getButtonMetrics(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth <= 320) {
      return (buttonSize: 60.0, iconSize: 20.0, spacing: 16.0);
    } else if (screenWidth <= 375) {
      return (buttonSize: 65.0, iconSize: 22.0, spacing: 18.0);
    } else if (screenWidth <= 414) {
      return (buttonSize: 70.0, iconSize: 24.0, spacing: 20.0);
    } else {
      return (buttonSize: 75.0, iconSize: 26.0, spacing: 24.0);
    }
  }

  /// Calculate responsive margin for controls container
  EdgeInsets _getControlsMargin(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalMargin = screenWidth <= 375 ? 24.0 : 32.0;
    return EdgeInsets.symmetric(horizontal: horizontalMargin);
  }

  /// Standard padding for controls container
  EdgeInsets _getControlsPadding() {
    return const EdgeInsets.symmetric(
      horizontal: 28.0,
      vertical: 22.0,
    );
  }

  /// Styling for the controls container background with platform-specific variations
  BoxDecoration _getControlsDecoration() {
    if (isIOS) {
      // iOS style with more blur and softer appearance
      return BoxDecoration(
        color: Colors.black.withValues(alpha: CallScreenConstants.controlsOpacity + 0.1),
        borderRadius: BorderRadius.circular(CallScreenConstants.borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: CallScreenConstants.controlsBorderOpacity + 0.05),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: CallScreenConstants.lightShadowOpacity),
            blurRadius: 20.0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: CallScreenConstants.veryLightShadowOpacity),
            blurRadius: 40.0,
            offset: const Offset(0, 12),
          ),
        ],
      );
    }
    
    // Material design style with more defined shadows
    return BoxDecoration(
      color: Colors.black.withValues(alpha: CallScreenConstants.controlsOpacity),
      borderRadius: BorderRadius.circular(CallScreenConstants.borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: CallScreenConstants.controlsBorderOpacity),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: CallScreenConstants.mediumShadowOpacity),
          blurRadius: 24.0,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: CallScreenConstants.veryLightShadowOpacity),
          blurRadius: 48.0,
          offset: const Offset(0, 16),
        ),
      ],
    );
  }
}
