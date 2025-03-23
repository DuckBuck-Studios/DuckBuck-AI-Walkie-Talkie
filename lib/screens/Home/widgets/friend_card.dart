import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'swipe_path_painter.dart';
import '../../../providers/call_provider.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../services/fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Friend Card Widget
class FriendCard extends StatefulWidget {
  final Map<String, dynamic> friend;
  final bool showStatus;
  final bool isIncoming; // Flag to indicate if this is for an incoming call
  final Map<String, dynamic>? callData; // Call data for incoming calls

  // Static registry to track friend cards for FCM handling
  static final Map<String, _FriendCardState> _activeCards = {};

  // Static method to handle incoming calls from FCM
  static void handleIncomingCall(BuildContext context, Map<String, dynamic> callData) {
    print("FriendCard: Handling incoming call with data: $callData");
    
    final String callerId = callData['sender_uid'] ?? callData['callerUid'] ?? '';
    
    if (callerId.isEmpty) {
      print("FriendCard: Caller ID is missing, trying to find any active card");
      
      // If no caller ID provided, use the first available card as fallback
      if (_activeCards.isNotEmpty) {
        final firstAvailableCard = _activeCards.values.first;
        
        if (firstAvailableCard.mounted) {
          print("FriendCard: Using first available card as fallback");
          
          // Create a new FriendCard for the incoming call
          final receiverCard = FriendCard(
            friend: firstAvailableCard.widget.friend,
            isIncoming: true,
            callData: callData,
          );
          
          // Show the incoming call UI
          _showIncomingCallScreen(context, receiverCard);
          return;
        }
      }
      
      print("FriendCard: No cards available to handle the call");
      return;
    }
    
    print("FriendCard: Looking for friend card with ID: $callerId");
    print("FriendCard: Available cards: ${_activeCards.keys.join(', ')}");
    
    // Find matching friend card in active registry
    final cardState = _activeCards[callerId];
    
    if (cardState != null && cardState.mounted) {
      print("FriendCard: Found matching card for caller $callerId");
      
      // Create a new FriendCard for the incoming call
      final receiverCard = FriendCard(
        friend: cardState.widget.friend,
        isIncoming: true,
        callData: callData,
      );
      
      // Show the incoming call UI
      _showIncomingCallScreen(context, receiverCard);
    } else {
      print("FriendCard: No exact matching card found for caller $callerId, trying fallback");
      
      // If we have any cards that might be this user with a different ID format
      // First check if any card contains this ID as a substring
      _FriendCardState? matchingCard;
      
      for (final entry in _activeCards.entries) {
        final cardId = entry.key;
        final cardState = entry.value;
         
        if (cardId.contains(callerId) || callerId.contains(cardId)) {
          print("FriendCard: Found partial match: $cardId contains or is contained in $callerId");
          matchingCard = cardState;
          break;
        }
        
        // 2. Check the last part of the ID (after last separator)
        final cardIdParts = cardId.split(RegExp(r'[_\-:]'));
        final callerIdParts = callerId.split(RegExp(r'[_\-:]'));
        
        if (cardIdParts.isNotEmpty && callerIdParts.isNotEmpty &&
            cardIdParts.last == callerIdParts.last) {
          print("FriendCard: Found match by last ID segment: ${cardIdParts.last}");
          matchingCard = cardState;
          break;
        }
      }
      
      // If we found a match by alternative strategy, use it
      if (matchingCard != null && matchingCard.mounted) {
        print("FriendCard: Using fuzzy matched card");
        
        // Create a new FriendCard for the incoming call
        final receiverCard = FriendCard(
          friend: matchingCard.widget.friend,
          isIncoming: true,
          callData: callData,
        );
        
        // Show the incoming call UI
        _showIncomingCallScreen(context, receiverCard);
        return;
      }
      
      // If no matching card found, use the first available card as fallback
      if (_activeCards.isNotEmpty) {
        final firstAvailableCard = _activeCards.values.first;
        
        if (firstAvailableCard.mounted) {
          print("FriendCard: Using first available card as fallback");
          
          // Create a new FriendCard for the incoming call
          final receiverCard = FriendCard(
            friend: firstAvailableCard.widget.friend,
            isIncoming: true,
            callData: callData,
          );
          
          // Show the incoming call UI
          _showIncomingCallScreen(context, receiverCard);
        } else {
          print("FriendCard: No cards available to handle the call");
        }
      } else {
        print("FriendCard: No cards available to handle the call");
      }
    }
  }
  
  // Show incoming call screen
  static void _showIncomingCallScreen(BuildContext context, FriendCard receiverCard) {
    // Update call provider with call data
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    callProvider.handleIncomingCall(receiverCard.callData!);
    
    // Use the context that has a Navigator (must be a BuildContext that's part of the widget tree)
    try {
      // Show the receiver card as an overlay using a dialog or modal bottom sheet
      // for more reliable rendering without Navigator issues
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (dialogContext) {
          return Material(
            type: MaterialType.transparency,
            child: receiverCard,
          );
        },
      );
    } catch (e) {
      print("FriendCard: Error showing incoming call screen: $e");
      // Fallback - try to show as a route if dialog fails
      try {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, animation, secondaryAnimation) {
              return receiverCard;
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      } catch (e) {
        print("FriendCard: Error showing incoming call with fallback: $e");
      }
    }
  }

  const FriendCard({
    Key? key,
    required this.friend,
    this.showStatus = false,
    this.isIncoming = false,
    this.callData,
  }) : super(key: key);

  @override
  State<FriendCard> createState() => _FriendCardState();
}

class _FriendCardState extends State<FriendCard> with SingleTickerProviderStateMixin {
  // FCM service for sending call notifications
  final FCMService _fcmService = FCMService();
  
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  OverlayEntry? _overlayEntry;
  bool _isLocked = false;
  bool _isLongPressed = false;
  bool _isInIntermediateState = false;
  bool _isMovingToFullScreen = false;
  Offset? _dragStartPosition;
  double _dragProgress = 0.0; // Track drag progress from 0.0 to 1.0
  PathDirection? _currentPathDirection; // Store the current path direction
  Offset? _pathEndPosition; // Store the calculated end position
  Timer? _intermediateStateTimer;
  Timer? _vibrationTimer;
  double _vibrationOffset = 0.0;
  double _vibrationAngle = 0.0; // For pendulum-like rotation
  double _vibrationProgress = 0.0; // Animation progress from 0 to 1
  
  // Call duration timer and state
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  
  // Initial card position and size
  Rect? _initialCardRect;

  // Call control states
  bool _isMicOn = true;
  bool _isVideoOn = true;
  bool _isSpeakerOn = true;

  // Progress counter for intermediate state
  int _intermediateProgress = 0;
  
  // Call data
  String _channelId = '';
  bool _otherUserJoined = false;
  StreamSubscription? _remoteUserSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _sizeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );
    
    // Register this card in the static registry with debug info
    if (widget.friend['id'] != null) {
      print("FriendCard: Registering card with ID: ${widget.friend['id']}");
      FriendCard._activeCards[widget.friend['id']] = this;
    }
    
    // If this is an incoming call, immediately go to full screen
    if (widget.isIncoming && widget.callData != null) {
      print("FriendCard: This is an incoming call, going straight to full screen");
      
      // Set the channel ID from call data
      _channelId = widget.callData!['channel_id'] ?? '';
      
      // Use a post-frame callback to ensure the widget is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _captureInitialCardPosition(context);
          _goToFullScreenDirectly();
        }
      });
      
      // Listen for the other user (caller) leaving, which should end the call
      _listenForRemoteUsers();
    }
  }

  @override
  void dispose() {
    final String? cardId = widget.friend['id'];
    print("FriendCard: Disposing card with ID: $cardId");
    _intermediateStateTimer?.cancel();
    _intermediateStateTimer = null;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    _callTimer?.cancel();
    _callTimer = null;
    _remoteUserSubscription?.cancel();
    _removeOverlay();
    _controller.dispose();
    
    // Remove from registry when disposed
    if (cardId != null) {
      FriendCard._activeCards.remove(cardId);
      print("FriendCard: Removed card with ID: $cardId from registry");
    }
    
    super.dispose();
  }
  
  // Generate a random channel ID
  String _generateChannelId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(10000);
    return 'channel_${timestamp}_$randomNum';
  }
  
  // Listen for remote users joining the call
  void _listenForRemoteUsers() {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    _remoteUserSubscription = callProvider.onRemoteUsersChanged.listen((users) {
      print("FriendCard: Remote users updated: $users");
      
      if (users.isNotEmpty && !_otherUserJoined) {
        setState(() {
          _otherUserJoined = true;
        });
        
        // If we're still in intermediate state, go to full screen
        if (_isInIntermediateState) {
          print("FriendCard: Remote user joined, transitioning to full screen");
          _goToFullScreen();
        }
      } else if (users.isEmpty && _otherUserJoined) {
        // The other user left
        print("FriendCard: All remote users left");
        
        // Only end the call automatically if we're not the initiator
        if (widget.isIncoming) {
          print("FriendCard: As receiver, ending call because initiator left");
          // End the call
          final callProvider = Provider.of<CallProvider>(context, listen: false);
          callProvider.endCall();
          
          // Close the screen/overlay
          if (_isLocked || _isMovingToFullScreen) {
            setState(() {
              _isLocked = false;
            });
            _controller.reverse();
            _removeOverlay();
            
            // If this is a separate screen (for receiver), pop it
            if (widget.isIncoming) {
              Navigator.of(context).pop();
            }
          }
        }
      }
    });
  }
  
  // Send call invitation via FCM
  Future<bool> _sendCallInvitation() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("FriendCard: Cannot send invitation - not logged in");
        return false;
      }
      
      final receiverUid = widget.friend['id'];
      if (receiverUid == null || receiverUid.isEmpty) {
        print("FriendCard: Cannot send invitation - no receiver ID");
        return false;
      }
      
      // Generate a channel ID
      _channelId = _generateChannelId();
      
      print("FriendCard: Sending call invitation to: $receiverUid with channel: $_channelId");
      
      // Send the invitation via FCM
      final success = await _fcmService.sendRoomInvitation(
        channelId: _channelId,
        receiverUid: receiverUid,
        senderUid: currentUser.uid,
      );
      
      print("FriendCard: FCM invitation sent: $success");
      return success;
    } catch (e) {
      print("FriendCard: Error sending call invitation: $e");
      return false;
    }
  }

  // Method to start a call duration timer
  void _startCallTimer() {
    _callTimer?.cancel();
    _callDuration = Duration.zero;
    
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
        });
        
        // Update the overlay to show the new duration
        _updateOverlay();
      }
    });
  }
  
  // Format duration for display
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  // Update overlay without removing/recreating
  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }
  
  // Method for receiver to go directly to full screen
  void _goToFullScreenDirectly() {
    print("DEBUG: Going directly to full screen for incoming call");
    
    setState(() {
      _isInIntermediateState = false;
      _isMovingToFullScreen = true;
      _intermediateProgress = 5;
      _vibrationProgress = 0.0;
      _vibrationOffset = 0.0;
      _vibrationAngle = 0.0;
    });
    
    // Set longer duration for animation
    _controller.duration = const Duration(milliseconds: 800);
    _controller.reset();
    
    // Show overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverlay();
    });
    
    // Automatically go to full screen
    _controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _isLocked = true;
        });
        
        // Start tracking call duration
        _startCallTimer();
        
        // Update UI
        _updateOverlay();
      }
    });
    
    // Connect to the Agora channel
    _connectToCall();
  }
  
  // Connect to Agora channel
  Future<void> _connectToCall() async {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // For initiator: prepare a new call
    if (!widget.isIncoming) {
      // Create call data
      final callData = {
        'channelId': _channelId,
        'callerId': FirebaseAuth.instance.currentUser?.uid,
        'callerName': FirebaseAuth.instance.currentUser?.displayName ?? 'User',
        'callerPhoto': FirebaseAuth.instance.currentUser?.photoURL ?? '',
        'receiverId': widget.friend['id'],
        'receiverName': widget.friend['displayName'] ?? widget.friend['name'] ?? 'Friend',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await callProvider.startCall(callData);
    }
    // For receiver: the call data was already passed to CallProvider in _showIncomingCallScreen
  }
  
  // Method to programmatically trigger call animation from FCM
  void _triggerCallAnimation() {
    // Ensure we're not already in a call state
    if (_isLocked || _isInIntermediateState || _isMovingToFullScreen) {
      print("DEBUG: Card already in animated state, ignoring trigger");
      return;
    }
    
    print("DEBUG: Triggering call animation programmatically");
    
    // First send the FCM notification as initiator
    _sendCallInvitation().then((success) {
      if (success) {
        // Capture initial card position if needed
        if (_initialCardRect == null) {
          _captureInitialCardPosition(context);
        }
        
        // Show the overlay first
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOverlay();
        });
        
        // Start the initial animation
        _controller.forward().then((_) {
          if (mounted) {
            // Move to intermediate state (connecting animation)
            _startIntermediateState();
            
            // Listen for remote users joining
            _listenForRemoteUsers();
            
            // Connect to the call channel
            _connectToCall();
          }
        });
      } else {
        // Show error if FCM notification failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initiate call. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  void _captureInitialCardPosition(BuildContext context) {
    // Get the RenderBox of the card
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    // Get the global position of the card
    final Offset position = renderBox.localToGlobal(Offset.zero);
    
    // Store the card's position and size
    _initialCardRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      renderBox.size.width,
      renderBox.size.height
    );
  }

  void _showOverlay() {
    final BuildContext currentContext = context;
    
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Get screen dimensions
          final Size screenSize = MediaQuery.of(overlayContext).size;
          final double screenWidth = screenSize.width;
          final double screenHeight = screenSize.height;
          
          // Get fullscreen target dimensions
          final double targetWidthFullScreen = screenWidth;
          final double targetHeightFullScreen = screenHeight;
          final double targetLeftFullScreen = 0;
          final double targetTopFullScreen = 0;
          
          // Initialize with defaults in case initial rect isn't captured
          double initialWidth = screenWidth * 0.75;
          double initialHeight = screenHeight * 0.5;
          double initialLeft = (screenWidth - initialWidth) / 2;
          double initialTop = (screenHeight - initialHeight) / 2;
          
          // If we have captured the initial card position, use it
          if (_initialCardRect != null) {
            initialWidth = _initialCardRect!.width;
            initialHeight = _initialCardRect!.height;
            initialLeft = _initialCardRect!.left;
            initialTop = _initialCardRect!.top;
          }
          
          // Calculate intermediate position (65% of the way to full screen)
          final double intermediateWidth = initialWidth + (targetWidthFullScreen - initialWidth) * 0.65;
          final double intermediateHeight = initialHeight + (targetHeightFullScreen - initialHeight) * 0.65;
          final double intermediateLeft = initialLeft + (targetLeftFullScreen - initialLeft) * 0.65;
          final double intermediateTop = initialTop + (targetTopFullScreen - initialTop) * 0.65;
          
          // Calculate current sizes based on animation state
          double currentWidth, currentHeight, currentLeft, currentTop;
          double backdropBlurAmount;
          double backgroundOpacity;
          double rotation = 0.0; // Default rotation
          
          if (_isInIntermediateState) {
            // Calculate pendulum-like curved vibration - balanced intensity
            double horizontalOffset = sin(_vibrationProgress * 2.5 * 3.14159) * 12.0;
            double verticalOffset = sin(_vibrationProgress * 4 * 3.14159) * 5.0;
            
            // Fixed at 65% of the way to full screen with curved pendulum vibration
            currentWidth = intermediateWidth;
            currentHeight = intermediateHeight;
            currentLeft = intermediateLeft + horizontalOffset;
            currentTop = intermediateTop + verticalOffset;
            rotation = sin(_vibrationProgress * 3 * 3.14159) * 0.025; // Moderate rotation
            backdropBlurAmount = 5.0;
            backgroundOpacity = 0.3;
            
            print("DEBUG: In intermediate state, progress: $_intermediateProgress/5, vibration: $_vibrationProgress");
          } else if (_isMovingToFullScreen) {
            // Animate from 65% to full screen
            final double t = _controller.value;
            currentWidth = intermediateWidth + (targetWidthFullScreen - intermediateWidth) * t;
            currentHeight = intermediateHeight + (targetHeightFullScreen - intermediateHeight) * t;
            currentLeft = intermediateLeft * (1 - t);
            currentTop = intermediateTop * (1 - t);
            // Fade out blur as we go to full screen
            backdropBlurAmount = 5.0 * (1 - t);
            backgroundOpacity = 0.3 + 0.2 * t;
            
            print("DEBUG: Moving to full screen, animation value: ${_controller.value.toStringAsFixed(2)}");
            
            // If the animation reaches the end, ensure we're at full screen dimensions
            if (t >= 0.99) {
              print("DEBUG: Animation reached end, setting full screen dimensions");
              currentWidth = targetWidthFullScreen;
              currentHeight = targetHeightFullScreen;
              currentLeft = 0;
              currentTop = 0;
              backdropBlurAmount = 0.0; // No blur in full screen
            }
          } else {
            // Animate from initial to 65% of the way to full screen
            final double t = _sizeAnimation.value;
            currentWidth = initialWidth + (intermediateWidth - initialWidth) * t;
            currentHeight = initialHeight + (intermediateHeight - initialHeight) * t;
            currentLeft = initialLeft + (intermediateLeft - initialLeft) * t;
            currentTop = initialTop + (intermediateTop - initialTop) * t;
            backdropBlurAmount = 10.0 * t;
            backgroundOpacity = 0.5 * t;
            
            print("DEBUG: Initial animation to 65%, value: ${_sizeAnimation.value.toStringAsFixed(2)}");
          }
          
          // Calculate the border radius based on the state
          double borderRadius = 20.0;
          if (_isMovingToFullScreen) {
            // Transition from 20 to 0 during the final animation
            borderRadius = 20.0 * (1.0 - _controller.value);
          }
          
          // Check if now in full screen mode
          bool isFullyExpandedScreen = _isMovingToFullScreen && _controller.value >= 0.99;
          
          return Material(
            color: Colors.black.withOpacity(backgroundOpacity),
            child: Stack(
              children: [
                // Animated background blur - Only show when not in full screen mode
                if (!isFullyExpandedScreen)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: backdropBlurAmount,
                      sigmaY: backdropBlurAmount,
                    ),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                // Positioned card with animation
                Positioned(
                  left: currentLeft,
                  top: currentTop,
                  width: currentWidth,
                  height: currentHeight,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Hero(
                      tag: 'friend-card-${widget.friend['id']}-fullscreen',
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(borderRadius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Card content
                              ClipRRect(
                                borderRadius: BorderRadius.circular(borderRadius),
                                child: _buildCardContent(isFullScreen: _isMovingToFullScreen || _isInIntermediateState),
                              ),
                              // Blur overlay for initial animation and intermediate state, but not full screen
                              if ((_sizeAnimation.value > 0.0 || _isInIntermediateState) && !isFullyExpandedScreen)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(borderRadius),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: _isInIntermediateState ? 5.0 : (_sizeAnimation.value * 5.0),
                                      sigmaY: _isInIntermediateState ? 5.0 : (_sizeAnimation.value * 5.0),
                                    ),
                                    child: Container(
                                      color: Colors.black.withOpacity(_isInIntermediateState ? 0.3 : (_sizeAnimation.value * 0.3)),
                                      child: Center(
                                        child: _isInIntermediateState ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                              value: _isInIntermediateState ? 
                                                _intermediateProgress / 5.0 : 
                                                null,
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Connecting...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ) : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              
                              // Call duration timer - only show when in full screen mode and call is active
                              if (isFullyExpandedScreen && _callTimer != null)
                                Positioned(
                                  top: 50,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.timer,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatDuration(_callDuration),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Lock/Unlock button - only show when locked
                if (_isLocked || (_isMovingToFullScreen && _controller.value >= 0.99))
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
                              onPressed: _toggleMicrophone,
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
                              onPressed: _toggleVideo,
                              label: _isVideoOn ? 'Video Off' : 'Video On',
                            ),
                            // End call button (larger and red)
                            _buildCallControlButton(
                              icon: Icons.call_end,
                              color: Colors.white,
                              backgroundColor: Colors.red.shade700,
                              size: 64,
                              onPressed: () {
                                // End call through provider
                                final callProvider = Provider.of<CallProvider>(context, listen: false);
                                callProvider.endCall();
                                
                                // Close the incoming call screen
                                Navigator.of(context).pop();
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
                              onPressed: _toggleSpeaker,
                              label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Visual swipe path - only show during long press but not locked
                if (_isLongPressed && !_isLocked && _dragStartPosition != null && isFullyExpandedScreen)
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
                if (_isLongPressed && !_isLocked && _dragStartPosition != null && _pathEndPosition != null && isFullyExpandedScreen)
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
                if (_isLongPressed && !_isLocked && _dragProgress < 0.2 && isFullyExpandedScreen)
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

    Overlay.of(currentContext).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    print("DEBUG: Removing overlay, state: intermediate=${_isInIntermediateState}, moving=${_isMovingToFullScreen}");
    
    // Always keep track of the timer but only cancel if not going to full screen or in the middle of transitions
    if (!_isInIntermediateState && !_isMovingToFullScreen) {
      print("DEBUG: Canceling timer because we're no longer in transition");
      _intermediateStateTimer?.cancel();
      _intermediateStateTimer = null;
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
    }
    
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
    
    // Reset drag progress
    _dragProgress = 0.0;
    
    // Don't reset these flags here, as it might interrupt the animation sequence
    if (!_isMovingToFullScreen && !_isInIntermediateState) {
      print("DEBUG: Resetting all animation state flags");
      _isInIntermediateState = false;
      _isMovingToFullScreen = false;
      _intermediateProgress = 0;
      _vibrationOffset = 0.0;
    }
  }

  void _startIntermediateState() {
    print("DEBUG: Starting intermediate state");
    
    // Cancel any existing timer first
    _intermediateStateTimer?.cancel();
    _vibrationTimer?.cancel();
    
    // Reset progress counter
    _intermediateProgress = 0;
    
    setState(() {
      _isInIntermediateState = true;
      _isMovingToFullScreen = false;
      _vibrationOffset = 0.0;
    });
    
    _removeOverlay();
    _showOverlay();
    
    // Start vibration animation
    _startVibrationEffect();
    
    // Start progress updates every second to show progression
    _updateIntermediateProgress();
    
    // Start a single 5-second timer
    print("DEBUG: Starting 5-second countdown timer");
    _intermediateStateTimer = Timer(const Duration(seconds: 5), () {
      print("DEBUG: 5 seconds completed! Moving to full screen now");
      
      if (mounted) {
        print("DEBUG: Widget is still mounted, calling _goToFullScreen()");
        // Move to full screen directly
        _goToFullScreen();
      } else {
        print("DEBUG: Widget is no longer mounted!");
      }
    });
  }
  
  void _startVibrationEffect() {
    // Trigger initial haptic feedback
    HapticFeedback.mediumImpact();
    
    // Reset vibration progress
    _vibrationProgress = 0.0;
    
    // Setup vibration timer that runs every 35ms for balanced animation speed
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!_isInIntermediateState || !mounted) {
        timer.cancel();
        return;
      }
      
      // Update vibration progress for smooth animation - balanced speed
      setState(() {
        // Moderate increment for balanced shaking speed
        _vibrationProgress = (_vibrationProgress + 0.05) % 1.0;
      });
      
      // Provide haptic feedback
      if ((_vibrationProgress * 100).toInt() % 20 == 0) {
        HapticFeedback.lightImpact();
      }
      
      // Refresh overlay to show the vibration
      _removeOverlay();
      _showOverlay();
    });
  }
  
  void _updateIntermediateProgress() {
    // Update every second until we reach 5 seconds
    if (_intermediateProgress < 5 && _isInIntermediateState && mounted) {
      // Update UI to show progress
      setState(() {
        _intermediateProgress++;
      });
      
      print("DEBUG: Intermediate progress: $_intermediateProgress/5");
      
      // Refresh overlay to show updated progress
      _removeOverlay();
      _showOverlay();
      
      // Schedule next update if still in intermediate state
      if (_intermediateProgress < 5 && _isInIntermediateState) {
        Future.delayed(const Duration(seconds: 1), _updateIntermediateProgress);
      }
    }
  }

  void _goToFullScreen() {
    print("DEBUG: _goToFullScreen() called!");
    
    // Make sure there's no active timer that could interfere
    _intermediateStateTimer?.cancel();
    _intermediateStateTimer = null;
    
    // Stop vibration effect
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    
    // Ensure we're not in intermediate state anymore
    setState(() {
      _isInIntermediateState = false;
      _isMovingToFullScreen = true;
      _intermediateProgress = 5; // Set to max to prevent further updates
      _vibrationProgress = 0.0; // Reset vibration
      _vibrationOffset = 0.0;
      _vibrationAngle = 0.0;
    });
    
    // Reset animation controller with longer duration for full screen animation
    _controller.duration = const Duration(milliseconds: 800);
    _controller.reset();
    
    print("DEBUG: Updating overlay before animation");
    // Use post frame callback to ensure UI is updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removeOverlay();
      _showOverlay();
      
      // Start the animation to full screen with completion callback
      print("DEBUG: Starting animation to full screen");
      _controller.forward().then((_) {
        print("DEBUG: Full screen animation completed successfully!");
        
        // When animation completes, auto-lock the card and start call timer
        if (mounted) {
          setState(() {
            _isLocked = true;
          });
          
          // Start call timer to track call duration
          _startCallTimer();
          
          // Update UI
          _updateOverlay();
        }
      });
    });
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
    // For incoming calls, immediately show full screen overlay
    if (widget.isIncoming) {
      // Ensure we have enough space for the card
      return InkWell(
        onTap: () {
          // If tapped and not already in full screen, immediately go there
          if (!_isMovingToFullScreen && !_isLocked) {
            _goToFullScreenDirectly();
          }
        },
        child: Stack(
          children: [
            // Main content
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.transparent,
              child: _buildCardContent(isFullScreen: true),
            ),
            
            // Call controls overlay at bottom
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
                        onPressed: _toggleMicrophone,
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
                        onPressed: _toggleVideo,
                        label: _isVideoOn ? 'Video Off' : 'Video On',
                      ),
                      // End call button (larger and red)
                      _buildCallControlButton(
                        icon: Icons.call_end,
                        color: Colors.white,
                        backgroundColor: Colors.red.shade700,
                        size: 64,
                        onPressed: () {
                          // End call through provider
                          final callProvider = Provider.of<CallProvider>(context, listen: false);
                          callProvider.endCall();
                          
                          // Close the incoming call screen
                          Navigator.of(context).pop();
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
                        onPressed: _toggleSpeaker,
                        label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Normal card for showing in the list
    return GestureDetector(
      onLongPressStart: (details) {
        print("DEBUG: Long press started");
        // Capture the current position and size of the card first
        _captureInitialCardPosition(context);
        
        // Determine path direction and end position once at the start of the gesture
        final Size screenSize = MediaQuery.of(context).size;
        _currentPathDirection = SwipePathPainter.determineDirection(details.globalPosition, screenSize);
        _pathEndPosition = SwipePathPainter.calculateEndPosition(details.globalPosition, screenSize, _currentPathDirection!);
        
        setState(() {
          _isLongPressed = true;
          _dragStartPosition = details.globalPosition;
          _dragProgress = 0.0;
        });
        
        // Trigger call animation which will send FCM and show connecting UI
        _triggerCallAnimation();
      },
      onLongPressEnd: (details) {
        print("DEBUG: Long press ended");
        setState(() {
          _isLongPressed = false;
        });
        
        // Always return to original size when released, unless locked
        if (!_isLocked) {
          print("DEBUG: Returning to original size on release - not locked");
          
          // Cancel any pending transition to full screen
          _intermediateStateTimer?.cancel();
          _intermediateStateTimer = null;
          
          // Reset states
          setState(() {
            _isInIntermediateState = false;
            _isMovingToFullScreen = false;
          });
          
          // End the call since user released without locking
          final callProvider = Provider.of<CallProvider>(context, listen: false);
          callProvider.endCall();
          
          // Animate back to original size
          _controller.reverse();
          _removeOverlay();
        } else {
          print("DEBUG: Not returning to original size - card is locked");
        }
      },
      onLongPressMoveUpdate: (details) {
        // Only allow locking when in full screen mode
        if (_isLongPressed && !_isLocked && _dragStartPosition != null && _pathEndPosition != null && 
            _isMovingToFullScreen && _controller.value >= 0.99) {
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
          width: MediaQuery.of(context).size.width * 0.65,
          height: MediaQuery.of(context).size.height * 0.4,
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

  // Toggle microphone mute state
  Future<void> _toggleMicrophone() async {
    // Check microphone permission if trying to unmute
    if (_isMicOn == false) {
      // Request permission if trying to enable mic
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required to unmute'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Permission denied, keep mic off
        return;
      }
    }
    
    // Update call provider
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final success = await callProvider.toggleMute();
    
    if (mounted) {
      setState(() {
        // Only toggle UI state if the action was successful
        _isMicOn = success ? !_isMicOn : _isMicOn;
      });
      
      // Show feedback about microphone state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isMicOn ? 'Microphone is now on' : 'Microphone is now muted'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Update UI
      _updateOverlay();
    }
  }
  
  // Toggle video state
  Future<void> _toggleVideo() async {
    // Check camera permission if trying to enable video
    if (_isVideoOn == false) {
      // Request permission if trying to enable camera
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to enable video'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Permission denied, keep video off
        return;
      }
    }
    
    // Update call provider
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final success = await callProvider.toggleVideo();
    
    if (mounted) {
      setState(() {
        // Only toggle UI state if the action was successful
        _isVideoOn = success ? !_isVideoOn : _isVideoOn;
      });
      
      // Show feedback about video state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVideoOn ? 'Video is now on' : 'Video is now off'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Update UI
      _updateOverlay();
    }
  }
  
  // Toggle speaker state
  Future<void> _toggleSpeaker() async {
    // Update call provider
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final success = await callProvider.toggleSpeaker();
    
    if (mounted) {
      setState(() {
        // Only update UI if the toggle was successful
        _isSpeakerOn = success ? !_isSpeakerOn : _isSpeakerOn;
      });
      
      // Show feedback about speaker state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSpeakerOn ? 'Speaker is now on' : 'Speaker is now off'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Update UI
      _updateOverlay();
    }
  }
} 