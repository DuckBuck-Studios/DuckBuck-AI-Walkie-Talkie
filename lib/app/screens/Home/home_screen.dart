import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; 
import 'package:cached_network_image/cached_network_image.dart';  
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
  // Cache the NavigationCard for access to menu options
  late final NavigationCard _navigationCard;
  // Track if we've loaded friends data
  bool _hasFriends = false;

  @override
  void initState() {
    super.initState();
    debugPrint('HomeScreen: Initializing');
    
    // Initialize animation controllers
    _muteAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimationController.repeat(reverse: true);
    
    // Create cached navigation card
    _navigationCard = NavigationCard(
      onNavigateToProfile: _navigateToProfile,
      onNavigateToFriends: _navigateToFriends,
      onNavigateToSettings: _navigateToSettings,
      onShowQRCode: (ctx) {
        HapticFeedback.selectionClick();
        _qrCodeScreen.showQRCode(ctx);
      },
    );
    
    // Do synchronous initialization right away to prevent flash
    _initializeSync();
    
    // Then do async initialization
    _initializeAsync();
  }
  
  // Do synchronous initialization first to prevent UI flash
  void _initializeSync() {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final friends = friendProvider.friends;
    
    _hasFriends = friends.isNotEmpty;
    
    if (_hasFriends) {
      // Set the first friend as selected immediately
      _selectedFriend = friends[0];
      _currentPage = 0; // Start at index 0 (first friend) since navigation card will be at the end
      
      // Initialize with correct initial page
      _pageController = PageController(initialPage: 0, keepPage: true);
    } else {
      // No friends yet, just initialize controller
      _pageController = PageController(keepPage: true);
    }
  }
  
  // Continue with async initialization afterwards
  Future<void> _initializeAsync() async {
    try {
      // Initialize FriendProvider
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      
      // Use Future.microtask to schedule the initialization for after the current build phase
      Future.microtask(() async {
        // Only initialize if not already initialized
        if (!friendProvider.isInitialized) {
          await friendProvider.initialize();
          
          // Update friends status after initialization
          if (mounted) {
            setState(() {
              _hasFriends = friendProvider.friends.isNotEmpty;
              if (_hasFriends && _selectedFriend == null) {
                _selectedFriend = friendProvider.friends[0];
              }
            });
          }
        }
        
        // Set up call invitation listener
        _listenForCallInvitations();
        
        // Set up mute status listener for the selected friend
        if (_selectedFriend != null) {
          _setupMuteStatusListener();
        }
        
        // Mark initialization as complete
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('HomeScreen: Error during initialization: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    
    // Set up mute status listener for the selected friend
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
          // Show loading indicator only for initial load
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          final friends = friendProvider.friends;
          final hasFriends = friends.isNotEmpty;
          
          // Update _hasFriends if it's changed
          if (hasFriends != _hasFriends) {
            _hasFriends = hasFriends;
            if (hasFriends && _selectedFriend == null) {
              _selectedFriend = friends[0];
            }
          }
          
          // If no friends, show the NavigationCard with add button
          if (!hasFriends) {
            return Stack(
              children: [
                _navigationCard,
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.white, size: 32),
                    onPressed: _navigateToFriends,
                    tooltip: 'Add Friends',
                  ),
                ),
              ],
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // PageView for swiping through friends (with NavigationCard)
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  // Only perform haptic feedback if fully initialized
                  if (_isInitialized) {
                    HapticFeedback.selectionClick();
                  }
                  
                  setState(() {
                    _currentPage = index;
                    _selectedFriend = index == friends.length ? null : friends[index];
                  });
                  
                  // Check mute status when changing pages
                  if (_selectedFriend != null) {
                    _setupMuteStatusListener();
                  }
                },
                physics: const BouncingScrollPhysics(),
                itemCount: friends.length + 1,
                itemBuilder: (context, index) {
                  if (index == friends.length) {
                    return _navigationCard;
                  }
                  
                  final friend = friends[index];
                  
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
              if (_currentPage < friends.length && _selectedFriend != null)
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

              // Name and Status Container
              AnimatedPositioned(
                duration: Duration(milliseconds: _isInitialized ? 500 : 0),
                curve: Curves.easeOutQuint,
                left: 0,
                right: 0,
                bottom: _currentPage < friends.length ? bottomBarHeight : -nameContainerHeight,
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
                      if (_currentPage < friends.length && friends.isNotEmpty)
                        Text(
                          friends[_currentPage]['displayName'] ?? 'Unknown User',
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

              // Curved Bottom Bar with animation
              if (_currentPage < friends.length && friends.isNotEmpty && friends[_currentPage]['id'] != null)
                AnimatedPositioned(
                  duration: Duration(milliseconds: _isInitialized ? 500 : 0),
                  curve: Curves.easeOutQuint,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CurvedBottomBar(
                    currentFriend: friends[_currentPage],
                    isMuted: _isUserMuted,
                    isMutedByFriend: _isMutedByFriend,
                    onButtonPressed: _startCall,
                    friendUid: friends[_currentPage]['id'],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}