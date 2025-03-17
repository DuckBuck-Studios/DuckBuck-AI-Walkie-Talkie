import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/animated_background.dart';
import '../../providers/user_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/cool_button.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _friendsPageController = PageController();
  int _currentFriendIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the user provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).initialize();
      
      // Initialize friend streams
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.uid != null) {
        Provider.of<FriendProvider>(context, listen: false).initializeFriendStreams(userProvider.uid!);
      }
    });
  }

  @override
  void dispose() {
    _friendsPageController.dispose();
    super.dispose();
  }

  void _navigateToProfile() {
    print("Navigating to profile");
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
  
  void _navigateToFriends() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FriendsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: Consumer2<UserProvider, FriendProvider>(
            builder: (context, userProvider, friendProvider, child) {
              final user = userProvider.currentUser;
              final friends = friendProvider.friends;
              
              // Debug print
              print('HomeScreen build: Found ${friends.length} friends');
              
              return Column(
                children: [
                  // Top Bar with Profile Icon
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Profile Photo Button
                        GestureDetector(
                          onTap: _navigateToProfile,
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
                                child: user?.photoURL != null
                                    ? Image.network(
                                        user!.photoURL!,
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
                          ),
                        
                        // App Name or Title
                        Text(
                          "DuckBuck",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade800,
                          ),
                        ),
                        
                        // Empty Container for balance
                        SizedBox(width: 50),
                      ],
                    ),
                  ),
                  
                  // Main Content
                  Expanded(
                    child: friends.isEmpty
                        ? _buildEmptyState()
                        : _buildFriendsView(friends),
                  ),
                  
                  // Bottom Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: DuckBuckButton(
                      text: friends.isEmpty ? 'Add Friends' : 'Friends',
                      onTap: _navigateToFriends,
                      icon: const Icon(Icons.people, color: Colors.white),
                      color: const Color(0xFF4A1C03),
                      borderColor: const Color(0xFF2D1102),
                      textColor: Colors.white,
                    ),
                  ).animate()
                    .fadeIn(duration: 600.ms, delay: 600.ms)
                    .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Add friends to start talking',
        style: TextStyle(
          fontSize: 18,
          color: Colors.brown.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: 200.ms)
      .moveY(begin: 20, end: 0, duration: 500.ms, curve: Curves.easeOutQuad);
  }
  
  Widget _buildFriendsView(List<Map<String, dynamic>> friends) {
    return Column(
      children: [
        // Friends Carousel
        Expanded(
          child: PageView.builder(
            controller: _friendsPageController,
            itemCount: friends.length,
            onPageChanged: (index) {
              setState(() {
                _currentFriendIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final friend = friends[index];
              print('Building card for friend: ${friend['displayName'] ?? 'Unknown'}');
              return Center(
                child: _buildFriendCard(friend),
              );
            },
          ),
        ),
        
        // Page Indicator Dots
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              friends.length,
              (index) => Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentFriendIndex == index
                      ? const Color(0xFF4A1C03)
                      : const Color(0xFF4A1C03).withOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final String name = friend['displayName'] ?? friend['name'] ?? 'Friend';
    
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade800.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
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
              child: friend['photoURL'] != null && friend['photoURL'].toString().isNotEmpty
                ? Image.network(
                    friend['photoURL'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.brown.shade100,
                        child: Center(
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.brown.shade800,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.brown.shade100,
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
            ),
            
            // Gradient overlay for better text visibility
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
            
            // Friend name and info
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Friend name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Online status indicator
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: friend['isOnline'] == true ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        friend['isOnline'] == true ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  Text(
                    'Swipe to see more friends',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn()
      .scale(
        begin: const Offset(0.9, 0.9),
        duration: 500.ms,
        curve: Curves.easeOutBack,
      );
  }
}