import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/animated_background.dart';
import '../../providers/user_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/friend_card.dart';
import '../../widgets/status_animation_popup.dart';
import 'profile_screen.dart';
import 'friend_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _friendsPageController = PageController();
  
  @override
  void initState() {
    super.initState();
    // Initialize the user provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print("HomeScreen: Starting initialization sequence");
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Wait for user provider to initialize
      await userProvider.initialize();
      print("HomeScreen: UserProvider initialization completed");
      
      // Set user status as online - only after initialization is complete
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
    _friendsPageController.dispose();
    super.dispose();
  }

  // Set user status as online
  void _setUserOnline() {
    print("HomeScreen: Setting user online status");
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Set user as online - the initialize method already handles this
    // We can use setStatusAnimation to ensure the status is active
    if (userProvider.uid != null) {
      print("HomeScreen: User ID found: ${userProvider.uid}, updating status animation");
      // Pass the current animation (which might be null)
      userProvider.setStatusAnimation(userProvider.statusAnimation);
    } else {
      print("HomeScreen: User ID is null, cannot set online status");
    }
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
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Profile Icon
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
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
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFD4A76A), width: 2),
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
                                borderRadius: BorderRadius.circular(25),
                                child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                    ? Image.network(
                                        user.photoURL!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.person, size: 30, color: Color(0xFFD4A76A));
                                        },
                                      )
                                    : const Icon(Icons.person, size: 30, color: Color(0xFFD4A76A)),
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
                    Text(
                      "DuckBuck",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                      ),
                    ).animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                    
                    // Empty Container for balance
                    const SizedBox(width: 50),
                  ],
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
                              // Staggered animation based on index
                              return Padding(
                                // Add padding to reduce the effective card size
                                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
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
              
              // Friends button at bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: GestureDetector(
                  onTap: _navigateToFriendScreen,
                  child: Container(
                    width: 200,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3C1F1F), // Dark chocolate
                          const Color(0xFF5C2F2F), // Lighter chocolate
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Manage Friends',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate()
                  .fadeIn(duration: 600.ms, delay: 400.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),
              ),
            ],
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