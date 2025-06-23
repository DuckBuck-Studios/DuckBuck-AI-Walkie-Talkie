# AI Agent Error Handling

This document outlines the comprehensive error handling strategy for the AI Agent system, including exception types, recovery mechanisms, and user experience patterns.

## Error Handling Architecture

### 1. Exception Hierarchy

```
AiAgentException (base)
├── Network Errors
│   ├── NetworkTimeoutException
│   ├── ConnectionFailedException
│   └── ApiUnavailableException
├── Authentication Errors
│   ├── TokenExpiredException
│   ├── InvalidCredentialsException
│   └── AuthorizationFailedException
├── Time Management Errors
│   ├── InsufficientTimeException
│   ├── TimeUpdateFailedException
│   └── TimeValidationException
├── Agora RTC Errors
│   ├── EngineInitializationException
│   ├── ChannelJoinException
│   └── AudioDeviceException
├── Backend Service Errors
│   ├── AgentCreationException
│   ├── AgentStopException
│   └── ServiceUnavailableException
└── Stream and Real-time Errors
    ├── StreamSubscriptionException
    ├── FirebaseSyncException
    └── RealtimeUpdateException
```

### 2. Error Code Classification

```dart
class AiAgentErrorCodes {
  // General errors (0-99)
  static const String unknown = 'ai-agent/unknown';
  static const String networkError = 'ai-agent/network-error';
  static const String databaseError = 'ai-agent/database-error';
  static const String invalidParameters = 'ai-agent/invalid-parameters';
  
  // Agent operation errors (100-199)
  static const String joinFailed = 'ai-agent/join-failed';
  static const String stopFailed = 'ai-agent/stop-failed';
  static const String agentNotFound = 'ai-agent/not-found';
  static const String agentAlreadyRunning = 'ai-agent/already-running';
  
  // Time management errors (200-299)
  static const String insufficientTime = 'ai-agent/insufficient-time';
  static const String timeUpdateFailed = 'ai-agent/time-update-failed';
  static const String timeCheckFailed = 'ai-agent/time-check-failed';
  static const String invalidTimeValue = 'ai-agent/invalid-time-value';
  
  // User-related errors (300-399)
  static const String userNotFound = 'ai-agent/user-not-found';
  static const String userNotAuthenticated = 'ai-agent/user-not-authenticated';
  static const String accessDenied = 'ai-agent/access-denied';
  
  // Stream and real-time errors (400-499)
  static const String streamError = 'ai-agent/stream-error';
  static const String streamSubscriptionFailed = 'ai-agent/stream-subscription-failed';
  static const String realtimeUpdateFailed = 'ai-agent/realtime-update-failed';
  
  // Circuit breaker and rate limiting (500-599)
  static const String circuitBreakerOpen = 'ai-agent/circuit-breaker-open';
  static const String rateLimitExceeded = 'ai-agent/rate-limit-exceeded';
  static const String serviceUnavailable = 'ai-agent/service-unavailable';
}
```

## Error Handling Patterns

### 1. Layered Error Handling

#### Service Layer (Throws)
```dart
class AiAgentService {
  Future<Map<String, dynamic>?> joinAgent({
    required String uid,
    required String channelName,
    required int remainingTimeSeconds,
  }) async {
    try {
      // Validate preconditions
      if (!hasRemainingTime(remainingTimeSeconds)) {
        return null; // Insufficient time - not an error, just no service
      }

      // Attempt API call
      final responseData = await _apiService.joinAiAgent(
        uid: uid,
        channelName: channelName,
      );

      if (responseData != null) {
        return responseData;
      } else {
        throw AiAgentExceptions.joinFailed('API returned null response');
      }
    } catch (e) {
      if (e is AiAgentException) rethrow;
      
      // Wrap unexpected errors
      throw AiAgentExceptions.joinFailed(e.toString(), e);
    }
  }
}
```

#### Repository Layer (Handles & Recovers)
```dart
class AiAgentRepository {
  Future<Map<String, dynamic>?> joinAgentWithFullSetup({
    required String uid,
  }) async {
    try {
      // Validate user eligibility
      final userData = await _userService.getUserData(uid);
      if (userData == null) {
        _logger.e(_tag, 'User data not found for uid: $uid');
        throw Exception('User data not found');
      }

      // Check time availability
      if (!_aiAgentService.hasRemainingTime(userData.agentRemainingTime)) {
        _logger.w(_tag, 'User $uid has no remaining AI agent time');
        return null; // Graceful handling - no exception
      }

      // Attempt service call
      return await _aiAgentService.joinAgentWithAgoraSetup(uid: uid);
    } catch (e) {
      _logger.e(_tag, 'Error in joinAgentWithFullSetup: $e');
      return null; // Convert exceptions to null for graceful UI handling
    }
  }
}
```

#### Provider Layer (UI State Management)
```dart
class AiAgentProvider extends ChangeNotifier {
  Future<bool> startAgent() async {
    try {
      _setState(AiAgentState.starting);
      
      final responseData = await _repository.joinAgentWithFullSetup(
        uid: _currentUid!,
      );
      
      if (responseData != null) {
        // Success path
        _createSession(responseData);
        return true;
      } else {
        // Graceful failure (insufficient time or service unavailable)
        _setError('Unable to start AI agent. Please check your remaining time.');
        _setState(AiAgentState.idle);
        return false;
      }
    } catch (e) {
      // Unexpected errors
      _logger.e(_tag, 'Error starting AI agent: $e');
      _setError('Failed to start AI agent. Please try again.');
      _setState(AiAgentState.idle);
      return false;
    }
  }
}
```

### 2. Circuit Breaker Pattern

```dart
class ApiService {
  bool _isCircuitBreakerOpen = false;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  static const int _failureThreshold = 5;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 1);
  
  Future<T> _executeWithCircuitBreaker<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    // Check if circuit breaker is open
    if (_isCircuitBreakerOpen) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
      
      if (timeSinceLastFailure < _circuitBreakerTimeout) {
        throw const ApiException(
          'Service temporarily unavailable due to circuit breaker',
          statusCode: 503,
          errorCode: 'CIRCUIT_BREAKER_OPEN',
        );
      } else {
        // Reset circuit breaker after timeout
        _resetCircuitBreaker();
      }
    }
    
    try {
      final result = await operation();
      _onRequestSuccess();
      return result;
    } catch (e) {
      _onRequestFailure();
      rethrow;
    }
  }
  
  void _onRequestFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= _failureThreshold) {
      _isCircuitBreakerOpen = true;
      _logger.e(_tag, 'Circuit breaker opened due to $failure_count consecutive failures');
    }
  }
  
  void _onRequestSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
  }
  
  void _resetCircuitBreaker() {
    _isCircuitBreakerOpen = false;
    _failureCount = 0;
    _lastFailureTime = null;
    _logger.i(_tag, 'Circuit breaker reset after timeout');
  }
}
```

### 3. Retry with Exponential Backoff

```dart
class ApiService {
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        
        if (attempt >= maxRetries) {
          _logger.e(_tag, '$operationName failed after $maxRetries attempts: $e');
          rethrow;
        }
        
        // Calculate exponential backoff delay
        final delay = Duration(
          milliseconds: (baseDelay.inMilliseconds * pow(2, attempt - 1)).toInt(),
        );
        
        _logger.w(_tag, '$operationName attempt $attempt failed, retrying in ${delay.inSeconds}s: $e');
        await Future.delayed(delay);
      }
    }
    
    throw Exception('Max retries exceeded'); // Should never reach here
  }
}
```

## Recovery Mechanisms

### 1. Graceful Degradation

#### Partial Functionality During Errors
```dart
class AiAgentProvider {
  Future<void> _connectAiAgentInBackground() async {
    try {
      // Attempt backend AI agent connection
      final responseData = await _repository.joinAiAgentOnly(
        uid: _currentUid!,
        channelName: 'ai_$_currentUid',
        remainingTimeSeconds: _remainingTimeSeconds,
      );
      
      if (responseData != null) {
        // Success: Full AI agent functionality
        _updateSessionWithBackendData(responseData);
        _setState(AiAgentState.running);
      } else {
        // Partial failure: Audio works, AI agent doesn't
        _setState(AiAgentState.error);
        _setError('AI Agent connection failed, but you can still use audio features');
        // Session continues - user can still use Agora audio
      }
    } catch (e) {
      // Background connection failed - don't interrupt user session
      _setState(AiAgentState.error);
      _setError('AI Agent connection failed, but you can still use audio features');
      // Audio controls remain functional
    }
  }
}
```

#### Audio Controls Always Functional
```dart
Future<bool> toggleMicrophone() async {
  // Audio controls work even during backend errors
  if (_currentSession == null) return false;
  
  try {
    final success = await _repository.toggleMicrophone();
    if (success) {
      _isMicrophoneMuted = await _repository.isMicrophoneMutedAsync();
      notifyListeners();
    }
    return success;
  } catch (e) {
    _logger.e(_tag, 'Error toggling microphone: $e');
    return false; // Return false but don't crash the session
  }
}
```

### 2. Automatic Recovery

#### Session Recovery After Network Issues
```dart
class AiAgentProvider {
  StreamSubscription<int>? _timeStreamSubscription;
  
  Future<void> initialize(String uid) async {
    _timeStreamSubscription = _repository.getUserRemainingTimeStream(uid).listen(
      (remainingTime) {
        _remainingTimeSeconds = remainingTime;
        notifyListeners();
      },
      onError: (error) {
        _logger.e(_tag, 'Error in time stream: $error');
        _setError('Connection issues with time tracking');
        
        // Attempt to reconnect after delay
        Timer(Duration(seconds: 5), () {
          _attemptStreamReconnection(uid);
        });
      },
    );
  }
  
  void _attemptStreamReconnection(String uid) {
    _timeStreamSubscription?.cancel();
    
    // Recursive retry with backoff
    _timeStreamSubscription = _repository.getUserRemainingTimeStream(uid).listen(
      (remainingTime) {
        _remainingTimeSeconds = remainingTime;
        _clearError(); // Clear error on successful reconnection
        notifyListeners();
      },
      onError: (error) {
        // Exponential backoff for reconnection attempts
        final delay = Duration(seconds: min(30, 5 * _reconnectionAttempts));
        Timer(delay, () => _attemptStreamReconnection(uid));
        _reconnectionAttempts++;
      },
    );
  }
}
```

### 3. Resource Cleanup on Errors

#### Automatic Cleanup Pattern
```dart
class AiAgentProvider {
  Future<bool> stopAgent() async {
    try {
      // Attempt normal cleanup
      final success = await _repository.stopAgentWithFullCleanup(
        agentId: _currentSession!.agentData.agentId,
        uid: _currentSession!.uid,
        timeUsedSeconds: _currentSession!.elapsedSeconds,
      );
      
      return success;
    } catch (e) {
      _logger.e(_tag, 'Error stopping AI agent: $e');
      return false;
    } finally {
      // Always clean up local resources regardless of errors
      _emergencyCleanup();
    }
  }
  
  void _emergencyCleanup() {
    // Clean up regardless of success/failure
    _stopUsageTracking();
    _stopProximitySensor();
    _currentSession = null;
    _setState(AiAgentState.idle);
    
    // Try to leave Agora channel
    try {
      _repository.stopAgentAndLeaveChannel();
    } catch (e) {
      _logger.e(_tag, 'Error during emergency Agora cleanup: $e');
    }
  }
}
```

## User Experience Error Patterns

### 1. Non-Blocking Errors

#### Background Sync Errors
```dart
// Firebase sync errors don't interrupt the user session
_firebaseSyncTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
  try {
    await _syncTimeToFirebase();
  } catch (e) {
    _logger.e(_tag, 'Background sync error: $e');
    // User continues using the app - sync will retry later
    // No UI notification for background errors
  }
});
```

#### Stream Reconnection Errors
```dart
// Stream errors trigger automatic reconnection without user intervention
onError: (error) {
  _logger.e(_tag, 'Stream error, attempting reconnection: $error');
  // Automatic retry - user sees no interruption
  Timer(Duration(seconds: 2), () => _reconnectStream());
}
```

### 2. User-Visible Errors

#### Clear Error Messaging
```dart
void _setError(String message) {
  _errorMessage = message;
  notifyListeners();
}

// Error messages are clear and actionable
_setError('Unable to connect to AI agent. Please check your internet connection and try again.');
_setError('No remaining AI agent time. Session will end shortly.');
_setError('Audio device unavailable. Please check your microphone permissions.');
```

#### Error Recovery Actions
```dart
// UI provides clear recovery options
Widget _buildErrorState() {
  return Column(
    children: [
      Text(_errorMessage),
      SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: _clearErrorAndRetry,
            child: Text('Retry'),
          ),
          ElevatedButton(
            onPressed: _returnToIdle,
            child: Text('Cancel'),
          ),
        ],
      ),
    ],
  );
}
```

### 3. Platform-Specific Error Presentation

#### iOS Error Dialogs
```dart
void _showErrorDialog(BuildContext context, String message) {
  showCupertinoDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('AI Agent Error'),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('OK'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CupertinoDialogAction(
          child: const Text('Retry'),
          onPressed: () {
            Navigator.of(context).pop();
            _retryLastOperation();
          },
        ),
      ],
    ),
  );
}
```

#### Android Error Snackbars
```dart
void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      action: SnackBarAction(
        label: 'Retry',
        textColor: Colors.white,
        onPressed: _retryLastOperation,
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}
```

## Error Monitoring and Logging

### 1. Comprehensive Error Logging

```dart
class LoggerService {
  void logError(String tag, String message, dynamic error, [StackTrace? stackTrace]) {
    // Console logging
    print('ERROR [$tag]: $message');
    if (error != null) {
      print('Error details: $error');
    }
    if (stackTrace != null) {
      print('Stack trace: $stackTrace');
    }
    
    // Analytics tracking
    _analyticsService.logError(tag, message, error);
    
    // Remote logging (production)
    if (kReleaseMode) {
      _remoteLogger.logError(tag, message, error, stackTrace);
    }
  }
}
```

### 2. Error Analytics

```dart
class ErrorAnalytics {
  void trackAiAgentError({
    required String errorCode,
    required String errorMessage,
    required AiAgentOperation operation,
    Map<String, dynamic>? additionalData,
  }) {
    final errorData = {
      'error_code': errorCode,
      'error_message': errorMessage,
      'operation': operation.name,
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': _currentUid,
      ...?additionalData,
    };
    
    _analyticsService.track('ai_agent_error', errorData);
  }
}
```

### 3. Error Metrics Collection

```dart
class ErrorMetrics {
  static final Map<String, int> _errorCounts = {};
  static final Map<String, DateTime> _lastErrorTimes = {};
  
  static void recordError(String errorCode) {
    _errorCounts[errorCode] = (_errorCounts[errorCode] ?? 0) + 1;
    _lastErrorTimes[errorCode] = DateTime.now();
    
    // Alert if error frequency is high
    if (_errorCounts[errorCode]! > 10) {
      _sendErrorAlert(errorCode);
    }
  }
  
  static Map<String, dynamic> getErrorSummary() {
    return {
      'error_counts': Map.from(_errorCounts),
      'last_error_times': _lastErrorTimes.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }
}
```

## Testing Error Scenarios

### 1. Unit Tests for Error Handling

```dart
group('AiAgentProvider Error Handling', () {
  test('should handle insufficient time gracefully', () async {
    // Mock repository to return null (insufficient time)
    when(mockRepository.joinAgentWithFullSetup(uid: anyNamed('uid')))
        .thenAnswer((_) async => null);
    
    final result = await provider.startAgent();
    
    expect(result, isFalse);
    expect(provider.state, AiAgentState.idle);
    expect(provider.errorMessage, contains('remaining time'));
  });
  
  test('should handle network errors with retry', () async {
    // Mock network error followed by success
    when(mockRepository.joinAgentWithFullSetup(uid: anyNamed('uid')))
        .thenThrow(NetworkException('Connection failed'))
        .thenAnswer((_) async => mockAgentResponse);
    
    // First attempt should fail
    final firstResult = await provider.startAgent();
    expect(firstResult, isFalse);
    
    // Retry should succeed
    final retryResult = await provider.startAgent();
    expect(retryResult, isTrue);
  });
});
```

### 2. Integration Tests for Error Recovery

```dart
testWidgets('should recover from stream errors', (tester) async {
  final provider = AiAgentProvider();
  final mockStream = StreamController<int>();
  
  // Setup widget with provider
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: AiAgentScreen(),
    ),
  );
  
  // Simulate stream error
  mockStream.addError(Exception('Stream failed'));
  await tester.pump();
  
  // Should show error state
  expect(find.text('connection issues'), findsOneWidget);
  
  // Simulate recovery
  mockStream.add(3600); // Remaining time
  await tester.pump();
  
  // Should return to normal state
  expect(find.text('Time: 1h'), findsOneWidget);
});
```

## Best Practices Summary

### 1. Error Handling Principles
- **Fail Gracefully**: Never crash the user session due to non-critical errors
- **Preserve User Investment**: Protect user's time and session progress
- **Clear Communication**: Provide actionable error messages
- **Automatic Recovery**: Attempt recovery without user intervention when possible
- **Resource Cleanup**: Always clean up resources regardless of error conditions

### 2. Error Categorization
- **Critical Errors**: Stop the session and require user action
- **Non-Critical Errors**: Continue session with degraded functionality
- **Background Errors**: Automatic retry without user notification
- **Transient Errors**: Automatic recovery with exponential backoff

### 3. User Experience Guidelines
- **Immediate Feedback**: Show error states immediately
- **Recovery Options**: Provide clear paths forward
- **Progress Preservation**: Don't lose user progress during errors
- **Platform Consistency**: Use native error presentation patterns
