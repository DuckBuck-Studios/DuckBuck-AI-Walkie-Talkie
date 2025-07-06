import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/services/agora/agora_token_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../walkie_talkie/providers/call_provider.dart';

/// Enhanced friend photo overlay with call initiation
class FriendPhotoOverlay extends StatefulWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onClose;
  
  const FriendPhotoOverlay({
    super.key,
    required this.friend,
    required this.onClose,
  });

  @override
  State<FriendPhotoOverlay> createState() => _FriendPhotoOverlayState();
}

class _FriendPhotoOverlayState extends State<FriendPhotoOverlay>
    with TickerProviderStateMixin {
  
  // Animation controllers
  late AnimationController _loadingController;
  late AnimationController _photoScaleController;
  late AnimationController _shakeController;
  
  // Animations
  late Animation<double> _loadingAnimation;
  late Animation<double> _photoScaleAnimation;
  late Animation<double> _shakeAnimation;

  // State variables
  bool _isHolding = false;
  bool _callInProgress = false;
  bool _isDisposed = false;
  Timer? _loadingTimer;
  Timer? _callMonitorTimer;

  // Services
  final AgoraTokenService _tokenService = serviceLocator<AgoraTokenService>();
  final LoggerService _logger = serviceLocator<LoggerService>();
  static const String _tag = 'FRIEND_PHOTO_OVERLAY';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Loading animation (2 seconds)
    _loadingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _loadingController, curve: Curves.linear));

    // Photo scale animation (shrink to 80%)
    _photoScaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _photoScaleAnimation = Tween<double>(begin: 1.0, end: 0.8)
        .animate(CurvedAnimation(parent: _photoScaleController, curve: Curves.easeInOut));

    // Shake animation (vertical)
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: -8.0, end: 8.0)
        .animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cleanupEverything();
    _loadingController.dispose();
    _photoScaleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _cleanupEverything() {
    _logger.i(_tag, 'Cleaning up everything');
    _loadingTimer?.cancel();
    _callMonitorTimer?.cancel();
    _stopAllAnimations();
  }

  void _stopAllAnimations() {
    // Check if widget is disposed before trying to stop animations
    if (_isDisposed) return;
    
    try {
      if (_loadingController.isAnimating) _loadingController.stop();
      _loadingController.reset();
    } catch (e) {
      _logger.w(_tag, 'Error stopping loading controller: $e');
    }
    
    try {
      if (_photoScaleController.isAnimating) _photoScaleController.stop();
      _photoScaleController.reset();
    } catch (e) {
      _logger.w(_tag, 'Error stopping photo scale controller: $e');
    }
    
    try {
      if (_shakeController.isAnimating) _shakeController.stop();
      _shakeController.reset();
    } catch (e) {
      _logger.w(_tag, 'Error stopping shake controller: $e');
    }
  }

  void _handleTap() {
    if (!_callInProgress) {
      widget.onClose();
    }
  }

  void _handleLongPressStart() {
    if (_callInProgress) return;

    _logger.i(_tag, 'Long press started');
    setState(() => _isHolding = true);
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Start animations
    _photoScaleController.forward();
    _shakeController.repeat(reverse: true);
    _loadingController.forward();
    
    // Start 2-second timer for call initiation
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (_isHolding && mounted) {
        _startCall();
      }
    });
  }

  void _handleLongPressEnd() {
    _logger.i(_tag, 'Long press ended - isHolding: $_isHolding, callInProgress: $_callInProgress');
    
    if (!_isHolding) return; // Already handled
    
    setState(() => _isHolding = false);
    
    if (_callInProgress) {
      // If call is in progress, end it
      _endCall();
    } else {
      // If still loading, cancel everything
      _cancelLoading();
    }
    
    HapticFeedback.lightImpact();
  }

  void _cancelLoading() {
    _logger.i(_tag, 'Cancelling loading');
    _loadingTimer?.cancel();
    _returnToNormal();
  }

  void _returnToNormal() {
    _logger.i(_tag, 'Returning to normal state');
    _stopAllAnimations();
    setState(() {
      _isHolding = false;
      _callInProgress = false;
    });
  }

  void _startCall() async {
    if (!_isHolding || _callInProgress) return;
    
    _logger.i(_tag, 'Starting call');
    setState(() => _callInProgress = true);

    try {
      // Generate token
      final friendName = widget.friend['displayName'] ?? 'Unknown';
      final friendPhoto = widget.friend['photoURL'] ?? '';
      final channelId = 'call_${DateTime.now().millisecondsSinceEpoch}';

      final tokenResponse = await _tokenService.generateTokenWithRetry(
        channelId: channelId,
        callerPhoto: friendPhoto,
        callName: friendName,
      );

      if (!_isHolding || !mounted) {
        _logger.i(_tag, 'User released during token generation');
        _endCall();
        return;
      }

      // Send FCM invitation
      await _sendFCMInvitation(
        friendId: widget.friend['uid'],
        channelId: tokenResponse.channelId,
        agoraToken: tokenResponse.token,
        agoraUid: tokenResponse.uid.toString(),
      );

      if (!_isHolding || !mounted) {
        _logger.i(_tag, 'User released during FCM sending');
        _endCall();
        return;
      }

      // Start call monitoring
      _startCallMonitoring(tokenResponse);

    } catch (e) {
      _logger.e(_tag, 'Error starting call: $e');
      _endCall();
    }
  }

  Future<void> _sendFCMInvitation({
    required String friendId,
    required String channelId,
    required String agoraToken,
    required String agoraUid,
  }) async {
    _logger.i(_tag, 'Sending FCM invitation');
    // Simulate FCM sending
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _startCallMonitoring(AgoraTokenResponse tokenResponse) {
    _logger.i(_tag, 'Starting call monitoring');
    
    // Show outgoing call UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isHolding && mounted) {
        final callProvider = context.read<CallProvider>();
        callProvider.showOutgoingCallUI(
          channelId: tokenResponse.channelId,
          friendName: widget.friend['displayName'] ?? 'Unknown',
          friendPhoto: widget.friend['photoURL'],
          agoraToken: tokenResponse.token,
          agoraUid: tokenResponse.uid.toString(),
        );
      }
    });

    // Monitor call state
    var timeoutCount = 0;
    _callMonitorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Check if user released
      if (!_isHolding) {
        _logger.i(_tag, 'User released - ending call');
        timer.cancel();
        _endCall();
        return;
      }

      // Check if call connected
      final callProvider = context.read<CallProvider>();
      if (callProvider.isCallActive && callProvider.callType == 'outgoing') {
        _logger.i(_tag, 'Call connected successfully');
        timer.cancel();
        _onCallConnected();
        return;
      }

      // Check for timeout (25 seconds)
      timeoutCount += 500;
      if (timeoutCount >= 25000) {
        _logger.w(_tag, 'Call timeout');
        timer.cancel();
        _onCallTimeout();
        return;
      }
    });
  }

  void _onCallConnected() {
    _logger.i(_tag, 'Call connected - user can now release');
    // Keep monitoring for call end, but user can release now
    _monitorCallEnd();
  }

  void _monitorCallEnd() {
    _callMonitorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final callProvider = context.read<CallProvider>();
      if (!callProvider.isCallActive) {
        _logger.i(_tag, 'Call ended');
        timer.cancel();
        _returnToNormal();
        return;
      }
    });
  }

  void _onCallTimeout() {
    _logger.w(_tag, 'Call timed out');
    _endCall();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onClose();
    });
  }

  void _endCall() {
    _logger.i(_tag, 'Ending call');
    _callMonitorTimer?.cancel();
    
    // TODO: Leave Agora channel if connected
    // TODO: Cancel FCM notification if possible
    
    _returnToNormal();
  }

  @override
  Widget build(BuildContext context) {
    final friendName = widget.friend['displayName'] ?? 'Unknown User';
    final friendPhoto = widget.friend['photoURL'];
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Friend photo with animations
            AnimatedBuilder(
              animation: Listenable.merge([_photoScaleAnimation, _shakeAnimation]),
              builder: (context, child) {
                double shakeOffset = 0.0;
                if (_shakeController.isAnimating) {
                  shakeOffset = _shakeAnimation.value;
                }

                return Transform.translate(
                  offset: Offset(0, shakeOffset),
                  child: Transform.scale(
                    scale: _photoScaleAnimation.value,
                    child: ClipRRect(
                      borderRadius: _photoScaleAnimation.value < 1.0
                          ? BorderRadius.circular(20)
                          : BorderRadius.zero,
                      child: _buildPhotoWidget(friendPhoto, screenSize),
                    ),
                  ),
                );
              },
            ),

            // Friend name (hidden during hold and call)
            if (!_isHolding && !_callInProgress)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Text(
                    friendName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.8),
                          blurRadius: 15,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Call button
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _handleTap,
                  onLongPressStart: (_) => _handleLongPressStart(),
                  onLongPressEnd: (_) => _handleLongPressEnd(),
                  onLongPressCancel: () => _handleLongPressEnd(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.7),
                      border: Border.all(
                        color: _isHolding || _callInProgress
                            ? Colors.green
                            : Colors.white.withOpacity(0.8),
                        width: _isHolding || _callInProgress ? 4 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                        if (_isHolding || _callInProgress)
                          BoxShadow(
                            color: Colors.green.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Loading ring
                        if (_isHolding)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _loadingAnimation,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  value: _loadingAnimation.value,
                                  strokeWidth: 3,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                );
                              },
                            ),
                          ),
                        
                        // Icon
                        Center(
                          child: Icon(
                            _callInProgress || _isHolding ? Icons.call_made : Icons.close,
                            size: 30,
                            color: _callInProgress || _isHolding
                                ? Colors.green
                                : Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(String? friendPhoto, Size screenSize) {
    if (friendPhoto != null && friendPhoto.isNotEmpty) {
      return Image.network(
        friendPhoto,
        fit: BoxFit.cover,
        width: screenSize.width,
        height: screenSize.height,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[900],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          );
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          Icons.person,
          size: 200,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
