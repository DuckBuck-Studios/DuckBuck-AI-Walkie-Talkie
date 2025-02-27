import 'package:duckbuck/Authentication/providers/auth_provider.dart';
import 'package:duckbuck/Authentication/screens/welcome.dart';
import 'package:duckbuck/Home/providers/UserProvider.dart';
import 'package:duckbuck/Home/providers/call_provider.dart';
import 'package:duckbuck/Home/providers/friend_provider.dart';
import 'package:duckbuck/Home/providers/pfp_provider.dart';
import 'package:duckbuck/home/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:duckbuck/Home/fcm_service/fcm_notification_handler.dart';

// This needs to be outside of any class
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await FCMNotificationHandler.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Set the background message handler before initializing FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize FCM handler
  await FCMNotificationHandler.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => PfpProvider()),
        ChangeNotifierProvider(create: (context) => CallProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: MaterialApp(
        title: 'DuckBuck',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: Builder(
          builder: (context) {
            // Set the application context for FCM handler
            FCMNotificationHandler.setApplicationContext(context);
            return Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return authProvider.isAuthenticated
                    ? HomeScreen()
                    : WelcomeScreen();
              },
            );
          },
        ),
      ),
    );
  }
}
