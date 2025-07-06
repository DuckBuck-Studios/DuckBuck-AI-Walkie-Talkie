import 'dart:async';
import 'package:flutter/material.dart';
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
  late AnimationController _loadingController;
  late Animation<double> _loadingAnimation;

  bool _isConnecting = false;
  bool _isHolding = false;
  bool _callStarted = false;
  Timer? _timeoutTimer;
  Timer? _longPressTimer;

  final AgoraTokenService _tokenService = serviceLocator<AgoraTokenService>();
  final LoggerService _logger = serviceLocator<LoggerService>();
  static const String _tag = 'FRIEND_PHOTO_OVERLAY';

  @override
  void initState() {
    super.initState();

    _loadingController = AnimationController(
      duration: const Duration(seconds: 2), // 2 second loading animation
      vsync: this,
    );

    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _timeoutTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!_callStarted) {
      widget.onClose();
    }
  }

  void _handleLongPressStart() {
    if (_callStarted) return;

    setState(() {
      _isHolding = true;
    });

    _logger.i(_tag, 'User started holding to initiate call');
    
    // Start loading animation
    _loadingController.forward();
    
    // Start timer to trigger call after 2 seconds
    _longPressTimer = Timer(const Duration(seconds: 2), () {
      if (_isHolding && !_callStarted) {
        _handleLongPress();
      }
    });
  }

  void _handleLongPressEnd() {
    if (_callStarted) return;

    setState(() {
      _isHolding = false;
    });

    // Cancel the loading animation and timer
    _loadingController.reset();
    _longPressTimer?.cancel();

    _logger.i(_tag, 'User stopped holding');
  }

  void _handleLongPress() async {
    if (_callStarted || _isConnecting) return;

    _logger.i(_tag, 'Starting call initiation process');
    
    setState(() {
      _isConnecting = true;
      _callStarted = true;
    });

    try {
      // Generate Agora token
      final friendName = widget.friend['displayName'] ?? 'Unknown';
      final friendPhoto = widget.friend['photoURL'] ?? '';
      final channelId = 'call_${DateTime.now().millisecondsSinceEpoch}';

      _logger.i(_tag, 'Generating token for channel: $channelId');
      
      final tokenResponse = await _tokenService.generateTokenWithRetry(
        channelId: channelId,
        callerPhoto: friendPhoto,
        callName: friendName,
      );

      _logger.i(_tag, 'Token generated, sending FCM invitation');

      // TODO: Send FCM notification to friend
      await _sendFCMInvitation(
        friendId: widget.friend['uid'],
        channelId: tokenResponse.channelId,
        agoraToken: tokenResponse.token,
        agoraUid: tokenResponse.uid.toString(),
        callerName: 'You', // TODO: Get from current user
        callerPhoto: '', // TODO: Get from current user
      );

      // Start 25-second timeout
      _startCallTimeout(tokenResponse);

      _logger.i(_tag, 'FCM sent, waiting for receiver to join');

    } catch (e) {
      _logger.e(_tag, 'Error starting call: $e');
      
      // Auto-close after showing error
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onClose();
        }
      });
    }
  }

  Future<void> _sendFCMInvitation({
    required String friendId,
    required String channelId,
    required String agoraToken,
    required String agoraUid,
    required String callerName,
    required String callerPhoto,
  }) async {
    // TODO: Implement FCM sending via your backend API
    _logger.i(_tag, 'Sending FCM to friend: $friendId');
    
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // For now, just log the FCM data that would be sent
    final fcmData = {
      'type': 'data_only',
      'priority': 'high',
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'call_name': callerName,
      'caller_photo': callerPhoto,
      'agora_channelid': channelId,
      'agora_token': agoraToken,
      'agora_uid': agoraUid,
    };
    
    _logger.d(_tag, 'FCM data to send: $fcmData');
  }

  void _startCallTimeout(AgoraTokenResponse tokenResponse) {
    // Set up periodic check for call state with 25-second timeout
    var timeoutSeconds = 0;
    _timeoutTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // Check if call became active (receiver joined)
      final callProvider = context.read<CallProvider>();
      if (callProvider.isCallActive && callProvider.callType == 'outgoing') {
        timer.cancel();
        _logger.i(_tag, 'Receiver joined the call!');
        return; // Call UI will show automatically via CallProvider
      }

      // Check if timeout reached (25 seconds)
      timeoutSeconds += 500;
      if (timeoutSeconds >= 25000) {
        timer.cancel();
        _handleCallTimeout();
      }
    });

    // Also trigger outgoing call UI immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callProvider = context.read<CallProvider>();
      callProvider.showOutgoingCallUI(
        channelId: tokenResponse.channelId,
        friendName: widget.friend['displayName'] ?? 'Unknown',
        friendPhoto: widget.friend['photoURL'],
        agoraToken: tokenResponse.token,
        agoraUid: tokenResponse.uid.toString(),
      );
    });
  }

  void _handleCallTimeout() {
    _logger.w(_tag, 'Call timeout - receiver did not join within 25 seconds');
    
    // Auto-close after showing timeout message
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        widget.onClose();
      }
    });
  }
   @override
  Widget build(BuildContext context) {
    final friendName = widget.friend['displayName'] ?? 'Unknown User';
    final friendPhoto = widget.friend['photoURL'];
    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false, // Prevent back button from closing
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Friend photo - fullscreen
            if (friendPhoto != null && friendPhoto.isNotEmpty)
              Image.network(
                friendPhoto,
                fit: BoxFit.cover,
                width: screenSize.width,
                height: screenSize.height,
                errorBuilder: (context, error, stackTrace) {
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
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Icon(
                    Icons.person,
                    size: 200,
                    color: Colors.grey[600],
                  ),
                ),
              ),

            // Friend name at top
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

            // Circular button at bottom - always visible
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _handleTap,
                  onLongPressStart: (_) => _handleLongPressStart(),
                  onLongPressEnd: (_) => _handleLongPressEnd(),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.7),
                      border: Border.all(
                        color: _isHolding 
                            ? Colors.green
                            : _isConnecting 
                                ? Colors.blue
                                : Colors.white.withOpacity(0.8),
                        width: _isHolding ? 4 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                        if (_isHolding)
                          BoxShadow(
                            color: Colors.green.withOpacity(0.6),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Loading progress ring when holding
                        if (_isHolding)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _loadingAnimation,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  value: _loadingAnimation.value,
                                  strokeWidth: 3,
                                  backgroundColor: Colors.transparent,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                );
                              },
                            ),
                          ),
                        
                        // Icon in center
                        Center(
                          child: Icon(
                            _isConnecting 
                                ? Icons.call_made
                                : _isHolding 
                                    ? Icons.call_made
                                    : Icons.close,
                            size: 30,
                            color: _isHolding 
                                ? Colors.green
                                : _isConnecting 
                                    ? Colors.blue
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
}
