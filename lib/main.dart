import 'package:duckbuck/Authentication/providers/auth_provider.dart';
import 'package:duckbuck/Authentication/screens/welcome.dart';
import 'package:duckbuck/Home/providers/UserProvider.dart';
import 'package:duckbuck/Home/providers/friend_provider.dart';
import 'package:duckbuck/Home/providers/voice_note_provider.dart';
import 'package:duckbuck/Home/providers/pfp_provider.dart';
import 'package:duckbuck/home/home.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => PfpProvider()),
        ChangeNotifierProvider(create: (_) => VoiceMessageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DuckBuck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return authProvider.isAuthenticated ? HomeScreen() : WelcomeScreen();
        },
      ),
    );
  }
}
