import 'package:duckbuck/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import 'package:flutter/foundation.dart' show kDebugMode; 
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
import 'package:flutter/services.dart';
import 'services/friend_service.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize app configuration
  final appConfig = AppConfig();
  await appConfig.initialize(
    // Set to production for release builds
    env: kDebugMode ? Environment.development : Environment.production,
  );
   
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
      ChangeNotifierProvider(create: (_) => FriendProvider(FriendService())),
      ChangeNotifierProvider(create: (_) => UserProvider()),
    ],
    child: const MyApp(),
  ));
}

/// Main app widget
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

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
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider(FriendService())),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
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
  final AppConfig _appConfig = AppConfig();
  
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

  // Set user ID for crash reporting
  Future<void> _setUserForCrashReporting(String? userId) async {
    if (userId != null) {
      await _appConfig.setUserIdentifier(userId);
    }
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

        // If not authenticated, show welcome screen
        if (!authProvider.isAuthenticated) {
          _appConfig.log('User not authenticated, showing welcome screen');
          return const WelcomeScreen().animate().fadeIn(
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
              return _buildSplashScreen();
            }
            
            // Get the current stage
            final currentStage = stageSnapshot.data ?? OnboardingStage.name;
            _appConfig.log('Current onboarding stage: $currentStage');
            
            // If the user doesn't exist in the database (notStarted), show welcome screen
            if (currentStage == OnboardingStage.notStarted) {
              _appConfig.log('User not in database, showing welcome screen');
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
