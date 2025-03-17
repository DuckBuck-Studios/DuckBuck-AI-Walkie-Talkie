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
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
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
        home: const AuthenticationWrapper(),
        debugShowCheckedModeBanner: false,
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
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading screen while checking auth state
        if (authProvider.status == AuthStatus.loading) {
          return Scaffold(
            body: DuckBuckAnimatedBackground(
              opacity: 0.03,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4A76A)),
                ),
              ),
            ),
          );
        }

        // If not authenticated, show welcome screen
        if (!authProvider.isAuthenticated) {
          return const WelcomeScreen().animate().fadeIn(
            duration: const Duration(milliseconds: 300),
          );
        }

        // For authenticated users, check onboarding status
        return FutureBuilder<OnboardingStage>(
          future: authProvider.getOnboardingStage(),
          builder: (context, snapshot) {
            // Show loading screen while checking onboarding stage
            if (!snapshot.hasData) {
              return Scaffold(
                body: DuckBuckAnimatedBackground(
                  opacity: 0.03,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4A76A)),
                    ),
                  ),
                ),
              );
            }

            // Determine which screen to show based on onboarding stage
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

            // Show the appropriate screen with animation
            return screenToShow.animate().fadeIn(
              duration: const Duration(milliseconds: 300),
            );
          },
        );
      },
    );
  }
}
