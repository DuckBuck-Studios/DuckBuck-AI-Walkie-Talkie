import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/providers/auth_provider.dart' as auth;
import '../../app/providers/user_provider.dart';
import '../Authentication/welcome_screen.dart';

class NavigationCard extends StatelessWidget {
  final VoidCallback onNavigateToProfile;
  final VoidCallback onNavigateToFriends;
  final VoidCallback onNavigateToSettings;
  final Function(BuildContext) onShowQRCode;

  const NavigationCard({
    super.key,
    required this.onNavigateToProfile,
    required this.onNavigateToFriends,
    required this.onNavigateToSettings,
    required this.onShowQRCode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black,
            Colors.black.withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.easeOutQuint,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A76A).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  "NAVIGATE",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 25),
                
                // Profile option
                _buildNavOption(
                  title: "Profile",
                  subtitle: "View your profile",
                  icon: Icons.person,
                  gradient: const [
                    Color(0xFF8E24AA),
                    Color(0xFF6A1B9A),
                  ],
                  onTap: onNavigateToProfile,
                  iconBuilder: (color) => Consumer<auth.AuthProvider>(
                    builder: (context, authProvider, child) {
                      return authProvider.userModel?.photoURL != null
                        ? Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: authProvider.userModel!.photoURL!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF6A1B9A).withOpacity(0.3),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF6A1B9A).withOpacity(0.3),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: const [
                                  Color(0xFF9C27B0),
                                  Color(0xFF6A1B9A),
                                ],
                              ),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            ),
                          );
                    },
                  ),
                ),
                
                const SizedBox(height: 15),
                
                // Friends option
                _buildNavOption(
                  title: "Friends",
                  subtitle: "Connect with your friends",
                  icon: Icons.people,
                  gradient: const [
                    Color(0xFF26A69A),
                    Color(0xFF00796B),
                  ],
                  onTap: onNavigateToFriends,
                ),
                
                const SizedBox(height: 15),
                
                // Settings option
                _buildNavOption(
                  title: "Settings",
                  subtitle: "Customize your app preferences",
                  icon: Icons.settings,
                  gradient: const [
                    Color(0xFFFF7043),
                    Color(0xFFE64A19),
                  ],
                  onTap: onNavigateToSettings,
                ),
                
                const SizedBox(height: 15),
                
                // QR Code option
                _buildNavOption(
                  title: "QR Code",
                  subtitle: "Share your profile with friends",
                  icon: Icons.qr_code,
                  gradient: const [
                    Color(0xFFFFD54F),
                    Color(0xFFFFA000),
                  ],
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onShowQRCode(context);
                  },
                ),
                
                const SizedBox(height: 15),
                
                // Sign Out option
                _buildNavOption(
                  title: "Sign Out",
                  subtitle: "Log out of your account",
                  icon: Icons.logout,
                  gradient: const [
                    Color(0xFFEF5350),
                    Color(0xFFD32F2F),
                  ],
                  onTap: () => _signOut(context),
                ),
                
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Handle sign out logic
  Future<void> _signOut(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4A76A)),
          ),
        ),
      );

      // Get the providers
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
      
      // Set user as offline and clear FCM token
      await userProvider.logout();
      
      // Sign out from Firebase Auth
      await authProvider.signOut();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Force navigation to welcome screen with logged out flag
      if (context.mounted) {
        // Clear the entire navigation stack and push welcome screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen(loggedOut: true)),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog if it's still showing
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildNavOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    Widget Function(Color iconColor)? iconBuilder,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: gradient[0].withOpacity(0.3),
          highlightColor: gradient[1].withOpacity(0.1),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: gradient[1].withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  // Icon or custom widget
                  iconBuilder != null 
                    ? iconBuilder(Colors.white)
                    : Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                  const SizedBox(width: 15),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate(
      delay: Duration(milliseconds: (title == "Profile" ? 100 : 
              title == "Friends" ? 200 : 
              title == "Settings" ? 300 : 
              title == "QR Code" ? 400 : 500)),
    ).slideX(
      begin: -0.2,
      end: 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutQuint,
    ).fadeIn(
      duration: const Duration(milliseconds: 400),
    );
  }
} 