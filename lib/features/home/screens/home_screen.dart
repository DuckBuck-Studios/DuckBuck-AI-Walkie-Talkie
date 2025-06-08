import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/home_friends_section.dart';
import '../widgets/fullscreen_photo_viewer.dart';
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
    
    setState(() {
      _isLoading = true;
    });
    _showPhotoViewer(); // Refresh the viewer with loading state

    _loadingAnimationController.forward();

    // Wait for 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    setState(() {
      _isLoading = false;
      _showCallControls = true;
    });
    
    _showPhotoViewer(); // Refresh the viewer with call controls
    _callControlsAnimationController.forward();
  }

  void _handleToggleMute() {
    HapticFeedback.lightImpact();
    setState(() {
      _isMuted = !_isMuted;
    });
    _showPhotoViewer(); // Refresh the viewer
  }

  void _handleToggleSpeaker() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _showPhotoViewer(); // Refresh the viewer
  }

  void _handleEndCall() {
    // Haptic feedback on end call
    HapticFeedback.heavyImpact();
    
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
                friends: homeProvider.friends,
                isLoading: homeProvider.isLoadingFriends,
                onFriendTap: _handleFriendTap,
              )
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
                friends: homeProvider.friends,
                isLoading: homeProvider.isLoadingFriends,
                onFriendTap: _handleFriendTap,
              )
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
            ),
          );
        }
      },
    );
  }
}
