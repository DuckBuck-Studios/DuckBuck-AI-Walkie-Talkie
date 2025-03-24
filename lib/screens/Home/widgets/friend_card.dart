import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'swipe_path_painter.dart';
import '../../../providers/call_provider.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'friend_card_initiator.dart';
import 'friend_card_receiver.dart';
import 'friend_card_ui.dart';

// Friend Card Widget
class FriendCard extends StatefulWidget {
  final Map<String, dynamic> friend;
  final bool showStatus;
  final bool isIncoming; // Flag to indicate if this is for an incoming call
  final Map<String, dynamic>? callData; // Call data for incoming calls

  // Static registry to track friend cards for FCM handling
  static final Map<String, _FriendCardState> _activeCards = {};

  // Static method to trigger an outgoing call to a friend
  static void initiateCall(BuildContext context, Map<String, dynamic> friend) {
    try {
      // Create a temporary friend card
      final friendCard = FriendCard(
        friend: friend,
        isIncoming: false,
      );
      
      // Show the card as a dialog
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            return Material(
              type: MaterialType.transparency,
              child: friendCard,
            );
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
      print("FriendCard: Error initiating call: $e");
    }
  }
  
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
          FriendCardReceiver.showIncomingCallScreen(context, receiverCard);
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
      FriendCardReceiver.showIncomingCallScreen(context, receiverCard);
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
        FriendCardReceiver.showIncomingCallScreen(context, receiverCard);
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
          FriendCardReceiver.showIncomingCallScreen(context, receiverCard);
        } else {
          print("FriendCard: No cards available to handle the call");
        }
      } else {
        print("FriendCard: No cards available to handle the call");
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
  // Modular components
  late FriendCardInitiator _initiator;
  late FriendCardReceiver? _receiver;
  
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
    
    // Initialize the initiator module
    _initiator = FriendCardInitiator(
      context: context,
      friend: widget.friend,
      setLongPressed: (value) => setState(() => _isLongPressed = value),
      setLocked: (value) => setState(() => _isLocked = value),
      setInIntermediateState: (value) => setState(() => _isInIntermediateState = value),
      setMovingToFullScreen: (value) => setState(() => _isMovingToFullScreen = value),
      setDragStartPosition: (value) => setState(() => _dragStartPosition = value),
      setDragProgress: (value) => setState(() => _dragProgress = value),
      setCurrentPathDirection: (value) => setState(() => _currentPathDirection = value),
      setPathEndPosition: (value) => setState(() => _pathEndPosition = value),
      setChannelId: (value) => setState(() => _channelId = value),
      captureInitialCardPosition: () => _captureInitialCardPosition(context),
      showOverlay: _showOverlay,
      removeOverlay: _removeOverlay,
      startIntermediateState: _startIntermediateState,
      listenForRemoteUsers: _listenForRemoteUsers,
      connectToCall: _connectToCall,
      controller: _controller,
    );
    
    // Initialize the receiver module if this is an incoming call
    if (widget.isIncoming) {
      _receiver = FriendCardReceiver(
        context: context,
        friend: widget.friend,
        callData: widget.callData,
        setInIntermediateState: (value) => setState(() => _isInIntermediateState = value),
        setMovingToFullScreen: (value) => setState(() => _isMovingToFullScreen = value),
        setLocked: (value) => setState(() => _isLocked = value),
        setIntermediateProgress: (value) => setState(() => _intermediateProgress = value),
        setVibrationProgress: (value) => setState(() => _vibrationProgress = value),
        setVibrationOffset: (value) {}, // No-op as we've removed the field
        setVibrationAngle: (value) {}, // No-op as we've removed the field
        setChannelId: (value) => setState(() => _channelId = value),
        startCallTimer: _startCallTimer,
        updateOverlay: _updateOverlay,
        connectToCall: _connectToCall,
        controller: _controller,
      );
    }
    
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
    return FriendCardUI.formatDuration(duration);
  }
  
  // Update overlay without removing/recreating
  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }
  
  // Method for receiver to go directly to full screen
  void _goToFullScreenDirectly() {
    if (widget.isIncoming && _receiver != null) {
      _receiver!.goToFullScreenDirectly();
    } else {
      print("DEBUG: Going directly to full screen for incoming call");
      
      setState(() {
        _isInIntermediateState = false;
        _isMovingToFullScreen = true;
        _intermediateProgress = 5;
        _vibrationProgress = 0.0;
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
                                child: FriendCardUI.buildCardContent(
                                  friend: widget.friend,
                                  showStatus: widget.showStatus,
                                  isFullScreen: _isMovingToFullScreen || _isInIntermediateState,
                                ),
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
      _vibrationProgress = 0.0;
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
      _vibrationProgress = 0.0;
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

  // Helper method to build call control buttons
  Widget _buildCallControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    double size = 48,
    Color? backgroundColor,
  }) {
    // Use the UI helper
    return FriendCardUI.buildCallControlButton(
      icon: icon,
      color: color,
      onPressed: onPressed,
      label: label,
      size: size,
      backgroundColor: backgroundColor,
    );
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
              child: FriendCardUI.buildCardContent(
                friend: widget.friend,
                showStatus: widget.showStatus,
                isFullScreen: true
              ),
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
        // End any ongoing call before starting a new one
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        if (callProvider.status != CallStatus.idle) {
          print("FriendCard: Ending ongoing call before starting a new one");
          callProvider.endCall();
        }
        
        // Reset any UI states that might be lingering
        if (_isLocked || _isInIntermediateState || _isMovingToFullScreen) {
          setState(() {
            _isLocked = false;
            _isInIntermediateState = false;
            _isMovingToFullScreen = false;
          });
          _controller.reset();
          _removeOverlay();
        }
        
        // Now delegate to the initiator's long press handler
        _initiator.onLongPressStart(details);
      },
      onLongPressEnd: _initiator.onLongPressEnd,
      onLongPressMoveUpdate: _initiator.onLongPressMoveUpdate,
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
            child: FriendCardUI.buildCardContent(
              friend: widget.friend,
              showStatus: widget.showStatus,
              isFullScreen: false
            ),
          ),
        ),
      ),
    );
  }
} 