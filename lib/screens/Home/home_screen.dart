import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';  
import 'dart:ui';
import 'dart:math' as math; 
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
                                  flightShuttleBuilder: (
                                    BuildContext flightContext,
                                    Animation<double> animation,
                                    HeroFlightDirection flightDirection,
                                    BuildContext fromHeroContext,
                                    BuildContext toHeroContext,
                                  ) {
                                    // Custom transition to handle size differences
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) {
                                        return Material(
                                          color: Colors.transparent,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFD4A76A),
                                                width: flightDirection == HeroFlightDirection.push 
                                                  ? lerpDouble(borderWidth, 3.0, animation.value) ?? borderWidth
                                                  : lerpDouble(3.0, borderWidth, animation.value) ?? 3.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFD4A76A).withOpacity(
                                                    flightDirection == HeroFlightDirection.push 
                                                      ? lerpDouble(0.1, 0.3, animation.value) ?? 0.1 
                                                      : lerpDouble(0.3, 0.1, animation.value) ?? 0.3,
                                                  ),
                                                  blurRadius: flightDirection == HeroFlightDirection.push 
                                                    ? lerpDouble(4, 15, animation.value) ?? 4 
                                                    : lerpDouble(15, 4, animation.value) ?? 15,
                                                  spreadRadius: flightDirection == HeroFlightDirection.push 
                                                    ? lerpDouble(1, 5, animation.value) ?? 1 
                                                    : lerpDouble(5, 1, animation.value) ?? 5,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(100.0),
                                              child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: user.photoURL!,
                                                    fit: BoxFit.cover,
                                                    placeholder: (context, url) => Container(
                                                      color: Colors.brown.shade100,
                                                      child: const Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Color(0xFF8B4513),
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => Icon(
                                                      Icons.person, 
                                                      size: 40, 
                                                      color: const Color(0xFFD4A76A),
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person, 
                                                    size: 40, 
                                                    color: const Color(0xFFD4A76A),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Material(
                                    color: Colors.transparent,
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
    // Use a fixed starting position instead of tap location
    // This avoids the tap ripple animation
    final screenSize = MediaQuery.of(context).size;
    final Offset centerOffset = Offset(screenSize.width * 0.1, screenSize.height * 0.1);
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(
          onBackPressed: (ctx) => Navigator.of(ctx).pop(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Value between 0.0 and 1.0
          final value = animation.value;
          
          // Determine which kind of animation to use
          // For forward transitions (going to profile)
          if (animation.status == AnimationStatus.forward || 
              animation.status == AnimationStatus.completed) {
            // We use a Stack with the liquid animation behind the child
            // This ensures the animation doesn't interfere with touch events
            return Stack(
              children: [
                // The liquid reveal animation
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SimplifiedLiquidPainter(
                      progress: value,
                      fillColor: const Color(0xFFF5E8C7),
                      centerOffset: centerOffset,
                    ),
                  ),
                ),
                // Fade in the actual screen content
                Opacity(
                  opacity: value,
                  child: child,
                ),
              ],
            );
          } 
          // For reverse transitions (going back to home)
          else {
            return Stack(
              children: [
                // The home screen background (already visible underneath)
                
                // Profile screen that gets a circular hole cut out of it to reveal home
                // The hole expands as animation progresses
                ClipPath(
                  clipper: _HoleClipper(
                    progress: 1.0 - value, // Inverted progress for growing hole
                    centerOffset: centerOffset,
                  ),
                  child: child, // Profile screen
                ),
                
                // Wave effects around the hole edge
                if (value > 0.1 && value < 0.9)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _HoleEdgeEffectPainter(
                        progress: 1.0 - value, // Inverted progress for growing hole
                        color: const Color(0xFFD4A76A).withOpacity(0.3),
                        centerOffset: centerOffset,
                      ),
                    ),
                  ),
              ],
            );
          }
        },
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _navigateToFriendScreen() {
    // Use a fixed starting position instead of tap location
    // This avoids the tap ripple animation
    final screenSize = MediaQuery.of(context).size;
    final Offset centerOffset = Offset(screenSize.width * 0.9, screenSize.height * 0.1);
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          FriendScreen(
            onBackPressed: (ctx) => Navigator.of(ctx).pop(),
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Value between 0.0 and 1.0
          final value = animation.value;
          
          // For forward transitions (going to friends)
          if (animation.status == AnimationStatus.forward || 
              animation.status == AnimationStatus.completed) {
            return Stack(
              children: [
                // The liquid reveal animation
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SimplifiedLiquidPainter(
                      progress: value,
                      fillColor: const Color(0xFFF5E8C7),
                      centerOffset: centerOffset,
                    ),
                  ),
                ),
                // Fade in the actual screen content
                Opacity(
                  opacity: value,
                  child: child,
                ),
              ],
            );
          } 
          // For reverse transitions (going back to home)
          else {
            return Stack(
              children: [
                // The home screen background (already visible underneath)
                
                // Friend screen with circular hole
                ClipPath(
                  clipper: _HoleClipper(
                    progress: 1.0 - value, // Inverted progress for growing hole
                    centerOffset: centerOffset,
                  ),
                  child: child, // Friend screen
                ),
                
                // Wave effects around the hole edge
                if (value > 0.1 && value < 0.9)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _HoleEdgeEffectPainter(
                        progress: 1.0 - value, // Inverted progress for growing hole
                        color: const Color(0xFFD4A76A).withOpacity(0.3),
                        centerOffset: centerOffset,
                      ),
                    ),
                  ),
              ],
            );
          }
        },
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 600),
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

// Custom painter for liquid reveal effect
// ignore: unused_element
class _LiquidRevealPainter extends CustomPainter {
  final double animationValue;
  final Color fillColor;
  final Offset centerOffset;

  _LiquidRevealPainter({
    required this.animationValue,
    required this.fillColor,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the maximum radius needed to cover the screen
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    
    // Create a paint for the liquid effect
    final paint = Paint()
      ..color = fillColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    
    // Create a circular path that grows with the animation
    final path = Path();
    
    // Draw the main circle with radius that shrinks as animation progresses
    // This creates the effect of revealing the profile screen
    final radius = maxRadius * (1.0 - animationValue);
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Fill the entire screen except for the circular hole
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    path.fillType = PathFillType.evenOdd;
    
    // Draw the path
    canvas.drawPath(path, paint);
    
    // Add wave effects for a more organic feel
    if (animationValue > 0.2 && animationValue < 0.9) {
      final waveProgress = (animationValue - 0.2) / 0.7; // Normalize to 0-1 range
      final wavePath = Path();
      
      // Create wave parameters
      final waveRadius = radius + 20 * math.sin(waveProgress * math.pi);
      final waveOpacity = 0.3 * (1.0 - waveProgress); // Fade out as animation completes
      
      // Create more dynamic wave with multiple segments
      wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
      
      // Create a semi-transparent paint for wave effect
      final wavePaint = Paint()
        ..color = fillColor.withOpacity(waveOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0;
      
      canvas.drawPath(wavePath, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_LiquidRevealPainter oldDelegate) => 
    animationValue != oldDelegate.animationValue;
}

// Custom painter for reverse animation (going back from profile to home)
class _LiquidCollapseTransition extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Offset centerOffset;

  _LiquidCollapseTransition({
    required this.progress,
    required this.fillColor,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the maximum radius needed to cover the screen
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    
    // Create a paint for the liquid effect
    final paint = Paint()
      ..color = fillColor.withOpacity(1.0 - progress)
      ..style = PaintingStyle.fill;
    
    // Calculate radius that grows as we return to HomeScreen
    final radius = maxRadius * progress;
    
    // Create a circular path
    final path = Path();
    
    // Create a hole in the screen that grows as animation progresses
    // This reveals the HomeScreen underneath
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Fill only the hole using evenOdd rule
    canvas.drawPath(path, paint);
    
    // Add wave effects for a more organic feel
    if (progress > 0.1 && progress < 0.9) {
      final waveProgress = (progress - 0.1) / 0.8; // Normalize to 0-1 range
      
      // Create wave with ripple effect
      final wavePath = Path();
      final waveRadius = radius - 15 * math.sin(waveProgress * math.pi * 2);
      
      wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
      
      final wavePaint = Paint()
        ..color = fillColor.withOpacity(0.3 * (1.0 - waveProgress))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;
      
      canvas.drawPath(wavePath, wavePaint);
      
      // Add second wave for more dynamic effect
      if (progress > 0.3) {
        final wave2Path = Path();
        final wave2Radius = radius - 30 * math.cos(waveProgress * math.pi);
        
        wave2Path.addOval(Rect.fromCircle(center: centerOffset, radius: wave2Radius));
        
        final wave2Paint = Paint()
          ..color = fillColor.withOpacity(0.2 * (1.0 - waveProgress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        
        canvas.drawPath(wave2Path, wave2Paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LiquidCollapseTransition oldDelegate) => 
    progress != oldDelegate.progress;
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

// Clipper that reveals content through the liquid shape
class _LiquidClipper extends CustomClipper<Path> {
  final double animationValue;
  final Offset centerOffset;

  _LiquidClipper({
    required this.animationValue,
    required this.centerOffset,
  });

  @override
  Path getClip(Size size) {
    // Create a circular path that grows with the animation
    final path = Path();
    final radius = size.width * animationValue * 1.5;
    
    // Draw the circular path
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Add wave effects if animation is in progress
    if (animationValue > 0.2 && animationValue < 0.8) {
      final waveHeight = size.height * 0.05 * math.sin(animationValue * math.pi);
      final wavePath = Path();
      
      wavePath.moveTo(0, size.height * 0.5 + waveHeight);
      
      for (int i = 0; i < 5; i++) {
        final x1 = size.width * (i / 5);
        final x2 = size.width * ((i + 1) / 5);
        final y = size.height * 0.5 + waveHeight * math.sin((animationValue + i) * math.pi);
        
        wavePath.quadraticBezierTo(
          (x1 + x2) / 2, 
          size.height * 0.5 - waveHeight,
          x2,
          y
        );
      }
      
      wavePath.lineTo(size.width, size.height);
      wavePath.lineTo(0, size.height);
      wavePath.close();
      
      // Combine the paths
      path.addPath(wavePath, Offset.zero);
    }
    
    return path;
  }

  @override
  bool shouldReclip(_LiquidClipper oldClipper) => 
    animationValue != oldClipper.animationValue;
}

// Clipper for the reverse animation
class _LiquidReverseClipper extends CustomClipper<Path> {
  final double progress;
  final Offset centerOffset;

  _LiquidReverseClipper({
    required this.progress,
    required this.centerOffset,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Create the inverse of the collapse circle
    final radius = size.width * (1.5 * (1.0 - progress));
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Add wave effects for more interesting transition
    if (progress > 0.2 && progress < 0.8) {
      final waveHeight = size.height * 0.08 * math.sin((1.0 - progress) * math.pi);
      final wavePath = Path();
      
      wavePath.moveTo(0, size.height * 0.6);
      
      for (int i = 0; i < 8; i++) {
        final x1 = size.width * (i / 8);
        final x2 = size.width * ((i + 1) / 8);
        final phase = i / 3 * math.pi;
        final y = size.height * 0.6 + waveHeight * math.sin((1.0 - progress) * math.pi * 2 + phase);
        
        wavePath.quadraticBezierTo(
          (x1 + x2) / 2, 
          size.height * 0.6 - waveHeight * math.cos((1.0 - progress) * math.pi * 3 + phase),
          x2,
          y
        );
      }
      
      wavePath.lineTo(size.width, size.height);
      wavePath.lineTo(0, size.height);
      wavePath.close();
      
      // Combine the paths
      path.addPath(wavePath, Offset.zero);
    }
    
    return path;
  }

  @override
  bool shouldReclip(_LiquidReverseClipper oldClipper) => 
    progress != oldClipper.progress;
}

// Simplified clipper that creates a single clear liquid reveal effect
class _SingleLiquidClipper extends CustomClipper<Path> {
  final double progress;
  final Offset centerOffset;

  _SingleLiquidClipper({
    required this.progress,
    required this.centerOffset,
  });

  @override
  Path getClip(Size size) {
    // Create a path for the entire screen
    final path = Path();
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Calculate the radius based on progress
    // Make it large enough to cover the diagonal of the screen
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;
    
    // Create the circular path
    final circlePath = Path();
    circlePath.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Use the circular path as the clip area
    return circlePath;
  }

  @override
  bool shouldReclip(_SingleLiquidClipper oldClipper) => 
    progress != oldClipper.progress;
}

// Simplified liquid border painter just for the edge effect
class _LiquidBorderPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Offset centerOffset;

  _LiquidBorderPainter({
    required this.progress,
    required this.fillColor,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;
    
    // Create wave effect with stroke only
    final wavePaint = Paint()
      ..color = fillColor.withOpacity(0.7 * (1.0 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    
    final wavePath = Path();
    wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: radius + 3 * math.sin(progress * math.pi * 2)));
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(_LiquidBorderPainter oldDelegate) => 
    progress != oldDelegate.progress;
}

// Add this simplified liquid painter at the end of the file
class _SimplifiedLiquidPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Offset centerOffset;

  _SimplifiedLiquidPainter({
    required this.progress,
    required this.fillColor,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the maximum radius needed to cover the screen
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    
    // Create a paint for the background color
    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    
    // Calculate the growing radius based on the animation progress
    final radius = maxRadius * progress;
    
    // Create a circular path
    final path = Path()
      ..addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Fill the circle
    canvas.drawPath(path, paint);
    
    // Add a subtle wave effect around the edge
    if (progress > 0.1 && progress < 0.9) {
      final waveProgress = progress;
      final wavePaint = Paint()
        ..color = fillColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;
      
      // Create wave path with subtle animation
      final wavePath = Path();
      final waveRadius = radius + 15 * math.sin(waveProgress * math.pi * 2);
      wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
      
      // Draw the wave effect
      canvas.drawPath(wavePath, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_SimplifiedLiquidPainter oldDelegate) => progress != oldDelegate.progress;
}

// Replace the existing _CircleRevealClipper with this improved version
class _CircularRevealClipper extends CustomClipper<Path> {
  final Offset centerOffset;
  final double fraction;

  _CircularRevealClipper({
    required this.centerOffset,
    required this.fraction,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * fraction;
    
    // Create a circular path
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    return path;
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.centerOffset != centerOffset;
  }
}

// Add a wave effect painter for additional visual appeal
class _WaveEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Offset centerOffset;

  _WaveEffectPainter({
    required this.progress,
    required this.color,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15.0;
    
    // Main wave
    final wavePath = Path();
    final waveRadius = radius + 10 * math.sin(progress * math.pi * 2);
    wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
    canvas.drawPath(wavePath, paint);
    
    // Secondary wave for more depth
    if (progress > 0.2) {
      final secondaryPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;
      
      final secondaryPath = Path();
      final secondaryRadius = radius + 25 * math.sin(progress * math.pi * 1.5);
      secondaryPath.addOval(Rect.fromCircle(center: centerOffset, radius: secondaryRadius));
      canvas.drawPath(secondaryPath, secondaryPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveEffectPainter oldDelegate) => 
    progress != oldDelegate.progress;
}

// Add this clipper to create a hole that grows
class _HoleClipper extends CustomClipper<Path> {
  final double progress;
  final Offset centerOffset;

  _HoleClipper({
    required this.progress,
    required this.centerOffset,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;
    
    // Start with entire screen
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Cut out circle
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Use evenOdd to make the circle a hole
    path.fillType = PathFillType.evenOdd;
    
    return path;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) => 
    progress != oldClipper.progress || centerOffset != oldClipper.centerOffset;
}

// Adds wave effects around the edge of the hole
class _HoleEdgeEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Offset centerOffset;

  _HoleEdgeEffectPainter({
    required this.progress,
    required this.color,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final baseRadius = maxRadius * progress;
    
    // Primary wave
    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    
    final wavePath = Path();
    final waveRadius = baseRadius + 12 * math.sin(progress * math.pi * 2);
    wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
    canvas.drawPath(wavePath, wavePaint);
    
    // Secondary wave (more subtle)
    if (progress > 0.3) {
      final wave2Paint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      
      final wave2Path = Path();
      final wave2Radius = baseRadius + 24 * math.sin(progress * math.pi * 1.5);
      wave2Path.addOval(Rect.fromCircle(center: centerOffset, radius: wave2Radius));
      canvas.drawPath(wave2Path, wave2Paint);
    }
  }

  @override
  bool shouldRepaint(_HoleEdgeEffectPainter oldDelegate) => 
    progress != oldDelegate.progress;
}