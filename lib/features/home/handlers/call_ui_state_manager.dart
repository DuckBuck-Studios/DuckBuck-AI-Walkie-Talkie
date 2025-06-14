import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../widgets/call_ui.dart';

/// Manages the enhanced call UI states and timing transitions
/// Handles progression from connecting -> waiting long -> failed states
class CallUIStateManager extends ChangeNotifier {
  static const String _tag = 'CALL_UI_STATE_MANAGER';
  final LoggerService _logger = serviceLocator<LoggerService>();
  
  // Timing constants - ensure each message shows for at least 5 seconds
  static const Duration _connectingDuration = Duration(seconds: 5); // Show "connecting" for 5 seconds
  static const Duration _waitingLongDuration = Duration(seconds: 5); // Show "waiting long" for 5 seconds  
  static const Duration _totalTimeout = Duration(seconds: 25); // Total timeout increased from 20 to 25 seconds
  
  CallLoadingState _currentState = CallLoadingState.connecting;
  Timer? _stateTimer;
  Timer? _waitingLongTimer;
  Timer? _timeoutTimer;
  bool _isActive = false;
  
  CallLoadingState get currentState => _currentState;
  bool get isActive => _isActive;
  
  /// Start the call UI state progression
  void startCallUI() {
    _logger.i(_tag, 'Starting call UI state progression...');
    
    if (_isActive) {
      _logger.w(_tag, 'Call UI already active, resetting...');
      reset();
    }
    
    _isActive = true;
    _currentState = CallLoadingState.connecting;
    notifyListeners();
    
    // Schedule transition to waiting long state after 5 seconds
    _stateTimer = Timer(_connectingDuration, () {
      if (_isActive) {
        _logger.i(_tag, 'Transitioning to waiting long state (friend internet sucks)...');
        _currentState = CallLoadingState.waitingLong;
        notifyListeners();
        
        // Schedule transition to failed state after additional 5 seconds in waiting long
        _waitingLongTimer = Timer(_waitingLongDuration, () {
          if (_isActive) {
            _logger.w(_tag, 'Call timed out after waiting long, transitioning to failed state...');
            _currentState = CallLoadingState.failed;
            notifyListeners();
          }
        });
      }
    });
    
    // Keep the total timeout as a safety net
    _timeoutTimer = Timer(_totalTimeout, () {
      if (_isActive) {
        _logger.w(_tag, 'Total timeout reached, forcing failed state...');
        _currentState = CallLoadingState.failed;
        notifyListeners();
      }
    });
  }
  
  /// Call succeeded - hide the loading UI
  void callSucceeded() {
    _logger.i(_tag, 'Call succeeded - stopping UI state manager');
    reset();
  }
  
  /// Call failed immediately - show failed state
  void callFailed() {
    _logger.w(_tag, 'Call failed immediately - showing failed state');
    
    if (!_isActive) return;
    
    _cancelTimers();
    _currentState = CallLoadingState.failed;
    notifyListeners();
  }
  
  /// User cancelled the call
  void callCancelled() {
    _logger.i(_tag, 'Call cancelled by user');
    reset();
  }
  
  /// User wants to retry the call
  void callRetry() {
    _logger.i(_tag, 'Call retry requested by user');
    // Reset and start again
    reset();
    startCallUI();
  }
  
  /// Reset the state manager
  void reset() {
    _logger.d(_tag, 'Resetting call UI state manager...');
    
    _cancelTimers();
    _isActive = false;
    _currentState = CallLoadingState.connecting;
    notifyListeners();
  }
  
  /// Cancel all active timers
  void _cancelTimers() {
    _stateTimer?.cancel();
    _stateTimer = null;
    _waitingLongTimer?.cancel();
    _waitingLongTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
  
  @override
  void dispose() {
    _logger.d(_tag, 'Disposing call UI state manager...');
    _cancelTimers();
    super.dispose();
  }
}
