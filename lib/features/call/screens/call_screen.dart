import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;

import '../providers/call_provider.dart';
import '../widgets/call_background_widget.dart';
import '../widgets/caller_name_section.dart';
import '../widgets/call_controls_container.dart';
import '../widgets/call_screen_constants.dart';

/// A production-level call screen widget with modular component architecture
/// Uses separate widgets for background, caller name, and controls for better maintainability
class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        if (!callProvider.isInCall || callProvider.currentCall == null) {
          return const SizedBox.shrink();  
        }

        return PopScope(
          canPop: false,
          child: Platform.isIOS 
              ? _buildCupertinoCallScreen(context, callProvider)
              : _buildMaterialCallScreen(context, callProvider),
        );
      },
    );
  }

  Widget _buildCupertinoCallScreen(BuildContext context, CallProvider callProvider) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: _buildCallContent(context, callProvider, true),
    );
  }

  Widget _buildMaterialCallScreen(BuildContext context, CallProvider callProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCallContent(context, callProvider, false),
    );
  }

  Widget _buildCallContent(BuildContext context, CallProvider callProvider, bool isIOS) {
    // Get caller info
    final callerName = callProvider.currentCall!.callerName;
    final callerPhotoUrl = callProvider.currentCall!.callerPhotoUrl;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen background image
        CallBackgroundWidget(
          photoUrl: callerPhotoUrl,
          displayName: callerName,
          isIOS: isIOS,
        ),
        
        // Gradient overlay for better text readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.black.withValues(alpha: 0.3),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.8),
              ],
              stops: CallScreenConstants.gradientStops,
            ),
          ),
        ),
        
        // Content overlay
        SafeArea(
          child: Column(
            children: [
              // Top section with caller name
              CallerNameSection(
                callerName: callerName,
                isIOS: isIOS,
              ),
              
              // Spacer to push controls to bottom
              const Spacer(),
              
              // Bottom section with call controls
              CallControlsContainer(isIOS: isIOS),
              
              // Bottom padding for controls
              SizedBox(height: MediaQuery.of(context).size.height * CallScreenConstants.bottomHeightFactor),
            ],
          ),
        ),
      ],
    );
  }
}
