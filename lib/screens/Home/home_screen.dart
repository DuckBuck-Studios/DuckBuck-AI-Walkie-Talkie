import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../../widgets/animated_background.dart';
import 'friend_card.dart';
import '../../providers/user_provider.dart';
import '../../providers/friend_provider.dart'; 
import '../../widgets/status_animation_popup.dart';
import 'profile_screen.dart';
import 'friend_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _selectedFriendId;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize the page controller with viewportFraction to show exactly one card
    _pageController = PageController(
      viewportFraction: 1.0,
      initialPage: 0,
    );
    
    // Add listener to track current page for animations
    _pageController.addListener(() {
      if (_pageController.page != null) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
    
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
    // Dispose page controller
    _pageController.dispose();
    
    // Unregister observer
    WidgetsBinding.instance.removeObserver(this);
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
                
                // Friends List
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
                                size: 64,
                                color: Colors.brown.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No friends yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.brown.shade300,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add friends to start chatting!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ).animate()
                          .fadeIn(duration: 300.ms)
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.0, 1.0),
                            duration: 300.ms,
                            curve: Curves.easeOutCubic,
                          );
                      }

                      return PageView.builder(
                        itemCount: friends.length,
                        controller: _pageController,
                        pageSnapping: true,
                        padEnds: false,
                        clipBehavior: Clip.none,
                        physics: const PageScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _selectedFriendId = friends[index]['id'];
                            _currentPage = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          // Calculate animation values based on page position
                          double page = _pageController.hasClients 
                              ? _pageController.page ?? index.toDouble()
                              : index.toDouble();
                          
                          // Calculate how far this page is from being fully visible
                          double pageDifference = (page - index).abs();
                          
                          // Animation calculations
                          double rotationValue = pageDifference * 0.5; // max rotation of 0.5 radians
                          double scaleValue = 1.0 - (pageDifference * 0.15); // scale between 0.85 and 1.0
                          double opacityValue = 1.0 - (pageDifference * 0.5); // opacity between 0.5 and 1.0
                          opacityValue = opacityValue.clamp(0.5, 1.0);
                          
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              // Debug the friend data
                              print("HomeScreen: Friend data for ${friends[index]['displayName']} - " +
                                    "isOnline: ${friends[index]['isOnline']}, " +
                                    "statusAnimation: ${friends[index]['statusAnimation']}, " +
                                    "privacySettings: ${friends[index]['privacySettings']}");
                              
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001) // perspective
                                  ..scale(scaleValue, scaleValue)
                                  ..rotateY(page > index ? rotationValue : -rotationValue),
                                child: Opacity(
                                  opacity: opacityValue,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 20),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: FriendCard(
                                      friend: friends[index],
                                      isSelected: friends[index]['id'] == _selectedFriendId,
                                      onTap: () {
                                        setState(() {
                                          _selectedFriendId = friends[index]['id'];
                                        });
                                        
                                        // Animate to the selected page
                                        _pageController.animateToPage(
                                          index,
                                          duration: const Duration(milliseconds: 400),
                                          curve: Curves.easeOutCubic,
                                        );
                                      },
                                    ).animate()
                                      .fadeIn(duration: 300.ms)
                                      .scale(
                                        begin: const Offset(0.95, 0.95),
                                        end: const Offset(1.0, 1.0),
                                        duration: 400.ms, 
                                        curve: Curves.easeOutCubic
                                      ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
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
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _navigateToFriendScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          const FriendScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Create a smooth sliding animation from right to left
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutQuint;
          
          var tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));
            
          var offsetAnimation = animation.drive(tween);
          
          // Add a fade animation
          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            ),
          );
          
          // Combine slide and fade animations
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // Helper method to handle friend tap
  void _handleFriendTap(Map<String, dynamic> friend) {
    setState(() {
      _selectedFriendId = friend['id'];
    });
    
    // Find the index of the tapped friend
    final index = _pageController.hasClients 
        ? Provider.of<FriendProvider>(context, listen: false)
            .friends.indexWhere((f) => f['id'] == friend['id'])
        : -1;
    
    // If found, animate to that page
    if (index >= 0) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    // TODO: Handle friend selection (e.g., start chat)
  }
}

// Add this class at the bottom of the file
class CustomScrollPhysics extends ScrollPhysics {
  const CustomScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Makes the scrolling more resistant for better control
    return offset * 0.85;
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1.0,
      );
}