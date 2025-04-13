import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/friend_provider.dart'; 
import '../../providers/call_provider.dart';
import '../Call/call_screen.dart';
import 'main_button.dart';
import 'profile_screen.dart';
import 'friend_screen.dart';
import 'setting/settings_screen.dart';
import 'navigation_card.dart';
import 'qr_code_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _isLoading = true;
  late PageController _pageController;
  int _currentPage = 0;
  String? _lastInteractedUserId;
  Map<String, dynamic>? _selectedFriend;
  final QRCodeScreen _qrCodeScreen = QRCodeScreen();
  bool _isUserMuted = false;
  bool _isMutedByFriend = false;
  StreamSubscription? _muteStatusSubscription;
  StreamSubscription? _mutedByFriendSubscription;
  StreamSubscription? _callInvitationSubscription;
  late AnimationController _muteAnimationController;
  late AnimationController _pulseAnimationController;
  bool _isTogglingMute = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen: Initializing');
    _muteAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimationController.repeat(reverse: true);
    
    // Initialize with a dummy controller first
    // We'll create the real one after we have determined the initial page
    _pageController = PageController();
    
    // Initialize in a single step and listen for call invitations
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      // Load last interacted user ID from shared preferences
      await _loadLastInteractedUser();
      
      // Initialize FriendProvider only once
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      if (!friendProvider.isInitialized) {
        await friendProvider.initialize();
      }
      
      // Listen for call invitations
      _listenForCallInvitations();
      
      // Determine initial page based on friends list and last interacted user
      await _determineInitialPage();
      
      // Mark as initialized to prevent double animations
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('HomeScreen: Error during initialization: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loadLastInteractedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastInteractedUserId = prefs.getString('last_interacted_user');
      debugPrint('HomeScreen: Loaded last interacted user: $_lastInteractedUserId');
    } catch (e) {
      debugPrint('HomeScreen: Error loading last interacted user: $e');
    }
  }
  
  Future<void> _saveLastInteractedUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_interacted_user', userId);
      _lastInteractedUserId = userId;
      debugPrint('HomeScreen: Saved last interacted user: $userId');
    } catch (e) {
      debugPrint('HomeScreen: Error saving last interacted user: $e');
    }
  }
  
  Future<void> _determineInitialPage() async {
    if (!mounted) return;
    
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final friends = friendProvider.friends;
    
    int initialPage = 0;
    
    // Default to navigation card (page 0) if no friends
    if (friends.isEmpty) {
      _currentPage = 0;
      _pageController = PageController(initialPage: 0);
      return;
    }
    
    // If we have a last interacted user, find them in the friends list
    if (_lastInteractedUserId != null) {
      for (int i = 0; i < friends.length; i++) {
        if (friends[i]['id'] == _lastInteractedUserId) {
          // Add 1 because page 0 is navigation card
          initialPage = i + 1;
          _selectedFriend = friends[i];
          break;
        }
      }
    }
    
    // If no last interacted user or not found, default to first friend
    if (initialPage == 0 && friends.isNotEmpty) {
      initialPage = 1; // First friend
      _selectedFriend = friends[0];
    }

    // Create a new PageController with the determined initial page
    _pageController = PageController(initialPage: initialPage);
    
    // Update current page state
    if (mounted) {
      setState(() {
        _currentPage = initialPage;
      });
    }
    
    // Set up mute status listener for the selected friend
    if (_selectedFriend != null) {
      _setupMuteStatusListener();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('HomeScreen: App lifecycle state changed to $state');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _muteStatusSubscription?.cancel();
    _mutedByFriendSubscription?.cancel();
    _callInvitationSubscription?.cancel();
    _muteAnimationController.dispose();
    _pulseAnimationController.dispose();
    debugPrint('HomeScreen: Disposing');
    super.dispose();
  }

  void _setupMuteStatusListener() {
    if (_selectedFriend != null) {
      _muteStatusSubscription?.cancel();
      _mutedByFriendSubscription?.cancel();
      
      _muteStatusSubscription = context.read<FriendProvider>()
          .isUserMutedStream(_selectedFriend!['id'])
          .listen((isMuted) {
        setState(() {
          _isUserMuted = isMuted;
        });
      });
      
      _mutedByFriendSubscription = context.read<FriendProvider>()
          .isMutedByUserStream(_selectedFriend!['id'])
          .listen((isMutedByFriend) {
        setState(() {
          _isMutedByFriend = isMutedByFriend;
        });
        debugPrint('HomeScreen: Current user is${isMutedByFriend ? '' : ' not'} muted by ${_selectedFriend!['displayName']}');
      });
    }
  }

  void _checkIfMutedByFriend() async {
    if (_selectedFriend == null) return;
    
    try {
      final isMutedByFriend = await context.read<FriendProvider>()
          .isMutedByUser(_selectedFriend!['id']);
      if (mounted) {
        setState(() {
          _isMutedByFriend = isMutedByFriend;
        });
      }
      debugPrint('HomeScreen: Current user is${isMutedByFriend ? '' : ' not'} muted by ${_selectedFriend!['displayName']}');
    } catch (error) {
      debugPrint('Error checking if muted by friend: $error');
    }
  }

  void _onFriendSelected(Map<String, dynamic> friend) {
    setState(() {
      _selectedFriend = friend;
    });
    
    // Save this as the last interacted user
    if (friend['id'] != null) {
      _saveLastInteractedUser(friend['id']);
    }
    
    _setupMuteStatusListener();
  }

  void _startCall() {
    if (_selectedFriend == null) return;
    
    if (_isMutedByFriend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can\'t call this user because they have disabled notifications from you.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Save this as the last interacted user when starting a call
    if (_selectedFriend!['id'] != null) {
      _saveLastInteractedUser(_selectedFriend!['id']);
    }

    _showOverlay();
  }

  void _showOverlay() {
    if (_selectedFriend == null) return;
    
    debugPrint('Starting call with ${_selectedFriend!['displayName']}');
  }

  void _toggleMute() async {
    if (_selectedFriend == null || _isTogglingMute) return;
    
    setState(() {
      _isTogglingMute = true;
    });
    
    try {
      // Get current state before the API call
      bool currentState = _isUserMuted;
      
      // Update the UI immediately for a more responsive feel
      setState(() {
        _isUserMuted = !currentState;
      });
      
      // Make the API call
      if (currentState) { // Was muted, now unmuting
        await context.read<FriendProvider>().unmuteUser(_selectedFriend!['id']);
      } else { // Was unmuted, now muting
        await context.read<FriendProvider>().muteUser(_selectedFriend!['id']);
      }
      
      _checkIfMutedByFriend();
    } catch (e) {
      debugPrint('Error toggling notification status: $e');
      
      // Revert state on error
      setState(() {
        _isUserMuted = !_isUserMuted;
      });
    } finally {
      // Add a small delay to prevent rapid toggling
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() {
          _isTogglingMute = false;
        });
      }
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(
          onBackPressed: (ctx) => Navigator.pop(ctx),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToFriends() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FriendScreen(
          onBackPressed: (ctx) => Navigator.pop(ctx),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _listenForCallInvitations() {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    _callInvitationSubscription = callProvider.callStateChanges.listen((state) {
      if (state == CallState.connected) {
        // Show the call screen
        _showCallScreen();
      }
    });
  }
  
  void _showCallScreen() {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final callData = callProvider.currentCall;
    
    // Save this as the last interacted user when receiving a call
    final senderUid = callData['sender_uid'];
    if (senderUid != null) {
      _saveLastInteractedUser(senderUid);
    }
    
    Navigator.of(context).push(CallScreenRoute(callData: callData));
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomBarHeight = screenHeight * 0.25;
    final nameContainerHeight = screenHeight * 0.15;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<FriendProvider>(
        builder: (context, friendProvider, child) {
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          final friends = friendProvider.friends;
          
          // If no friends, just show the NavigationCard
          if (friends.isEmpty) {
            return NavigationCard(
              onNavigateToProfile: _navigateToProfile,
              onNavigateToFriends: _navigateToFriends,
              onNavigateToSettings: _navigateToSettings,
              onShowQRCode: (ctx) {
                HapticFeedback.selectionClick();
                _qrCodeScreen.showQRCode(ctx);
              },
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // PageView for swiping through friends
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  // Only perform haptic feedback and extra operations if fully initialized
                  if (_isInitialized) {
                    HapticFeedback.selectionClick();
                  }
                  
                  setState(() {
                    _currentPage = index;
                    _selectedFriend = index == 0 ? null : friends[index - 1];
                  });
                  
                  // Only update last interacted user if fully initialized (not during startup)
                  if (_isInitialized && index > 0 && friends.isNotEmpty) {
                    final friendId = friends[index - 1]['id'];
                    if (friendId != null) {
                      _saveLastInteractedUser(friendId);
                    }
                  }
                  
                  // Check mute status when changing pages
                  if (_selectedFriend != null) {
                    _setupMuteStatusListener();
                  }
                },
                physics: const BouncingScrollPhysics(),
                itemCount: friends.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return NavigationCard(
                      onNavigateToProfile: _navigateToProfile,
                      onNavigateToFriends: _navigateToFriends,
                      onNavigateToSettings: _navigateToSettings,
                      onShowQRCode: (ctx) {
                        HapticFeedback.selectionClick();
                        _qrCodeScreen.showQRCode(ctx);
                      },
                    );
                  }
                  
                  final friendIndex = index - 1;
                  final friend = friends[friendIndex];
                  
                  return GestureDetector(
                    onTap: () => _onFriendSelected(friend),
                    child: Hero(
                      tag: 'friend_${friend['id']}',
                      child: friend['photoURL'] != null
                          ? CachedNetworkImage(
                              imageUrl: friend['photoURL'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 120,
                              ),
                            )
                          : const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 120,
                              ),
                            ),
                    ),
                  );
                },
              ),

              // Mute Button - Only show if not on navigation card
              if (_currentPage > 0)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Tooltip(
                      message: _isUserMuted ? 'Enable Notifications' : 'Disable Notifications',
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          
                          // Add quick animation on tap
                          _muteAnimationController.forward(from: 0).then((_) {
                            _muteAnimationController.reset();
                          });
                          
                          _toggleMute();
                        },
                        child: AnimatedBuilder(
                          animation: _muteAnimationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 - (_muteAnimationController.value * 0.1),
                              child: child,
                            );
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: _isUserMuted 
                                    ? Colors.red.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.2),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Background pulse animation (only when muted)
                                if (_isUserMuted)
                                  AnimatedBuilder(
                                    animation: _pulseAnimationController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: 0.9 + 0.2 * _pulseAnimationController.value,
                                        child: Container(
                                          height: 40,
                                          width: 40,
                                          decoration: BoxDecoration(
                                            color: Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.red.withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                
                                // Icon with animation
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    _isUserMuted 
                                      ? Icons.notifications_off_rounded
                                      : Icons.notifications_active_rounded,
                                    key: ValueKey<bool>(_isUserMuted),
                                    color: _isUserMuted ? Colors.red.shade300 : Colors.green.shade300,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Name and Status Container - Use duration based on initialization state
              AnimatedPositioned(
                duration: Duration(milliseconds: _isInitialized ? 500 : 0),
                curve: Curves.easeOutQuint,
                left: 0,
                right: 0,
                bottom: _currentPage > 0 ? bottomBarHeight : -nameContainerHeight,
                child: Container(
                  height: nameContainerHeight,
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.06,
                    vertical: screenHeight * 0.02,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentPage > 0 && friends.isNotEmpty)
                        Text(
                          friends[_currentPage - 1]['displayName'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      SizedBox(height: screenHeight * 0.003),
                    ],
                  ),
                ),
              ),

              // Curved Bottom Bar with animation - Use duration based on initialization state
              if (_currentPage > 0 && friends.isNotEmpty && friends[_currentPage - 1]['id'] != null)
                AnimatedPositioned(
                  duration: Duration(milliseconds: _isInitialized ? 500 : 0),
                  curve: Curves.easeOutQuint,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CurvedBottomBar(
                    currentFriend: friends[_currentPage - 1],
                    isMuted: _isUserMuted,
                    isMutedByFriend: _isMutedByFriend,
                    onButtonPressed: _startCall,
                    friendUid: friends[_currentPage - 1]['id'],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}