import 'package:duckbuck/app/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import 'package:flutter/foundation.dart' show kDebugMode; 
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'app/providers/auth_provider.dart'; 
import 'app/providers/friend_provider.dart';
import 'screens/Authentication/welcome_screen.dart';
import 'screens/onboarding/name_screen.dart';
import 'screens/onboarding/dob_screen.dart';
import 'screens/onboarding/gender_screen.dart';
import 'screens/onboarding/profile_photo_screen.dart';
import 'screens/Home/home_screen.dart'; 
import 'app/widgets/animated_background.dart';
import 'app/services/friend_service.dart';
import 'app/config/app_config.dart';
import 'screens/Home/setting/settings_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/providers/call_provider.dart';
import 'app/services/fcm_receiver_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background notifications
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Call our handler
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  // Keep native splash screen up until app is fully loaded
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize FCM with background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize the FCM receiver service
  final fcmService = FCMReceiverService();
  await fcmService.initialize();
  
  // Initialize the CallProvider
  final callProvider = CallProvider();
  await callProvider.initialize();
  
  // Initialize app configuration
  final appConfig = AppConfig();
  await appConfig.initialize(
    // Set to production for release builds
    env: kDebugMode ? Environment.development : Environment.production,
  );
  
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => FriendProvider(FriendService())),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider<CallProvider>.value(value: callProvider),
    ],
    child: const MyApp(),
  ));
}

/// Main app widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver { 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  } 

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Get call provider without listening to changes
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // Handle app lifecycle state changes
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and interactive (foreground)
        debugPrint('App resumed - Call state: ${callProvider.callState}');
        break;
      case AppLifecycleState.inactive:
        // App is in an inactive state (transitioning between states)
        debugPrint('App inactive - Call state: ${callProvider.callState}');
        break;
      case AppLifecycleState.paused:
        // App is not visible (background)
        debugPrint('App paused - Call state: ${callProvider.callState}');
        // If there's an active call, make sure the background service is running
        if (callProvider.callState == CallState.connected) {
          debugPrint('App paused with active call - ensuring background service is running');
        }
        break;
      case AppLifecycleState.detached:
        // App is detached from the UI (though this callback may not be called in this state)
        debugPrint('App detached - Call state: ${callProvider.callState}');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DuckBuck',
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        primarySwatch: Colors.brown,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.brown,
          brightness: Brightness.light,
        ),
      ),
      home: const AuthenticationWrapper(),
    );
  }
}

/// A wrapper widget that redirects to the appropriate screen
/// based on authentication state
class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  // Add a flag to track if we're still initializing
  bool _isInitializing = true;
  final AppConfig _appConfig = AppConfig();
  
  @override
  void initState() {
    super.initState();
    // Check auth state asynchronously
    _checkAuthState();
  }
  
  // Check auth state asynchronously
  Future<void> _checkAuthState() async {
    try {
      // Get the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Wait for the auth provider to initialize
      if (authProvider.status == AuthStatus.loading) {
        // Wait until status changes from loading
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return authProvider.status == AuthStatus.loading;
        });
      }
      
      // Allow extra time for Firebase to connect and UI to prepare
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        
        // Only remove the native splash screen once app is fully ready
        FlutterNativeSplash.remove();
      }
    } catch (e) {
      // In case of error, still remove splash after timeout
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        FlutterNativeSplash.remove();
      }
    }
  }

  Widget _buildLoadingScreen() {
    // Simply use the animated background without adding redundant logo
    // since the native splash already shows the logo
    return const DuckBuckAnimatedBackground(
      child: SizedBox.shrink(),  // Empty widget to avoid redundant logo
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always show splash screen during initialization
    if (_isInitializing) {
      return _buildLoadingScreen();
    }
    
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If still loading auth state, show splash screen
        if (authProvider.status == AuthStatus.loading) {
          return _buildLoadingScreen();
        }

        // If not authenticated, show welcome screen
        if (!authProvider.isAuthenticated) {
          _appConfig.log('User not authenticated, showing welcome screen');
          return const WelcomeScreen(accountDeleted: false, loggedOut: false).animate().fadeIn(
            duration: const Duration(milliseconds: 300),
          );
        }

        // Set user ID for crash reporting if authenticated
        if (authProvider.currentUser?.uid != null) {
          _setUserForCrashReporting(authProvider.currentUser?.uid);
        }

        // For authenticated users, check onboarding stage directly
        return FutureBuilder<OnboardingStage>(
          future: authProvider.getOnboardingStage(),
          builder: (context, stageSnapshot) {
            // If we're still loading the stage, show the splash screen
            if (stageSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }
            
            // Get the current stage
            final currentStage = stageSnapshot.data ?? OnboardingStage.name;
            _appConfig.log('Current onboarding stage: $currentStage');
            
            // If the user doesn't exist in the database (notStarted), show welcome screen
            if (currentStage == OnboardingStage.notStarted) {
              _appConfig.log('User not in database, showing welcome screen');
              // Sign out the user first
              authProvider.signOut();
              return const WelcomeScreen(accountDeleted: false, loggedOut: false).animate().fadeIn(
                duration: const Duration(milliseconds: 300),
              );
            }
            
            // Route to the appropriate screen based on onboarding stage
            Widget targetScreen;
            
            switch (currentStage) {
              case OnboardingStage.completed:
                targetScreen = const HomeScreen();
                break;
              case OnboardingStage.name:
                targetScreen = const NameScreen();
                break;
              case OnboardingStage.dateOfBirth:
                targetScreen = const DOBScreen();
                break;
              case OnboardingStage.gender:
                targetScreen = const GenderScreen();
                break;
              case OnboardingStage.profilePhoto:
                targetScreen = const ProfilePhotoScreen();
                break;
              default:
                targetScreen = const NameScreen();
            }
            
            // Animate the transition to the target screen
            return targetScreen.animate().fadeIn(
              duration: const Duration(milliseconds: 300),
            );
          },
        );
      },
    );
  }

  // Set user ID for crash reporting
  Future<void> _setUserForCrashReporting(String? userId) async {
    if (userId != null) {
      await _appConfig.setUserIdentifier(userId);
    }
  }
}

