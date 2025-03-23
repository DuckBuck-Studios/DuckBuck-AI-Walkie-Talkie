import 'package:duckbuck/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart'; 
import 'providers/friend_provider.dart';
import 'screens/Authentication/welcome_screen.dart';
import 'screens/onboarding/name_screen.dart';
import 'screens/onboarding/dob_screen.dart';
import 'screens/onboarding/gender_screen.dart';
import 'screens/onboarding/profile_photo_screen.dart';
import 'screens/Home/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_receiver_service.dart';
import 'providers/call_provider.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase App Check
  await _initializeAppCheck();
  
  // Create call provider for initialization
  final callProvider = CallProvider();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => FriendProvider()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider.value(value: callProvider),
    ],
    child: const MyApp(),
  ));
}

// Platform-specific App Check initialization
Future<void> _initializeAppCheck() async {
  if (Platform.isAndroid) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  } else if (Platform.isIOS) {
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.debug,
    );
  }
  
  if (kDebugMode) {
    print('Firebase App Check initialized');
  }
}

/// Main app widget
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // FCM and Notification service initialization
  final FCMReceiverService _fcmService = FCMReceiverService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize FCM after build is complete to have access to context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePushNotifications();
    });
  }

  // Initialize push notifications
  Future<void> _initializePushNotifications() async {
    // Initialize FCM service with context
    await _fcmService.initialize(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle app lifecycle changes if needed
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: 'DuckBuck',
        debugShowCheckedModeBanner: false,
        navigatorKey: FCMReceiverService.navigatorKey,
        theme: ThemeData(
          primarySwatch: Colors.brown,
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.brown,
            brightness: Brightness.light,
          ),
        ),
        home: const AuthenticationWrapper(),
      ),
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
  
  @override
  void initState() {
    super.initState();
    // Check auth state asynchronously
    _checkAuthState();
  }
  
  // Check auth state asynchronously
  Future<void> _checkAuthState() async {
    // Add a minimum delay to show splash screen
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Widget _buildSplashScreen() {
    return const SplashScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Always show splash screen during initialization
    if (_isInitializing) {
      return _buildSplashScreen();
    }
    
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // If still loading auth state, show splash screen
        if (authProvider.status == AuthStatus.loading) {
          return _buildSplashScreen();
        }
        
        print('AuthWrapper: Current auth status: ${authProvider.status}');
        print('AuthWrapper: Is authenticated: ${authProvider.isAuthenticated}');
        print('AuthWrapper: Current user: ${authProvider.currentUser?.uid}');

        // If not authenticated, show welcome screen
        if (!authProvider.isAuthenticated) {
          print('AuthWrapper: Not authenticated, showing welcome screen');
          return const WelcomeScreen().animate().fadeIn(
            duration: const Duration(milliseconds: 300),
          );
        }

        // For authenticated users, check onboarding stage directly
        return FutureBuilder<OnboardingStage>(
          future: authProvider.getOnboardingStage(),
          builder: (context, stageSnapshot) {
            // If we're still loading the stage, show the splash screen
            if (stageSnapshot.connectionState == ConnectionState.waiting) {
              return _buildSplashScreen();
            }
            
            // Get the current stage
            final currentStage = stageSnapshot.data ?? OnboardingStage.name;
            print('AuthWrapper: Current onboarding stage: $currentStage');
            
            // If the user doesn't exist in the database (notStarted), show welcome screen
            if (currentStage == OnboardingStage.notStarted) {
              print('AuthWrapper: User not in database, showing welcome screen');
              // Sign out the user first
              authProvider.signOut();
              return const WelcomeScreen().animate().fadeIn(
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
}
