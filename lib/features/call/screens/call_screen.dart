import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io' show Platform;

import '../providers/call_provider.dart';
import '../../../shared/widgets/call_ui_components.dart';

/// Call screen with consistent UI styling matching the fullscreen photo viewer
/// Uses shared CallUIComponents for consistent positioning and styling
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
          child: (Platform.isIOS 
              ? _buildCupertinoCallScreen(context, callProvider)
              : _buildMaterialCallScreen(context, callProvider))
          .animate()
          .fadeIn(
            duration: 600.ms,
            curve: Curves.easeOut,
          )
          .slideY(
            duration: 800.ms,
            begin: 0.1,
            end: 0.0,
            curve: Curves.easeOutCubic,
          ),
        );
      },
    );
  }

  Widget _buildCupertinoCallScreen(BuildContext context, CallProvider callProvider) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: _buildCallContent(context, callProvider),
    );
  }

  Widget _buildMaterialCallScreen(BuildContext context, CallProvider callProvider) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCallContent(context, callProvider),
    );
  }

  Widget _buildCallContent(BuildContext context, CallProvider callProvider) {
    final callerName = callProvider.currentCall!.callerName;
    final callerPhotoUrl = callProvider.currentCall!.callerPhotoUrl;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen photo with Hero animation
          Hero(
            tag: 'friend_photo_$callerName',
            child: _buildPhoto(context, callerPhotoUrl, callerName),
          )
          .animate()
          .scale(
            duration: 600.ms,
            curve: Curves.easeOutCubic,
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
          )
          .fadeIn(
            duration: 400.ms,
            curve: Curves.easeOut,
          ),
          
          // Call controls at bottom - using shared component for consistent styling
          CallUIComponents.buildCallControls(
            context,
            isMuted: callProvider.isMuted,
            isSpeakerOn: callProvider.isSpeakerOn,
            onToggleMute: () => callProvider.toggleMute(),
            onToggleSpeaker: () => callProvider.toggleSpeaker(),
            onEndCall: () => callProvider.endCall(),
          )
          .animate()
          .slideY(
            duration: 500.ms,
            curve: Curves.easeOutCubic,
            begin: 1.0,
            end: 0.0,
          )
          .fadeIn(duration: 300.ms),
          
          // Display name at top - using shared component for consistent positioning
          CallUIComponents.buildCallerName(
            context,
            displayName: callerName,
          )
          .animate()
          .slideY(
            duration: 500.ms,
            curve: Curves.easeOutCubic,
            begin: -1.0,
            end: 0.0,
          )
          .fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildPhoto(BuildContext context, String? photoUrl, String displayName) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Center(
            child: Platform.isIOS
                ? const CupertinoActivityIndicator(
                    color: Colors.white,
                    radius: 20,
                  )
                : const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
          ),
          errorWidget: (context, url, error) => _buildFallbackPhoto(context, displayName),
        ),
      );
    }

    return _buildFallbackPhoto(context, displayName);
  }

  Widget _buildFallbackPhoto(BuildContext context, String displayName) {
    final initials = _getInitials(displayName);
    final color = _getColorFromName(displayName);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: color,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.2,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words[0][0].toUpperCase();
  }

  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }
}
