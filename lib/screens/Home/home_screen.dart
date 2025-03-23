import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/animated_background.dart';
import '../../providers/user_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/status_animation_popup.dart';
import 'profile_screen.dart';
import 'friend_screen.dart';

// Friend Card Widget
class FriendCard extends StatefulWidget {
  final Map<String, dynamic> friend;
  final bool showStatus;

  const FriendCard({
    Key? key,
    required this.friend,
    this.showStatus = false,
  }) : super(key: key);

  @override
  State<FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<FriendCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  OverlayEntry? _overlayEntry;
  bool _isLocked = false;
  bool _isLongPressed = false;
  Offset? _dragStartPosition;
  double _dragProgress = 0.0; // Track drag progress from 0.0 to 1.0
  PathDirection? _currentPathDirection; // Store the current path direction
  Offset? _pathEndPosition; // Store the calculated end position

  // Call control states
  bool _isMicOn = true;
  bool _isVideoOn = true;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Material(
            color: Colors.black.withOpacity(0.5 * _controller.value),
            child: Stack(
              children: [
                // Animated background blur
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10 * _controller.value,
                    sigmaY: 10 * _controller.value,
                  ),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
                // Centered card
                Center(
                  child: Hero(
                    tag: 'friend-card-${widget.friend['id']}-fullscreen',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: MediaQuery.of(context).size.width * (0.9 + (0.1 * _controller.value)),
                      height: MediaQuery.of(context).size.height * (0.7 + (0.3 * _controller.value)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20 * (1 - _controller.value)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20 * (1 - _controller.value)),
                        child: _buildCardContent(isFullScreen: true),
                      ),
                    ),
                  ),
                ),
                // Lock/Unlock button - only show when locked
                if (_isLocked)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Mic toggle button
                            _buildCallControlButton(
                              icon: _isMicOn
                                ? Icons.mic
                                : Icons.mic_off,
                              color: _isMicOn
                                ? Colors.white
                                : Colors.red,
                              onPressed: () {
                                setState(() {
                                  _isMicOn = !_isMicOn;
                                });
                                // Remove and recreate overlay to update UI
                                _removeOverlay();
                                _showOverlay();
                              },
                              label: _isMicOn ? 'Mute' : 'Unmute',
                            ),
                            // Video toggle button
                            _buildCallControlButton(
                              icon: _isVideoOn
                                ? Icons.videocam
                                : Icons.videocam_off,
                              color: _isVideoOn
                                ? Colors.white
                                : Colors.red,
                              onPressed: () {
                                setState(() {
                                  _isVideoOn = !_isVideoOn;
                                });
                                // Remove and recreate overlay to update UI
                                _removeOverlay();
                                _showOverlay();
                              },
                              label: _isVideoOn ? 'Video Off' : 'Video On',
                            ),
                            // End call button (larger and red)
                            _buildCallControlButton(
                              icon: Icons.call_end,
                              color: Colors.red,
                              size: 64,
                              backgroundColor: Colors.red.shade700,
                              onPressed: () {
                                setState(() {
                                  _isLocked = false;
                                  // Reset call control states
                                  _isMicOn = true;
                                  _isVideoOn = true;
                                  _isSpeakerOn = true;
                                });
                                _controller.reverse();
                                _removeOverlay();
                              },
                              label: 'End',
                            ),
                            // Speaker toggle button
                            _buildCallControlButton(
                              icon: _isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                              color: _isSpeakerOn
                                ? Colors.white
                                : Colors.red,
                              onPressed: () {
                                setState(() {
                                  _isSpeakerOn = !_isSpeakerOn;
                                });
                                // Remove and recreate overlay to update UI
                                _removeOverlay();
                                _showOverlay();
                              },
                              label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Visual swipe path - only show during long press but not locked
                if (_isLongPressed && !_isLocked && _controller.value > 0.7 && _dragStartPosition != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: SwipePathPainter(
                          startPosition: _dragStartPosition!,
                          progress: _dragProgress,
                          screenSize: MediaQuery.of(context).size,
                          presetDirection: _currentPathDirection,
                          presetEndPosition: _pathEndPosition,
                        ),
                      ),
                    ),
                  ),
                // Lock icon at the end of the swipe path
                if (_isLongPressed && !_isLocked && _controller.value > 0.7 && _dragStartPosition != null && _pathEndPosition != null)
                  Positioned(
                    left: _pathEndPosition!.dx - 20,  // Adjust for icon width/height
                    top: _pathEndPosition!.dy - 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _dragProgress > 0.8
                          ? Colors.green.withOpacity(0.8)
                          : Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: _dragProgress > 0.8 ? Colors.white : Colors.brown.shade800,
                        size: 24 + (_dragProgress * 8), // Grow slightly as user approaches
                      ),
                    ),
                  ),
                // Swipe instruction text - shows only when starting the gesture
                if (_isLongPressed && !_isLocked && _controller.value > 0.7 && _dragProgress < 0.2)
                  Positioned(
                    bottom: MediaQuery.of(context).size.height * 0.1,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade800.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Swipe to lock card',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // Reset drag progress
    _dragProgress = 0.0;
  }

  Widget _buildCardContent({bool isFullScreen = false}) {
    final String name = widget.friend['displayName'] ?? widget.friend['name'] ?? 'Friend';
    final String? statusAnimation = widget.friend['statusAnimation'];
    final bool isOnline = widget.friend['isOnline'] == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Friend Photo as Background
        ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcOver,
          child: widget.friend['photoURL'] != null && widget.friend['photoURL'].toString().isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.friend['photoURL'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.brown.shade100,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.brown.shade800,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.brown.shade100,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: isFullScreen ? 120 : 80,
                      color: Colors.brown.shade800,
                    ),
                  ),
                ),
              )
            : Container(
                color: Colors.brown.shade100,
                child: Center(
                  child: Icon(
                    Icons.person,
                    size: isFullScreen ? 120 : 80,
                    color: Colors.brown.shade800,
                  ),
                ),
              ),
        ),
        
        // Status animation at the top center
        if (widget.showStatus && statusAnimation != null)
          Positioned(
            top: isFullScreen ? 40 : 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: isFullScreen ? 120 : 90,
                height: isFullScreen ? 120 : 90,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(isFullScreen ? 60 : 45),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isFullScreen ? 58 : 43),
                  child: Lottie.asset(
                    _getStatusAnimationPath(statusAnimation),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stacktrace) {
                      print('Error loading status animation: ${_getStatusAnimationPath(statusAnimation)}');
                      return const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 30,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

        // Friend name and status at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.all(isFullScreen ? 24.0 : 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isFullScreen ? 32 : 24,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                if (widget.showStatus)
                  Row(
                    children: [
                      Container(
                        width: isFullScreen ? 12 : 8,
                        height: isFullScreen ? 12 : 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: isOnline ? Colors.green.shade300 : Colors.grey.shade400,
                          fontSize: isFullScreen ? 20 : 16,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        // Determine path direction and end position once at the start of the gesture
        final Size screenSize = MediaQuery.of(context).size;
        _currentPathDirection = SwipePathPainter.determineDirection(details.globalPosition, screenSize);
        _pathEndPosition = SwipePathPainter.calculateEndPosition(details.globalPosition, screenSize, _currentPathDirection!);
        
        setState(() {
          _isLongPressed = true;
          _dragStartPosition = details.globalPosition;
          _dragProgress = 0.0;
        });
        _controller.forward();
        _showOverlay();
      },
      onLongPressEnd: (details) {
        setState(() {
          _isLongPressed = false;
        });
        if (!_isLocked) {
          _controller.reverse();
          _removeOverlay();
        }
      },
      onLongPressMoveUpdate: (details) {
        if (_isLongPressed && !_isLocked && _dragStartPosition != null && _pathEndPosition != null) {
          // Calculate displacement based on the fixed direction
          final Offset displacement = details.globalPosition - _dragStartPosition!;
          final Offset pathVector = _pathEndPosition! - _dragStartPosition!;
          
          // Project displacement onto the path direction to get progress
          double dotProduct = displacement.dx * pathVector.dx + displacement.dy * pathVector.dy;
          double pathLengthSquared = pathVector.dx * pathVector.dx + pathVector.dy * pathVector.dy;
          
          // Calculate normalized projection (progress along the path)
          double progress = (dotProduct / pathLengthSquared).clamp(0.0, 1.0);
          
          // Update drag progress
          setState(() {
            _dragProgress = progress;
          });
          
          // If overlay is null, recreate it to update the UI
          if (_overlayEntry != null) {
            _removeOverlay();
            _showOverlay();
          }
          
          // If progress is sufficient, lock the card
          if (progress > 0.9) {  // Threshold for locking
            setState(() {
              _isLocked = true;
              _isLongPressed = false;
            });
            
            // Vibrate for haptic feedback
            HapticFeedback.mediumImpact();
            
            // Show a visual feedback that card is locked
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Card locked! Use the End button to close.'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Hero(
        tag: 'friend-card-${widget.friend['id']}-fullscreen',
        child: Container(
          width: MediaQuery.of(context).size.width * 0.75,
          height: MediaQuery.of(context).size.height * 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildCardContent(),
          ),
        ),
      ),
    );
  }

  // Helper method to build call control buttons
  Widget _buildCallControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    double size = 48,
    Color? backgroundColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? Colors.black.withOpacity(0.4),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: color,
              size: size * 0.5,
            ),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _getStatusAnimationPath(String? status) {
    if (status == null) return 'assets/status/offline.json';
    
    // Handle different status types
    if (status.startsWith('blue-demon')) {
      return 'assets/status/blue-demon/$status.json';
    } else if (status.startsWith('usr-emoji')) {
      return 'assets/status/usr-emoji/$status.json';
    }
    
    // Default case - try direct path
    return 'assets/status/$status.json';
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _friendsPageController = PageController();
  
  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize the user provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print("HomeScreen: Starting initialization sequence");
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Wait for user provider to initialize
      await userProvider.initialize();
      print("HomeScreen: UserProvider initialization completed");
      
      // Set user status as online automatically - without affecting animation status
      _setUserOnline();
      
      // Initialize friend provider
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      print("HomeScreen: Initializing FriendProvider");
      await friendProvider.initialize();
      print("HomeScreen: FriendProvider initialization completed");
      
      // Start monitoring friend statuses
      _startFriendStatusMonitoring(friendProvider);
    });
  }
  
  @override
  void dispose() {
    // Unregister observer
    WidgetsBinding.instance.removeObserver(this);
    _friendsPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("HomeScreen: App lifecycle state changed to $state");
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - set user as online
        print("HomeScreen: App resumed, setting user online");
        userProvider.setOnlineStatus(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App went to background - user will be set offline by Firebase onDisconnect
        print("HomeScreen: App went to background state: $state");
        break;
      case AppLifecycleState.hidden:
        // New state in Flutter 3.13+
        print("HomeScreen: App hidden");
        break;
    }
  }

  // Set user status as online
  void _setUserOnline() {
    print("HomeScreen: Setting user online status");
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Set user as online without changing animation status
    userProvider.setOnlineStatus(true);
    
    // Keep this for backward compatibility - it will only update animation if already set
    userProvider.setStatusAnimation(userProvider.statusAnimation, explicitChange: false);
  }

  // Show status animation popup
  void _showStatusAnimationPopup() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => StatusAnimationPopup(
        onAnimationSelected: (animation) {
          userProvider.setStatusAnimation(animation);
        },
      ),
    );
  }

  // Monitor friend statuses
  void _startFriendStatusMonitoring(FriendProvider friendProvider) {
    print("HomeScreen: Starting friend status monitoring");
    // This ensures the friend provider starts monitoring status updates
    friendProvider.startStatusMonitoring();
    
    // Add debugging for friend statuses
    final friends = friendProvider.friends;
    print("HomeScreen: Monitoring ${friends.length} friends for status updates");
    for (var friend in friends) {
      print("HomeScreen: Friend ${friend['displayName']} (${friend['id']}) status: ${friend['isOnline'] == true ? 'Online' : 'Offline'}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        body: DuckBuckAnimatedBackground(
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar with Profile Icon and Friends Button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.04,
                    vertical: MediaQuery.of(context).size.height * 0.02,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate appropriate sizes based on screen width
                      final double screenWidth = MediaQuery.of(context).size.width;
                      final bool isSmallScreen = screenWidth < 360;
                      final double buttonSize = isSmallScreen ? 45 : 50;
                      final double borderWidth = isSmallScreen ? 1.5 : 2;
                      final double iconSize = isSmallScreen ? 26 : 30;
                      final double titleFontSize = screenWidth * 0.06;
                      
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Profile Photo Button
                          Consumer<UserProvider>(
                            builder: (context, userProvider, child) {
                              final user = userProvider.currentUser;
                              return GestureDetector(
                                onTap: _navigateToProfile,
                                onLongPress: _showStatusAnimationPopup,
                                child: Hero(
                                  tag: 'profile-photo',
                                  child: Container(
                                    width: buttonSize,
                                    height: buttonSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFD4A76A), width: borderWidth),
                                      color: const Color(0xFFD4A76A).withOpacity(0.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(buttonSize / 2),
                                      child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: user.photoURL!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.brown.shade100,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: isSmallScreen ? 2 : 3,
                                                    color: Colors.brown.shade800,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Icon(
                                                Icons.person, 
                                                size: iconSize, 
                                                color: const Color(0xFFD4A76A)
                                              ),
                                            )
                                          : Icon(
                                              Icons.person, 
                                              size: iconSize, 
                                              color: const Color(0xFFD4A76A)
                                            ),
                                    ),
                                  ),
                                ),
                              ).animate()
                                .fadeIn(duration: 400.ms)
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1.0, 1.0),
                                  duration: 500.ms,
                                  curve: Curves.elasticOut,
                                );
                            }
                          ),
                          
                          // App Name or Title
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "DuckBuck",
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                            ),
                          ).animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                          
                          // Friends Button with Lottie Animation
                          GestureDetector(
                            onTap: _navigateToFriendScreen,
                            child: Container(
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFD4A76A).withOpacity(0.2),
                                border: Border.all(color: const Color(0xFFD4A76A), width: borderWidth),
                              ),
                              child: Lottie.asset(
                                'assets/animations/friend.json',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ).animate()
                            .fadeIn(duration: 400.ms)
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1.0, 1.0),
                              duration: 500.ms,
                              curve: Curves.elasticOut,
                            ),
                        ],
                      );
                    }
                  ),
                ),
                
                // Friends section with PageView
                Expanded(
                  child: Consumer<FriendProvider>(
                    builder: (context, friendProvider, child) {
                      final friends = friendProvider.friends;
                      
                      if (friends.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Color(0xFF3C1F1F),
                              ).animate()
                                .fadeIn(duration: 800.ms)
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  duration: 800.ms,
                                  curve: Curves.elasticOut,
                                ),
                              const SizedBox(height: 16),
                              Text(
                                'No friends yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade800,
                                ),
                              ).animate()
                                .fadeIn(delay: 200.ms, duration: 600.ms),
                              const SizedBox(height: 8),
                              Text(
                                'Add friends to see them here',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.brown.shade600,
                                ),
                              ).animate()
                                .fadeIn(delay: 400.ms, duration: 600.ms),
                            ],
                          ),
                        );
                      }
                      
                      return Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: _friendsPageController,
                              itemCount: friends.length,
                              itemBuilder: (context, index) {
                                // Get screen dimensions for responsive padding
                                final Size screenSize = MediaQuery.of(context).size;
                                final bool isSmallScreen = screenSize.width < 360;
                                final bool isLargeScreen = screenSize.width > 600;
                                final bool isLandscape = screenSize.width > screenSize.height;
                                
                                // Calculate appropriate padding based on screen size
                                final double horizontalPadding = isLargeScreen 
                                    ? screenSize.width * 0.15 
                                    : (isSmallScreen ? screenSize.width * 0.06 : screenSize.width * 0.08);
                                    
                                final double verticalPadding = isLandscape
                                    ? screenSize.height * 0.05
                                    : (isSmallScreen ? screenSize.height * 0.02 : screenSize.height * 0.03);
                                
                                // Staggered animation based on index
                                return Padding(
                                  // Dynamic padding to adjust card size for different screens
                                  padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding, 
                                    vertical: verticalPadding
                                  ),
                                  child: FriendCard(
                                    friend: friends[index],
                                    showStatus: true, // Enable status display
                                  ).animate()
                                    .fadeIn(
                                      delay: Duration(milliseconds: 100 * index), 
                                      duration: 800.ms
                                    )
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1.0, 1.0),
                                      delay: Duration(milliseconds: 100 * index),
                                      duration: 800.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                                );
                              },
                            ),
                          ),
                          if (friends.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  friends.length,
                                  (index) => AnimatedBuilder(
                                    animation: _friendsPageController,
                                    builder: (context, child) {
                                      // Calculate current page for indicator
                                      double page = _friendsPageController.hasClients
                                          ? _friendsPageController.page ?? 0
                                          : 0;
                                      bool isActive = (index == page.round());
                                      
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        width: isActive ? 12 : 8,
                                        height: isActive ? 12 : 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? const Color(0xFF3C1F1F)
                                              : const Color(0xFF3C1F1F).withOpacity(0.3),
                                        ),
                                      ).animate(
                                        target: isActive ? 1.0 : 0.0,
                                      ).scaleXY(
                                        begin: 1.0,
                                        end: 1.2,
                                        duration: 300.ms,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ).animate()
                              .fadeIn(delay: 600.ms, duration: 400.ms),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToFriendScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const FriendScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// Custom painter for the swipe path
class SwipePathPainter extends CustomPainter {
  final Offset startPosition;
  final double progress;
  final Size screenSize;
  final Offset endPosition;
  final PathDirection direction;
  final PathDirection? presetDirection;
  final Offset? presetEndPosition;
  
  SwipePathPainter({
    required this.startPosition,
    required this.progress,
    required this.screenSize,
    this.presetDirection,
    this.presetEndPosition,
  }) : endPosition = presetEndPosition ?? calculateEndPosition(startPosition, screenSize, presetDirection ?? determineDirection(startPosition, screenSize)),
       direction = presetDirection ?? determineDirection(startPosition, screenSize);
  
  static Offset calculateEndPosition(Offset start, Size screenSize, PathDirection direction) {
    // Determine where to place the endpoint based on screen position
    final pathLength = 150.0;
    
    switch (direction) {
      case PathDirection.right:
        return Offset(start.dx + pathLength, start.dy);
      case PathDirection.left:
        return Offset(start.dx - pathLength, start.dy);
      case PathDirection.up:
        return Offset(start.dx, start.dy - pathLength);
      case PathDirection.down:
        return Offset(start.dx, start.dy + pathLength);
      case PathDirection.upRight:
        return Offset(start.dx + pathLength * 0.7, start.dy - pathLength * 0.7);
      case PathDirection.upLeft:
        return Offset(start.dx - pathLength * 0.7, start.dy - pathLength * 0.7);
      case PathDirection.downRight:
        return Offset(start.dx + pathLength * 0.7, start.dy + pathLength * 0.7);
      case PathDirection.downLeft:
        return Offset(start.dx - pathLength * 0.7, start.dy + pathLength * 0.7);
    }
  }
  
  static PathDirection determineDirection(Offset start, Size screenSize) {
    // Calculate distance to edges
    final distanceToRight = screenSize.width - start.dx;
    final distanceToLeft = start.dx;
    final distanceToTop = start.dy;
    final distanceToBottom = screenSize.height - start.dy;
    
    // Minimum distance required for path
    const minDistance = 180.0;
    
    // List of possible directions based on available space
    List<PathDirection> possibleDirections = [];
    
    if (distanceToRight >= minDistance) possibleDirections.add(PathDirection.right);
    if (distanceToLeft >= minDistance) possibleDirections.add(PathDirection.left);
    if (distanceToTop >= minDistance) possibleDirections.add(PathDirection.up);
    if (distanceToBottom >= minDistance) possibleDirections.add(PathDirection.down);
    
    // Add diagonal directions if there's enough space in both directions
    if (distanceToRight >= minDistance * 0.7 && distanceToTop >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.upRight);
    if (distanceToLeft >= minDistance * 0.7 && distanceToTop >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.upLeft);
    if (distanceToRight >= minDistance * 0.7 && distanceToBottom >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.downRight);
    if (distanceToLeft >= minDistance * 0.7 && distanceToBottom >= minDistance * 0.7) 
      possibleDirections.add(PathDirection.downLeft);
    
    // Default to right if no direction has enough space (unlikely)
    if (possibleDirections.isEmpty) return PathDirection.right;
    
    // Choose a random direction from the possible ones
    return possibleDirections[Random().nextInt(possibleDirections.length)];
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    
    // Calculate the path vector
    final pathVector = Offset(
      endPosition.dx - startPosition.dx,
      endPosition.dy - startPosition.dy,
    );
    
    // Current path end position based on progress
    final currentEnd = Offset(
      startPosition.dx + pathVector.dx * progress,
      startPosition.dy + pathVector.dy * progress,
    );
    
    // Draw dashed line for remaining path
    paint.color = Colors.white.withOpacity(0.5);
    final dashWidth = 15.0;
    final dashSpace = 5.0;
    
    double currentDistance = pathVector.distance * progress;
    final totalDistance = pathVector.distance;
    
    while (currentDistance < totalDistance) {
      final nextDistance = currentDistance + dashWidth;
      if (nextDistance > totalDistance) break;
      
      final startPoint = Offset(
        startPosition.dx + (pathVector.dx * currentDistance / totalDistance),
        startPosition.dy + (pathVector.dy * currentDistance / totalDistance),
      );
      
      final endPoint = Offset(
        startPosition.dx + (pathVector.dx * nextDistance / totalDistance),
        startPosition.dy + (pathVector.dy * nextDistance / totalDistance),
      );
      
      canvas.drawLine(startPoint, endPoint, paint);
      currentDistance = nextDistance + dashSpace;
    }
    
    // Draw completed path
    paint.color = Colors.green;
    paint.strokeWidth = 8;
    canvas.drawLine(startPosition, currentEnd, paint);
    
    // Draw arrow heads along the path if not completed
    if (progress < 0.9) {
      final arrowPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      // Calculate unit vector for arrow direction
      final dx = pathVector.dx / pathVector.distance;
      final dy = pathVector.dy / pathVector.distance;
      
      // Draw arrow heads along the remaining path
      for (double d = pathVector.distance * progress + 20; d < totalDistance; d += 40) {
        final arrowX = startPosition.dx + (dx * d);
        final arrowY = startPosition.dy + (dy * d);
        
        // Create a path for the arrow head
        final path = Path();
        path.moveTo(arrowX, arrowY);
        
        // Calculate perpendicular vector for arrow wings
        final perpX = -dy * 5;
        final perpY = dx * 5;
        
        // Draw arrow that points in the direction of the path
        path.lineTo(arrowX - (dx * 10) + perpX, arrowY - (dy * 10) + perpY);
        path.lineTo(arrowX - (dx * 10) - perpX, arrowY - (dy * 10) - perpY);
        path.close();
        
        canvas.drawPath(path, arrowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant SwipePathPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.startPosition != startPosition ||
           oldDelegate.direction != direction;
  }
}

enum PathDirection {
  right,
  left,
  up,
  down,
  upRight,
  upLeft,
  downRight,
  downLeft,
}