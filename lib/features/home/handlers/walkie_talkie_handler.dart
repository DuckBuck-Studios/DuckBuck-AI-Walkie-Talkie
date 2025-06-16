import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';

/// Handler for walkie-talkie connection with funny messages and timer
class WalkieTalkieHandler extends ChangeNotifier {
  static const String _tag = 'WALKIE_TALKIE_HANDLER';
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  Timer? _connectionTimer;
  Timer? _messageTimer;
  int _remainingSeconds = 25;
  bool _isConnecting = false;
  String _currentMessage = '';
  
  // Simple connection messages to show during the waiting period
  final List<String> _connectionMessages = [
    "Connecting to your friend...",
    "Your friend's internet sucks...",
    "Connection failed! Try again later.",
  ];
  
  // Getters
  bool get isConnecting => _isConnecting;
  String get currentMessage => _currentMessage;
  int get remainingSeconds => _remainingSeconds;
  
  /// Start the walkie-talkie connection process
  void startConnection() {
    if (_isConnecting) return;
    
    _logger.i(_tag, 'Starting walkie-talkie connection...');
    
    _isConnecting = true;
    _remainingSeconds = 25;
    _currentMessage = _connectionMessages[0]; // "Connecting to your friend..."
    
    notifyListeners();
    
    // Start the 25-second countdown timer
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      
      if (_remainingSeconds <= 0) {
        // Connection failed after 25 seconds
        _handleConnectionTimeout();
      } else {
        notifyListeners();
      }
    });
    
    // Start showing connection messages
    _startConnectionMessages();
  }
  
  /// Start showing connection messages at intervals
  void _startConnectionMessages() {
    // Show "Your friend's internet sucks..." after 5 seconds
    Timer(const Duration(seconds: 5), () {
      if (_isConnecting && _remainingSeconds > 5) {
        _currentMessage = _connectionMessages[1]; // "Your friend's internet sucks..."
        _logger.d(_tag, 'Showing message: $_currentMessage');
        notifyListeners();
      }
    });
  }
  
  /// Handle connection timeout (25 seconds elapsed)
  void _handleConnectionTimeout() {
    _logger.w(_tag, 'Connection timed out after 25 seconds');
    _currentMessage = _connectionMessages[2]; // "Connection failed! Try again later."
    
    // Auto-stop after showing timeout message for 2 seconds
    Timer(const Duration(seconds: 2), () {
      stopConnection();
    });
    
    notifyListeners();
  }
  
  /// Handle connection failure
  void connectionFailed() {
    if (!_isConnecting) return;
    
    _logger.w(_tag, 'Connection failed!');
    _currentMessage = _connectionMessages[2]; // "Connection failed! Try again later."
    
    // Auto-stop after showing failure message for 2 seconds
    Timer(const Duration(seconds: 2), () {
      stopConnection();
    });
    
    notifyListeners();
  }
  
  /// Simulate successful connection (call this when friend actually joins)
  void connectionSucceeded() {
    if (!_isConnecting) return;
    
    _logger.i(_tag, 'Connection succeeded!');
    
    // Stop timers and clear connecting state completely
    _connectionTimer?.cancel();
    _messageTimer?.cancel();
    _connectionTimer = null;
    _messageTimer = null;
    
    // Clear all connecting state so call UI can show
    _isConnecting = false;
    _currentMessage = '';
    _remainingSeconds = 25;
    
    notifyListeners();
  }
  
  /// End the walkie-talkie session (call this when call actually ends)
  void endSession() {
    _logger.i(_tag, 'Ending walkie-talkie session...');
    _cleanup();
    notifyListeners();
  }

  /// Stop the connection attempt
  void stopConnection() {
    _logger.i(_tag, 'Stopping walkie-talkie connection...');
    _cleanup();
    notifyListeners();
  }
  
  /// Clean up timers and reset state
  void _cleanup() {
    _connectionTimer?.cancel();
    _messageTimer?.cancel();
    _connectionTimer = null;
    _messageTimer = null;
    
    _isConnecting = false;
    _currentMessage = '';
    _remainingSeconds = 25;
  }
  
  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
