import 'package:duckbuck/screens/Authentication/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_animate/flutter_animate.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart'; 
import 'providers/friend_provider.dart';
import 'providers/user_provider.dart';
import 'screens/Home/home_screen.dart';   
import 'screens/onboarding/name_screen.dart';
import 'screens/onboarding/dob_screen.dart';
import 'screens/onboarding/gender_screen.dart';
import 'screens/onboarding/profile_photo_screen.dart';
import 'widgets/animated_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize App Check
  await _initializeAppCheck();
  
  runApp(const MyApp());
}

// Platform-specific App Check initialization
Future<void> _initializeAppCheck() async {
  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('YOUR-RECAPTCHA-V3-SITE-KEY'),
    );
  } else if (Platform.isAndroid) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  } else if (Platform.isIOS || Platform.isMacOS) {
    await FirebaseAppCheck.instance.activate(
      appleProvider: AppleProvider.debug,
    );
  }
  
  if (kDebugMode) {
    print('Firebase App Check initialized');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD4A76A),
            brightness: Brightness.light,
          ),
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// A splash screen to prevent flash of content
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Quickly initialize and move to the main app
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthenticationWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or name
              Text(
                "DuckBuck",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ).animate().fadeIn(duration: const Duration(milliseconds: 300)).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
              ),
            ],
          ),
        ),
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
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to listen to auth state changes
    return Consumer<AuthProvider>(
      builder: (_, authProvider, __) {
        // If not authenticated, show welcome screen with animation
        if (!authProvider.isAuthenticated) {
          return const WelcomeScreen().animate().fadeIn(duration: const Duration(milliseconds: 300));
        }
        
        // For authenticated users, check onboarding status and direct to proper screen
        return FutureBuilder<OnboardingStage>(
          future: authProvider.getOnboardingStage(),
          builder: (context, snapshot) {
            // While loading onboarding stage, show a placeholder that matches the app theme
            // rather than a loading indicator
            if (!snapshot.hasData) {
              return Scaffold(
                body: DuckBuckAnimatedBackground(
                  child: const SizedBox.expand(),
                ),
              );
            }
             
            Widget screenToShow;
            final onboardingStage = snapshot.data!;
            
            if (onboardingStage == OnboardingStage.completed) {
              screenToShow = const HomeScreen();
            } else {
              switch (onboardingStage) {
                case OnboardingStage.dateOfBirth:
                  screenToShow = const DOBScreen();
                  break;
                case OnboardingStage.gender:
                  screenToShow = const GenderScreen();
                  break;
                case OnboardingStage.profilePhoto:
                  screenToShow = const ProfilePhotoScreen();
                  break;
                case OnboardingStage.name:
                case OnboardingStage.notStarted:
                default:
                  screenToShow = const NameScreen();
                  break;
              }
            }
            
            // Return the appropriate screen with a fade-in animation
            return screenToShow.animate().fadeIn(
              duration: const Duration(milliseconds: 300),
            );
          },
        );
      },
    );
  }
}
