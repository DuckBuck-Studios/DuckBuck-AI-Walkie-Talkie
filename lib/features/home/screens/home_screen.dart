import 'package:flutter/material.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/navigation/app_routes.dart';
import 'package:duckbuck/core/repositories/user_repository.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get services from service locator
      final userRepository = serviceLocator<UserRepository>();
      final analyticsService = serviceLocator<FirebaseAnalyticsService>();
      
      // Log analytics event before signing out
      await analyticsService.logEvent(
        name: 'user_logout',
        parameters: {'timestamp': DateTime.now().toIso8601String()},
      );

      // Perform logout - FCM token clearing happens inside the UserRepository.signOut() method
      debugPrint('🔥 HOME: Calling central signOut method in UserRepository');
      await userRepository.signOut();
      
      // No need to clear preferences here as it's already done in UserRepository.signOut()

      debugPrint('Logout completed successfully, all auth state cleared');

      // Navigate to welcome/login screen
      if (mounted) {
        // Use pushNamedAndRemoveUntil to clear the navigation stack
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.welcome,
          (route) => false, // This removes all previous routes
        );
      }
    } catch (e) {
      // Show error if logout fails
      debugPrint('Logout failed: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent back button navigation
      canPop: false,
      child: Scaffold(
        // Remove back button and disable automatic back button
        appBar: AppBar(
          title: const Text('DuckBuck'),
          elevation: 2,
          automaticallyImplyLeading: false, // This removes the back button
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Welcome to DuckBuck!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                // Logout button
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
