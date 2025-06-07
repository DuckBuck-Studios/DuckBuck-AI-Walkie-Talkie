import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/home_provider.dart';
import '../widgets/home_friends_section.dart';
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeProvider()..initialize(),
      child: HomeScreenContent(
        onShowFullscreenOverlay: widget.onShowFullscreenOverlay,
        onHideFullscreenOverlay: widget.onHideFullscreenOverlay,
      ),
    );
  }
}

class HomeScreenContent extends StatefulWidget {
  final Function(Widget)? onShowFullscreenOverlay;
  final VoidCallback? onHideFullscreenOverlay;
  
  const HomeScreenContent({
    super.key,
    this.onShowFullscreenOverlay,
    this.onHideFullscreenOverlay,
  });

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedFriend;
  bool _isExpanded = false;
  bool _isInCall = false;
  bool _isConnecting = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  late AnimationController _animationController;
  late AnimationController _connectingController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _connectingController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOutCubic),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectingController.dispose();
    super.dispose();
  }

  void _expandFriend(Map<String, dynamic> friendProfile) {
    setState(() {
      _selectedFriend = friendProfile;
      _isExpanded = true;
    });
    _animationController.forward();
  }

  void _collapseFriend() {
    _animationController.reverse().then((_) {
      setState(() {
        _selectedFriend = null;
        _isExpanded = false;
      });
    });
  }

  void _startCall() {
    setState(() {
      _isConnecting = true;
    });
    
    // Start the connecting animation and show fullscreen overlay when it completes
    _connectingController.forward().then((_) {
      setState(() {
        _isConnecting = false;
        _isInCall = true;
      });
      
      // Show fullscreen overlay only after connecting animation completes
      if (widget.onShowFullscreenOverlay != null && _selectedFriend != null) {
        widget.onShowFullscreenOverlay!(_buildFullscreenCallOverlay(_selectedFriend!));
      }
    });
  }

  void _endCall() {
    setState(() {
      _isInCall = false;
      _isConnecting = false;
      _isMuted = false;
      _isSpeakerOn = false;
    });
    _connectingController.reset();
    
    // Hide fullscreen overlay
    if (widget.onHideFullscreenOverlay != null) {
      widget.onHideFullscreenOverlay!();
    }
    
    _collapseFriend();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    // Add actual mute functionality here
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // Add actual speaker functionality here
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        final theme = Theme.of(context);
        
        return Stack(
          children: [
            // Main home screen content
            Scaffold(
              backgroundColor: Platform.isIOS 
                  ? CupertinoColors.systemGroupedBackground.resolveFrom(context) 
                  : theme.colorScheme.background,
              appBar: !_isExpanded && !Platform.isIOS ? AppBar(
                title: const Text('Home'),
                automaticallyImplyLeading: false,
                elevation: 0,
                backgroundColor: theme.colorScheme.background,
                centerTitle: true,
              ) : null,
              body: _buildFriendsListView(context, homeProvider),
            ),
            
            // Local overlay for non-call expansion (shows during connecting phase too)
            if (_isExpanded && !_isInCall)
              Positioned.fill(
                child: _buildExpandedView(context, homeProvider),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFriendsListView(BuildContext context, HomeProvider homeProvider) {
    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Home'),
          automaticallyImplyLeading: false,
        ),
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 - (_scaleAnimation.value * 0.1),
                child: Opacity(
                  opacity: 1.0 - _fadeAnimation.value,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: HomeFriendsSection(
                      provider: homeProvider,
                      onFriendTap: (context, relationship) {
                        _expandFriend(relationship);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      return SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final scale = _isExpanded ? 1.0 - (_scaleAnimation.value * 0.1) : 1.0;
            final opacity = _isExpanded ? 1.0 - _fadeAnimation.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: HomeFriendsSection(
                    provider: homeProvider,
                    onFriendTap: (context, relationship) {
                      _expandFriend(relationship);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }

  Widget _buildExpandedView(BuildContext context, HomeProvider homeProvider) {
    if (_selectedFriend == null) return const SizedBox.shrink();

    final isIOS = Platform.isIOS;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Material(
          type: MaterialType.canvas,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isIOS 
                  ? CupertinoColors.black 
                  : Colors.black,
            ),
            child: Stack(
              children: [
                // Fullscreen Photo Background
                Positioned.fill(
                  child: _buildFullscreenPhoto(_selectedFriend!),
                ),
                
                // Bottom Section - name section only (no call controls in local view)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                        top: 16,
                      ),
                      child: _buildBottomNameSection(context, _selectedFriend!, isIOS),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullscreenCallOverlay(Map<String, dynamic> friendProfile) {
    if (_selectedFriend == null) return const SizedBox.shrink();
    
    return Material(
      type: MaterialType.canvas,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Stack(
          children: [
            // Fullscreen Photo Background
            Positioned.fill(
              child: _buildFullscreenPhoto(friendProfile),
            ),
            
            // Top section with friend name and status
            Positioned(
              top: MediaQuery.of(context).padding.top + 30,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Hero(
                    tag: 'friend_name_${friendProfile['uid']}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        friendProfile['displayName'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'In Call',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Call controls at bottom - only show when actually in call
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildFullscreenCallControls(context, friendProfile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenCallControls(BuildContext context, Map<String, dynamic> friendProfile) {
    return Container(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.only(
          left: 30,
          right: 30,
          bottom: MediaQuery.of(context).padding.bottom + 40,
          top: 60,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute button
            _buildFullscreenCallButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              color: _isMuted ? Colors.red.shade600 : Colors.grey.shade700,
              onPressed: _toggleMute,
            ),
            
            // End call button (larger and more prominent)
            _buildFullscreenCallButton(
              icon: Icons.call_end,
              label: 'End Call',
              color: Colors.red.shade600,
              onPressed: _endCall,
              isLarge: true,
            ),
            
            // Speaker button
            _buildFullscreenCallButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
              label: _isSpeakerOn ? 'Speaker' : 'Phone',
              color: _isSpeakerOn ? Colors.blue.shade600 : Colors.grey.shade700,
              onPressed: _toggleSpeaker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    final buttonSize = isLarge ? 80.0 : 65.0;
    final iconSize = isLarge ? 32.0 : 26.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenPhoto(Map<String, dynamic> friendProfile) {
    final hasImage = friendProfile['photoURL'] != null && friendProfile['photoURL'].toString().isNotEmpty;
    
    if (hasImage) {
      return Hero(
        tag: 'friend_photo_${friendProfile['uid']}',
        child: CachedNetworkImage(
          imageUrl: friendProfile['photoURL'],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => Container(
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallbackPhoto(friendProfile),
        ),
      );
    } else {
      return _buildFallbackPhoto(friendProfile);
    }
  }

  Widget _buildFallbackPhoto(Map<String, dynamic> friendProfile) {
    return Hero(
      tag: 'friend_photo_${friendProfile['uid']}',
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800,
              Colors.purple.shade800,
              Colors.pink.shade800,
            ],
          ),
        ),
        child: Center(
          child: Text(
            _getInitials(friendProfile['displayName'] ?? 'Unknown User'),
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectingIndicator() {
    return AnimatedBuilder(
      animation: _connectingController,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Only show the connecting progress and text - NO BUTTONS
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _connectingController.value,
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                backgroundColor: Colors.white.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connecting...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomNameSection(BuildContext context, Map<String, dynamic> friendProfile, bool isIOS) {
    return GestureDetector(
      onTap: _isConnecting ? null : _collapseFriend, // Disable tap when connecting
      onLongPress: _isConnecting ? null : _startCall, // Disable long press when connecting
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: _isConnecting
            ? Center(child: _buildConnectingIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'friend_name_${friendProfile['uid']}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        friendProfile['displayName'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to return • Hold to call',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts.last.isNotEmpty) {
      return (parts.first[0] + parts.last[0]).toUpperCase();
    } else if (parts.first.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }
    return '?';
  }
}
