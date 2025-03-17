import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/animated_background.dart';
import '../../providers/user_provider.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the user provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).initialize();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final user = userProvider.currentUser;
            
            return Stack(
              children: [
                // Profile Photo in top left corner
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: MediaQuery.of(context).padding.left + 20,
                  child: GestureDetector(
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
                ),
                
                // Center text
                Center(
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
                  .moveY(begin: 20, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
              ],
            );
          },
        ),
      ),
    );
  }
}