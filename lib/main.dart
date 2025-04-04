import 'package:duckbuck/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import 'package:flutter/foundation.dart' show kDebugMode; 
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart'; 
import 'providers/friend_provider.dart';
import 'screens/Authentication/welcome_screen.dart';
import 'screens/onboarding/name_screen.dart';
import 'screens/onboarding/dob_screen.dart';
import 'screens/onboarding/gender_screen.dart';
import 'screens/onboarding/profile_photo_screen.dart';
import 'screens/Home/home_screen.dart'; 
import 'package:flutter/services.dart';
import 'services/friend_service.dart';
import 'config/app_config.dart'; 

void main() async {
  // Ensure Flutter is initialized and preserve native splash
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
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

class _AuthenticationWrapperState extends State<AuthenticationWrapper> with SingleTickerProviderStateMixin {
  // Flags to track loading states
  bool _isInitializing = true;
  
  // Target screen to show after splash
  Widget? _targetScreen;
  
  final AppConfig _appConfig = AppConfig();
  
  @override
  void initState() {
    super.initState();
    
    // Fully initialize the app and determine the correct screen to show
    _initializeApp();
  }
  
  // Completely initialize the app and determine the target screen
  Future<void> _initializeApp() async {
    try {
      // Get the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Wait for auth state to be determined
      while (authProvider.status == AuthStatus.loading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Determine the correct target screen based on auth state
      if (!authProvider.isAuthenticated) {
        // Not authenticated, show welcome screen
        _targetScreen = const WelcomeScreen();
      } else {
        // Authenticated, set user ID for crash reporting
        if (authProvider.currentUser?.uid != null) {
          await _setUserForCrashReporting(authProvider.currentUser?.uid);
        }
        
        // Determine onboarding stage
        final onboardingStage = await authProvider.getOnboardingStage();
        
        if (onboardingStage == OnboardingStage.notStarted) {
          // User doesn't exist in database, sign out and show welcome
          await authProvider.signOut();
          _targetScreen = const WelcomeScreen();
        } else {
          // Route to the appropriate screen based on onboarding stage
          switch (onboardingStage) {
            case OnboardingStage.completed:
              _targetScreen = const HomeScreen();
              break;
            case OnboardingStage.name:
              _targetScreen = const NameScreen();
              break;
            case OnboardingStage.dateOfBirth:
              _targetScreen = const DOBScreen();
              break;
            case OnboardingStage.gender:
              _targetScreen = const GenderScreen();
              break;
            case OnboardingStage.profilePhoto:
              _targetScreen = const ProfilePhotoScreen();
              break;
            default:
              _targetScreen = const NameScreen();
          }
        }
      }
      
      // Update state now that we're done initializing
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        
        // Remove native splash only after everything is ready
        FlutterNativeSplash.remove();
      }
    } catch (e) {
      // Log the error but still continue to show the app
      _appConfig.log('Error during app initialization: $e');
      
      // Set a default screen in case of error
      _targetScreen = const WelcomeScreen();
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        
        // Remove native splash even in case of error
        FlutterNativeSplash.remove();
      }
    }
  }

  // Set user ID for crash reporting
  Future<void> _setUserForCrashReporting(String? userId) async {
    if (userId != null) {
      await _appConfig.setUserIdentifier(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator during initialization
    if (_isInitializing) {
      // Return empty container while native splash is still showing
      return Container(color: Colors.transparent);
    }
    
    // Show the target screen with a fade animation
    return _targetScreen!.animate().fadeIn(
      duration: const Duration(milliseconds: 400),
    );
  }
}
