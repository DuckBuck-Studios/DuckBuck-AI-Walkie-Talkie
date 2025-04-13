import 'package:flutter/material.dart'; 
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';
import 'call_control_buttons.dart';
import 'dart:async';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _controlsVisible = true;
  StreamSubscription? _callStateSubscription;
  Timer? _autoHideTimer;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    // Auto-hide controls after 4 seconds
    _startAutoHideTimer();
    
    // Add listener for call state changes after a brief delay to let mounting complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToCallStateChanges();
    });
  }

  void _startAutoHideTimer() {
    // Cancel any existing timer
    _autoHideTimer?.cancel();
    
    // Start new timer
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }
  
  void _listenToCallStateChanges() {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // Listen to call state changes to detect remote-ended calls
    _callStateSubscription = callProvider.callStateChanges.listen((state) {
      if (state == CallState.ended || state == CallState.idle) {
        // Call ended by remote user, pop back to previous screen
        debugPrint('CallScreen: Call ended remotely, closing screen');
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else if (state == CallState.connected) {
        // Call just connected - ensure controls visible briefly
        if (mounted) {
          setState(() {
            _controlsVisible = true;
          });
          
          // Then auto-hide after delay
          _startAutoHideTimer();
        }
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _callStateSubscription?.cancel();
    _autoHideTimer?.cancel();
    super.dispose();
  }
  
  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    if (_controlsVisible) { 
      _startAutoHideTimer();
    } else { 
      _autoHideTimer?.cancel();
    }
  }
  
  // Build profile view for audio-only call
  Widget _buildProfileView(CallProvider callProvider) {
    final call = callProvider.currentCall;
    final callerName = call['sender_name'] ?? 'Unknown Caller';
    final callerPhoto = call['sender_photo'];
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (callerPhoto != null && callerPhoto.isNotEmpty)
          Hero(
            tag: 'caller_photo_${call['sender_uid']}',
            child: CircleAvatar(
              radius: 75,
              backgroundImage: NetworkImage(callerPhoto),
            ),
          ),
        if (callerPhoto == null || callerPhoto.isEmpty)
          Hero(
            tag: 'caller_photo_${call['sender_uid']}',
            child: CircleAvatar(
              radius: 75,
              backgroundColor: Colors.purple.shade700,
              child: const Icon(
                Icons.person,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
            
        const SizedBox(height: 32),
        
        Text(
          callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate()
      .fadeIn(duration: 400.ms, curve: Curves.easeOutQuad)
      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutExpo);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          // Get call data
          final callState = callProvider.callState;
          final duration = callProvider.callDurationText;
          
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background - solid black
              Container(
                color: Colors.black,
              ),
              
              // Main content area
              SafeArea(
                child: _buildProfileView(callProvider),
              ),
              
              // Invisible layer for gesture detection
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleControls,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
              
              // Call duration display
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ).animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms),
                  ),
                ),
              ),
              
              // Call status text
              Positioned(
                bottom: 160,
                left: 0,
                right: 0,
                child: Visibility(
                  visible: callState == CallState.connecting,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 50),
                    child: Text(
                      _getCallStatusText(callState),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, duration: 500.ms),
                ),
              ),
              
              // Bottom controls with enhanced animation
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CallControlButtons(
                  callProvider: callProvider,
                  controlsVisible: _controlsVisible,
                  onCallEnd: () => Navigator.of(context).pop(),
                ).animate(
                  target: _controlsVisible ? 1 : 0,
                )
                  .slide(
                    begin: const Offset(0, 1),
                    end: const Offset(0, 0),
                    duration: 350.ms,
                    curve: _controlsVisible ? Curves.easeOutQuint : Curves.easeInQuint,
                  )
                  .fade(
                    begin: 0.4,
                    end: 1.0,
                    duration: 300.ms,
                    curve: Curves.easeOut
                  )
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.0, 1.0),
                    duration: 350.ms,
                    curve: Curves.easeOutBack
                  ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  String _getCallStatusText(CallState state) {
    switch (state) {
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return 'Connected';
      case CallState.connectionFailed:
        return 'Connection failed';
      case CallState.ended:
        return 'Call ended';
      case CallState.idle:
        return 'Call ended';
    }
  }
}

class CallScreenRoute extends PageRouteBuilder {
  final Map<String, dynamic> callData;
  
  CallScreenRoute({required this.callData})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => const CallScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          const curve = Curves.easeOutExpo;
          var fadeAnimation = Tween(begin: begin, end: end).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );
          
          return FadeTransition(opacity: fadeAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      );
} 