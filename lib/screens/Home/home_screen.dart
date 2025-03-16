import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'profile_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize FriendProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userModel != null) {
        final friendProvider = Provider.of<FriendProvider>(context, listen: false);
        friendProvider.initializeFriendStreams(authProvider.userModel!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: Stack(
          children: [
            // Profile Photo in top left corner - with tap to go to profile
            Positioned(
              top: 40,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  // Navigate to the profile screen with a nice hero animation
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
                },
                child: Hero(
                  tag: 'profile-photo',
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4A76A).withOpacity(0.2),
                      border: Border.all(
                        color: const Color(0xFFD4A76A),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: userModel?.photoURL != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.network(
                              userModel!.photoURL!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Color(0xFFD4A76A),
                                );
                              },
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 30,
                            color: Color(0xFFD4A76A),
                          ),
                  ),
                ),
              ),
            ),
            
            // App Title in the center
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'DuckBuck',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade800,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.3, end: 0),
                  
                  const SizedBox(height: 10),
                  
                  Text(
                    'Welcome back, ${userModel?.displayName ?? 'User'}!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.brown.shade600,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 400.ms).slideY(begin: 0.3, end: 0),
                ],
              ),
            ),
            
            // Friends button at the bottom
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: DuckBuckButtonStyles.primary(
                  text: 'Friends',
                  onTap: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const FriendsScreen(),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people, color: Colors.white),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideY(begin: 0.3, end: 0),
            ),
            
            // Sign Out button at top right
            Positioned(
              top: 40,
              right: 20,
              child: InkWell(
                onTap: () => authProvider.signOut(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.brown.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.brown,
                  ),
                ),
              ).animate().fadeIn(duration: 600.ms, delay: 700.ms),
            ),
          ],
        ),
      ),
    );
  }
} 