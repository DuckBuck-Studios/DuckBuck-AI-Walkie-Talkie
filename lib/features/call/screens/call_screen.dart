import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io' show Platform, File;

import '../providers/call_provider.dart';
import '../../shared/widgets/call_ui_components.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';

/// Call screen with consistent UI styling matching the fullscreen photo viewer
/// Uses shared CallUIComponents for consistent positioning and styling
class CallScreen extends StatelessWidget {
  static const String _tag = 'CALL_SCREEN';
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  CallScreen({super.key});

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
    _logger.d(_tag, '_buildPhoto called with photoUrl: $photoUrl');
    
    if (photoUrl != null && photoUrl.isNotEmpty) {
      // Check if it's a local file path
      final isLocalFile = photoUrl.startsWith('file://') || photoUrl.startsWith('/');
      _logger.d(_tag, 'Is local file: $isLocalFile for URL: $photoUrl');
      
      if (isLocalFile) {
        // Handle local file paths
        final localPath = photoUrl.startsWith('file://') 
            ? photoUrl.replaceFirst('file://', '') 
            : photoUrl;
        
        _logger.d(_tag, 'Processing local file path: $localPath');
        
        // Check if file exists
        final file = File(localPath);
        if (!file.existsSync()) {
          _logger.w(_tag, 'Local file does not exist: $localPath');
          return _buildFallbackPhoto(context, displayName);
        }
        
        _logger.d(_tag, 'Local file exists, loading: $localPath');
            
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              _logger.e(_tag, 'Error loading local file: $localPath - $error');
              return _buildFallbackPhoto(context, displayName);
            },
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                _logger.d(_tag, 'Local file loaded successfully: $localPath');
                return child;
              }
              return Center(
                child: Platform.isIOS
                    ? const CupertinoActivityIndicator(
                        color: Colors.white,
                        radius: 20,
                      )
                    : const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
              );
            },
          ),
        );
      } else {
        // Handle network URLs
        _logger.d(_tag, 'Processing network URL: $photoUrl');
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
            errorWidget: (context, url, error) {
              _logger.e(_tag, 'Error loading network image: $photoUrl - $error');
              return _buildFallbackPhoto(context, displayName);
            },
          ),
        );
      }
    }

    _logger.w(_tag, 'No photo URL provided, using fallback');
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
