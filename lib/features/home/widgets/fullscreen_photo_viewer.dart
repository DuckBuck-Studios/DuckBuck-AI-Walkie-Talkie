import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;
import '../../shared/widgets/call_ui_components.dart';
import 'call_ui.dart';

class FullscreenPhotoViewer extends StatelessWidget {
  final String? photoURL;
  final String displayName;
  final VoidCallback onExit;
  final VoidCallback? onLongPress;
  final bool isLoading;
  final bool showCallControls;
  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onEndCall;

  const FullscreenPhotoViewer({
    super.key,
    required this.photoURL,
    required this.displayName,
    required this.onExit,
    this.onLongPress,
    this.isLoading = false,
    this.showCallControls = false,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.onToggleMute,
    this.onToggleSpeaker,
    this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen photo with Hero animation and entrance animation
          Hero(
            tag: 'friend_photo_$displayName',
            child: _buildPhoto(context),
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
          
          // Bottom container with enhanced call UI
          showCallControls 
            ? CallUIComponents.buildCallControls(
                context,
                isMuted: isMuted,
                isSpeakerOn: isSpeakerOn,
                onToggleMute: onToggleMute,
                onToggleSpeaker: onToggleSpeaker,
                onEndCall: onEndCall,
              )
              .animate()
              .slideY(
                duration: 500.ms,
                curve: Curves.easeOutCubic,
                begin: 1.0,
                end: 0.0,
              )
              .fadeIn(duration: 300.ms)
            : (isLoading 
                ? CallUIComponents.buildLoadingIndicator(context)
                  .animate()
                  .slideY(
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                    begin: 1.0,
                    end: 0.0,
                  )
                  .fadeIn(duration: 300.ms)
                : CallUI.buildInstructionUI(
                    context,
                    onExit: onExit,
                    onLongPress: onLongPress,
                  )
              ),
          
          // Display name at top - animated
          CallUIComponents.buildCallerName(
            context,
            displayName: displayName,
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
    )
    .animate()
    .fadeIn(
      duration: 300.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildPhoto(BuildContext context) {
    if (photoURL != null && photoURL!.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: CachedNetworkImage(
          imageUrl: photoURL!,
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
          errorWidget: (context, url, error) => _buildFallbackPhoto(context),
        ),
      );
    }

    return _buildFallbackPhoto(context);
  }

  Widget _buildFallbackPhoto(BuildContext context) {
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