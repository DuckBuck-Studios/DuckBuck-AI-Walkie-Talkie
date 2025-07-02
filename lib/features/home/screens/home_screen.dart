import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/shared_friends_provider.dart';
import '../../walkie_talkie/providers/call_provider.dart';
import '../widgets/home_friends_section.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/agora/agora_token_service.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import 'dart:io' show Platform;

class HomeScreen extends StatefulWidget {
  final Function(Widget)? onShowFullscreenOverlay;
  final VoidCallback? onHideFullscreenOverlay;
  
  const HomeScreen({
    super.key,
    this.onShowFullscreenOverlay,
    this.onHideFullscreenOverlay,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize SharedFriendsProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharedFriendsProvider>().initialize();
    });
  }

  void _handleFriendTap(Map<String, dynamic> friend) {
    // Show friend photo in fullscreen overlay
    if (widget.onShowFullscreenOverlay != null) {
      widget.onShowFullscreenOverlay!(
        _FriendPhotoOverlay(
          friend: friend,
          onClose: () => widget.onHideFullscreenOverlay?.call(),
        ),
      );
    }
  }

  void _handleAiAgentTap() {
    Navigator.pushNamed(context, AppRoutes.aiAgent);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SharedFriendsProvider>(
      builder: (context, friendsProvider, child) {
        final isIOS = Platform.isIOS;
        final theme = Theme.of(context);
        
        if (isIOS) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: const Text('Home'),
              automaticallyImplyLeading: false,
              backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
              border: null,
            ),
            backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            child: SafeArea(
              child: HomeFriendsSection(
                friends: friendsProvider.friends, // Use real friends from SharedFriendsProvider
                isLoading: friendsProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
                onAiAgentTap: _handleAiAgentTap,
              ),
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              title: const Text('Home'),
              automaticallyImplyLeading: false,
              centerTitle: true,
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
            ),
            body: SafeArea(
              child: HomeFriendsSection(
                friends: friendsProvider.friends, // Use real friends from SharedFriendsProvider
                isLoading: friendsProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
                onAiAgentTap: _handleAiAgentTap,
              ),
            ),
          );
        }
      },
    );
  }
}

/// Enhanced friend photo overlay with call initiation
class _FriendPhotoOverlay extends StatefulWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onClose;
  
  const _FriendPhotoOverlay({
    required this.friend,
    required this.onClose,
  });

  @override
  State<_FriendPhotoOverlay> createState() => _FriendPhotoOverlayState();
}

class _FriendPhotoOverlayState extends State<_FriendPhotoOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  bool _isConnecting = false;
  bool _isHolding = false;
  bool _callStarted = false;
  String _statusText = 'Tap to close • Hold to start call';
  Timer? _timeoutTimer;

  final AgoraTokenService _tokenService = serviceLocator<AgoraTokenService>();
  final LoggerService _logger = serviceLocator<LoggerService>();
  static const String _tag = 'FRIEND_PHOTO_OVERLAY';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(seconds: 25), // 25 second timeout
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _timeoutTimer?.cancel();
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
      _statusText = 'Hold to start call...';
    });

    _logger.i(_tag, 'User started holding to initiate call');
  }

  void _handleLongPressEnd() {
    if (_callStarted) return;

    setState(() {
      _isHolding = false;
    });

    if (!_isConnecting) {
      setState(() {
        _statusText = 'Tap to close • Hold to start call';
      });
    }

    _logger.i(_tag, 'User stopped holding');
  }

  void _handleLongPress() async {
    if (_callStarted || _isConnecting) return;

    _logger.i(_tag, 'Starting call initiation process');
    
    setState(() {
      _isConnecting = true;
      _callStarted = true;
      _statusText = 'Generating token...';
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

      setState(() {
        _statusText = 'Sending invitation...';
      });

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

      setState(() {
        _statusText = 'Connecting...';
      });

      // Start 25-second timeout
      _progressController.forward();
      _startCallTimeout(tokenResponse);

      _logger.i(_tag, 'FCM sent, waiting for receiver to join');

    } catch (e) {
      _logger.e(_tag, 'Error starting call: $e');
      
      setState(() {
        _statusText = 'Failed to start call';
      });

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
    // Set up periodic check for call state
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

      // Check if timeout reached
      if (_progressController.isCompleted) {
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
    
    setState(() {
      _statusText = 'No answer • Call ended';
    });

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

    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: (_) => _handleLongPressStart(),
      onLongPressEnd: (_) => _handleLongPressEnd(),
      onLongPress: _handleLongPress,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Main content - same as before but with call functionality
            Center(
              child: Hero(
                tag: 'friend_photo_$friendName',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Friend photo with enhanced animations
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isConnecting ? 1.0 : _pulseAnimation.value,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                              border: Border.all(
                                color: _isHolding 
                                    ? Colors.green 
                                    : _isConnecting 
                                        ? Colors.blue 
                                        : Colors.white,
                                width: _isHolding ? 6 : 4,
                              ),
                              boxShadow: [
                                if (_isHolding || _isConnecting)
                                  BoxShadow(
                                    color: (_isHolding ? Colors.green : Colors.blue)
                                        .withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                              ],
                            ),
                            child: ClipOval(
                              child: friendPhoto != null
                                  ? Image.network(
                                      friendPhoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.person,
                                          size: 150,
                                          color: Colors.grey[400],
                                        );
                                      },
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 150,
                                      color: Colors.grey[400],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Friend name
                    Text(
                      friendName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Status text (enhanced)
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: _isConnecting ? Colors.blue[300] : Colors.grey[400],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Progress indicator during connecting
                    if (_isConnecting) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 250,
                        child: AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _progressAnimation.value,
                              backgroundColor: Colors.grey[700],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${25 - (_progressAnimation.value * 25).round()}s remaining',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Close button (only show if not connecting)
            if (!_isConnecting)
              Positioned(
                top: 60,
                right: 20,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
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
