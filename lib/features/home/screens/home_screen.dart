import 'package:flutter/material.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/navigation/app_routes.dart';
import 'package:duckbuck/core/repositories/user_repository.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';
// Track session metrics
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  // Analytics service
  late final FirebaseAnalyticsService _analyticsService;
  
  // Session tracking variables
  DateTime _sessionStartTime = DateTime.now();
  Timer? _sessionHeartbeatTimer;
  int _sessionInteractions = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Register didChangeAppLifecycleState observer
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize analytics service
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();
    
    // Log screen view with enhanced parameters
    _analyticsService.logScreenView(
      screenName: 'home_screen',
      screenClass: 'HomeScreen',
    );
    
    // Log event for successful authentication flow completion
    _analyticsService.logEvent(
      name: 'auth_flow_complete',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
        'screen': 'home_screen',
        'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
      },
    );
    
    // Start session heartbeat timer (every 30 seconds)
    _sessionHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _logSessionHeartbeat();
    });
  }
  
  @override
  void dispose() {
    // Cancel timer and remove observer
    _sessionHeartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    // Log session end event
    _logSessionEnd(reason: 'screen_disposed');
    
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Track app lifecycle state changes
    if (state == AppLifecycleState.paused) {
      // App went to background
      _logSessionEnd(reason: 'app_backgrounded');
    } else if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _sessionStartTime = DateTime.now();
      _analyticsService.logEvent(
        name: 'home_session_resumed',
        parameters: {
          'timestamp': _sessionStartTime.toIso8601String(),
          'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
        },
      );
    }
  }
  
  // Log session heartbeat to track active session duration
  void _logSessionHeartbeat() {
    final duration = DateTime.now().difference(_sessionStartTime);
    _analyticsService.logEvent(
      name: 'home_session_heartbeat',
      parameters: {
        'session_duration_seconds': duration.inSeconds.toString(),
        'interactions_count': _sessionInteractions.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
      },
    );
  }
  
  // Log session end with reason
  void _logSessionEnd({required String reason}) {
    final duration = DateTime.now().difference(_sessionStartTime);
    _analyticsService.logEvent(
      name: 'home_session_end',
      parameters: {
        'session_duration_seconds': duration.inSeconds.toString(),
        'end_reason': reason,
        'interactions_count': _sessionInteractions.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
      },
    );
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    // Track interaction
    _sessionInteractions++;
    
    // Get session duration before logout
    final sessionDuration = DateTime.now().difference(_sessionStartTime);
    
    try {
      // Get services from service locator
      final userRepository = serviceLocator<UserRepository>();
      
      // Log enhanced logout analytics event
      await _analyticsService.logEvent(
        name: 'user_logout',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
          'session_duration_seconds': sessionDuration.inSeconds.toString(),
          'interactions_before_logout': _sessionInteractions.toString(),
        },
      );

      // Perform logout - FCM token clearing happens inside the UserRepository.signOut() method
      debugPrint('🔥 HOME: Calling central signOut method in UserRepository');
      await userRepository.signOut();
      
      // No need to clear preferences here as it's already done in UserRepository.signOut()

      debugPrint('Logout completed successfully, all auth state cleared');
      
      // Log successful logout completion
      await _analyticsService.logEvent(
        name: 'user_logout_success',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
        },
      );

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
      
      // Log logout failure with error details
      await _analyticsService.logEvent(
        name: 'user_logout_failed',
        parameters: {
          'timestamp': DateTime.now().toIso8601String(),
          'error': e.toString(),
          'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
        },
      );
      
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

  // Handle a demo interaction for analytics tracking
  void _handleDemoInteraction() {
    // Increment interaction counter
    setState(() {
      _sessionInteractions++;
    });
    
    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo interaction recorded')),
    );
    
    // Log interaction in analytics
    _analyticsService.logEvent(
      name: 'demo_interaction',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
        'interaction_number': _sessionInteractions.toString(),
      },
    );
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

                // Interaction buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Demo interaction button 
                    ElevatedButton.icon(
                      onPressed: _handleDemoInteraction,
                      icon: const Icon(Icons.touch_app),
                      label: const Text('Demo Button'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Logout button
                    _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
