import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/home_friends_section.dart';
import '../widgets/fullscreen_photo_viewer.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/agora/agora_token_service.dart';
import '../../../core/services/agora/agora_service.dart';
import '../../../core/services/notifications/notifications_service.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Call state variables
  bool _isLoading = false;
  bool _showCallControls = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  late AnimationController _loadingAnimationController;
  late AnimationController _callControlsAnimationController;
  Map<String, dynamic>? _currentFriend;
  @override
  void initState() {
    super.initState();
    // Initialize HomeProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().initialize();
    });
    
    // Initialize animation controllers
    _loadingAnimationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _callControlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _loadingAnimationController.dispose();
    _callControlsAnimationController.dispose();
    super.dispose();
  }

  void _handleFriendTap(Map<String, dynamic> friend) {
    if (widget.onShowFullscreenOverlay != null) {
      setState(() {
        _currentFriend = friend;
        _isLoading = false;
        _showCallControls = false;
        _isMuted = false;
        _isSpeakerOn = false;
      });
      
      _loadingAnimationController.reset();
      _callControlsAnimationController.reset();
      
      _showPhotoViewer();
    }
  }

  void _showPhotoViewer() {
    if (_currentFriend == null) return;
    
    final photoViewer = FullscreenPhotoViewer(
      photoURL: _currentFriend!['photoURL'],
      displayName: _currentFriend!['displayName'] ?? 'Unknown User',
      onExit: _handleExit,
      onLongPress: _handleLongPress,
      isLoading: _isLoading,
      showCallControls: _showCallControls,
      isMuted: _isMuted,
      isSpeakerOn: _isSpeakerOn,
      onToggleMute: _handleToggleMute,
      onToggleSpeaker: _handleToggleSpeaker,
      onEndCall: _handleEndCall,
    );
    
    widget.onShowFullscreenOverlay!(photoViewer);
  }

  void _handleExit() {
    // Only allow exit if call is not active
    if (!_showCallControls && !_isLoading) {
      HapticFeedback.mediumImpact();
      
      // Add exit animation before hiding overlay
      _animateExit().then((_) {
        if (widget.onHideFullscreenOverlay != null) {
          widget.onHideFullscreenOverlay!();
        }
      });
    }
  }

  Future<void> _animateExit() async {
    // Add a slight delay for smooth exit animation
    await Future.delayed(const Duration(milliseconds: 200));
  }

  void _handleLongPress() async {
    if (_showCallControls) return; // Prevent multiple activations
    
    // Haptic feedback on long press
    HapticFeedback.mediumImpact();
    
    final logger = serviceLocator<LoggerService>();
    const tag = 'WALKIE_TALKIE_CIRCUIT';
    
    // PART 1: GET CHANNEL ID FROM RELATIONSHIP
    // Use relationship ID as channel ID instead of generating one
    if (_currentFriend == null) {
      logger.e(tag, 'No friend selected - cannot start walkie-talkie');
      return;
    }
    
    final relationshipId = _currentFriend!['relationshipId'] as String?;
    if (relationshipId == null || relationshipId.isEmpty) {
      logger.e(tag, 'Relationship ID is missing - cannot start walkie-talkie');
      return;
    }
    
    final friendUid = _currentFriend!['uid'] as String?;
    if (friendUid == null || friendUid.isEmpty) {
      logger.e(tag, 'Friend UID is missing - cannot start walkie-talkie');
      return;
    }
    
    final friendName = _currentFriend!['displayName'] ?? 'Unknown User';
    
    logger.i(tag, 'PART 1 - Using relationship ID as channel: $relationshipId');
    logger.i(tag, '   - Friend: $friendUid ($friendName)');
    
    // Start loading state
    setState(() {
      _isLoading = true;
    });
    _showPhotoViewer(); // Refresh the viewer with loading state
    _loadingAnimationController.forward();
    
    try {
      // PART 2: GET AGORA TOKEN (backend will assign UID)
      logger.i(tag, 'PART 2 - Fetching Agora token from backend...');
      final tokenService = serviceLocator<AgoraTokenService>();
      
      // Backend will auto-assign UID - only provide channelId
      final tokenResponse = await tokenService.generateToken(
        channelId: relationshipId,
      );
      
      logger.i(tag, 'PART 2 - Successfully fetched Agora token');
      logger.d(tag, '   - Token (first 20 chars): ${tokenResponse.token.substring(0, 20)}...');
      logger.d(tag, '   - Token (full): ${tokenResponse.token}');
      logger.d(tag, '   - Channel: ${tokenResponse.channelId}');
      logger.d(tag, '   - Backend assigned UID: ${tokenResponse.uid}');
      
      // Validate channel matches
      if (relationshipId != tokenResponse.channelId) {
        logger.e(tag, '❌ CHANNEL MISMATCH: Token generated for different channel!');
        throw Exception('Channel mismatch: requested $relationshipId, got ${tokenResponse.channelId}');
      }
      
      // PART 3: INITIALIZE AGORA ENGINE
      logger.i(tag, 'PART 3 - Initializing Agora engine...');
      final engineInitialized = await AgoraService.initializeEngine();
      
      if (!engineInitialized) {
        logger.e(tag, 'PART 3 - Failed to initialize Agora engine');
        throw Exception('Failed to initialize Agora engine');
      }
      
      logger.i(tag, 'PART 3 - Agora engine initialized successfully');
      
      // PART 4: SEND FCM DATA-ONLY NOTIFICATION TO FRIEND (NO AGORA UID SENT)
      logger.i(tag, 'PART 4 - Sending FCM invitation to friend...');
      final notificationsService = serviceLocator<NotificationsService>();
      
      final invitationSent = await notificationsService.sendDataOnlyNotification(
        uid: friendUid,
        type: 'walkie_talkie_invite',
        agoraChannelId: relationshipId,
      );
      
      if (!invitationSent) {
        logger.w(tag, 'PART 4 - Failed to send FCM invitation to friend');
        // Continue anyway, maybe friend is already in app
      } else {
        logger.i(tag, 'PART 4 - FCM invitation sent successfully to friend');
        logger.d(tag, '   - Friend UID: $friendUid');
        logger.d(tag, '   - Channel: $relationshipId');
        logger.d(tag, '   - No Agora UID sent - backend will handle assignment');
      }
      
      // PART 5: JOIN CHANNEL AND WAIT FOR FRIEND (15 seconds timeout)
      logger.i(tag, 'PART 5 - Joining Agora channel and waiting for friend...');
      logger.d(tag, '   - Channel: $relationshipId');
      logger.d(tag, '   - My UID: ${tokenResponse.uid} (backend assigned)');
      logger.d(tag, '   - Token being passed to AgoraService: ${tokenResponse.token}');
      logger.d(tag, '   - Timeout: 15 seconds');
      
      // Final verification before making the call
      logger.w(tag, '🔍 FINAL AGORA CALL VERIFICATION:');
      logger.w(tag, '   - Channel param: $relationshipId (length: ${relationshipId.length})');
      logger.w(tag, '   - UID param: ${tokenResponse.uid} (using backend UID)');
      logger.w(tag, '   - Token param length: ${tokenResponse.token.length}');
      logger.w(tag, '   - Token starts with: ${tokenResponse.token.substring(0, 10)}');
      
      final friendJoined = await AgoraService.joinChannelAndWaitForUsers(
        relationshipId,
        token: tokenResponse.token,
        uid: tokenResponse.uid, // Use the UID that the token was actually generated for
        timeoutSeconds: 15,
      );
      
      logger.i(tag, 'PART 6 - AgoraService.joinChannelAndWaitForUsers returned: $friendJoined');
      
      if (friendJoined) {
        logger.i(tag, '✅ PART 6 - Friend joined the channel! Showing call UI...');
        
        // SUCCESS: Show call UI since friend joined
        setState(() {
          _isLoading = false;
          _showCallControls = true;
        });
        
        _showPhotoViewer(); // Refresh the viewer with call controls
        _callControlsAnimationController.forward();
        
      } else {
        logger.w(tag, '❌ PART 6 - Friend did not join within timeout');
        
        // FAILED: Auto-leave channel and don't show call UI
        logger.i(tag, 'Auto-leaving channel due to timeout...');
        await AgoraService.leaveChannel();
        
        throw Exception('Friend did not join the channel within 15 seconds');
      }
      
    } catch (e) {
      logger.e(tag, 'Failed to initialize walkie-talkie circuit: $e');
      
      // Reset loading state on error
      setState(() {
        _isLoading = false;
      });
      _showPhotoViewer(); // Refresh the viewer
      _loadingAnimationController.reset();
      
      // TODO: Show error message to user
    }
  }

  void _handleToggleMute() async {
    HapticFeedback.lightImpact();
    
    final logger = serviceLocator<LoggerService>();
    const tag = 'WALKIE_TALKIE_CIRCUIT';
    
    try {
      bool success;
      if (_isMuted) {
        // Currently muted, turn microphone on
        success = await AgoraService.turnMicrophoneOn();
        logger.d(tag, 'Turned microphone ${success ? "ON" : "FAILED"}');
      } else {
        // Currently unmuted, turn microphone off
        success = await AgoraService.turnMicrophoneOff();
        logger.d(tag, 'Turned microphone ${success ? "OFF" : "FAILED"}');
      }
      
      if (success) {
        setState(() {
          _isMuted = !_isMuted;
        });
        _showPhotoViewer(); // Refresh the viewer
      } else {
        logger.w(tag, 'Failed to toggle microphone');
        // TODO: Show error to user
      }
    } catch (e) {
      logger.e(tag, 'Exception while toggling microphone: $e');
    }
  }

  void _handleToggleSpeaker() async {
    HapticFeedback.lightImpact();
    
    final logger = serviceLocator<LoggerService>();
    const tag = 'WALKIE_TALKIE_CIRCUIT';
    
    try {
      bool success;
      if (_isSpeakerOn) {
        // Currently on speaker, turn off
        success = await AgoraService.turnSpeakerOff();
        logger.d(tag, 'Turned speaker ${success ? "OFF" : "FAILED"}');
      } else {
        // Currently off speaker, turn on
        success = await AgoraService.turnSpeakerOn();
        logger.d(tag, 'Turned speaker ${success ? "ON" : "FAILED"}');
      }
      
      if (success) {
        setState(() {
          _isSpeakerOn = !_isSpeakerOn;
        });
        _showPhotoViewer(); // Refresh the viewer
      } else {
        logger.w(tag, 'Failed to toggle speaker');
        // TODO: Show error to user
      }
    } catch (e) {
      logger.e(tag, 'Exception while toggling speaker: $e');
    }
  }

  void _handleEndCall() async {
    // Haptic feedback on end call
    HapticFeedback.heavyImpact();
    
    final logger = serviceLocator<LoggerService>();
    const tag = 'WALKIE_TALKIE_CIRCUIT';
    
    logger.i(tag, 'Ending walkie-talkie call...');
    
    // Leave Agora channel
    try {
      final leaveResult = await AgoraService.leaveChannel();
      if (leaveResult) {
        logger.i(tag, 'Successfully left Agora channel');
      } else {
        logger.w(tag, 'Failed to leave Agora channel properly');
      }
    } catch (e) {
      logger.e(tag, 'Exception while leaving Agora channel: $e');
    }
    
    // Reset state
    setState(() {
      _showCallControls = false;
      _isLoading = false;
      _isMuted = false;
      _isSpeakerOn = false;
    });
    
    _loadingAnimationController.reset();
    _callControlsAnimationController.reset();
    
    // Add smooth exit animation
    _animateExit().then((_) {
      if (widget.onHideFullscreenOverlay != null) {
        widget.onHideFullscreenOverlay!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
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
                friends: homeProvider.friends, // Use real friends from HomeProvider
                isLoading: homeProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
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
                friends: homeProvider.friends, // Use real friends from HomeProvider
                isLoading: homeProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
              ),
            ),
          );
        }
      },
    );
  }
}
