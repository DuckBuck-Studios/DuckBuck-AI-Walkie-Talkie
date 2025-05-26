import 'package:flutter/material.dart';
import 'package:duckbuck/core/services/service_locator.dart';
import 'package:duckbuck/core/services/firebase/firebase_analytics_service.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final FirebaseAnalyticsService _analyticsService;
  DateTime _sessionStartTime = DateTime.now();
  Timer? _sessionHeartbeatTimer;
  int _sessionInteractions = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _analyticsService = serviceLocator<FirebaseAnalyticsService>();
    _analyticsService.logScreenView(
      screenName: 'home_content_screen',
      screenClass: 'HomeScreen',
    );
    _analyticsService.logEvent(
      name: 'auth_flow_complete',
      parameters: {
        'timestamp': DateTime.now().toIso8601String(),
        'screen': 'home_content_screen',
        'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
      },
    );
    _sessionHeartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _logSessionHeartbeat();
    });
  }

  @override
  void dispose() {
    _sessionHeartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _logSessionEnd(reason: 'screen_disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _logSessionEnd(reason: 'app_backgrounded');
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
      _analyticsService.logEvent(
        name: 'home_session_resumed',
        parameters: {
          'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
        },
      );
    }
  }

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

  void _logSessionEnd({required String reason}) {
    final duration = DateTime.now().difference(_sessionStartTime);
    _analyticsService.logEvent(
      name: 'home_session_end',
      parameters: {
        'session_duration_seconds': duration.inSeconds.toString(),
        'end_reason': reason,
        'session_id': _sessionStartTime.millisecondsSinceEpoch.toString(),
        'interactions_count': _sessionInteractions.toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreenContent();
  }
}

class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        // Remove back button by setting automaticallyImplyLeading to false
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Welcome to DuckBuck!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            // Removed the demo button as requested
          ],
        ),
      ),
    );
  }
}
