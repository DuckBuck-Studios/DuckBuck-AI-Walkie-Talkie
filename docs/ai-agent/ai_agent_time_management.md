# AI Agent Time Management System

This document describes the comprehensive time management system that tracks and controls AI agent usage in DuckBuck.

## Overview

The AI Agent time management system provides users with a limited allocation of AI conversation time, tracks usage in real-time, and synchronizes data across multiple layers of the application architecture.

## Time Allocation System

### 1. Default Time Allowance
- **New Users**: 1 hour (3600 seconds) of AI agent time
- **Storage Location**: Firebase Firestore user document
- **Field Name**: `agentRemainingTime`
- **Data Type**: Integer (seconds)

### 2. Time Persistence
```dart
// UserModel structure
class UserModel {
  final String uid;
  final String email;
  // ... other fields
  final int agentRemainingTime;  // Seconds remaining
  
  UserModel({
    required this.uid,
    required this.email,
    // ... other parameters
    this.agentRemainingTime = 3600, // Default 1 hour
  });
}
```

### 3. Firebase Document Structure
```json
{
  "uid": "user_firebase_uid",
  "email": "user@example.com",
  "agentRemainingTime": 3600,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Real-Time Tracking Architecture

### 1. Multi-Layer Time Tracking

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (AiAgentProvider)               │
├─────────────────────────────────────────────────────────────┤
│  • Local timer (1 second intervals)                        │
│  • Real-time UI updates                                    │
│  • Auto-stop when time expires locally                     │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                Firebase Sync Layer                         │
├─────────────────────────────────────────────────────────────┤
│  • Batch sync timer (5 second intervals)                   │
│  • Firebase writes for persistence                         │
│  • Error handling for sync failures                        │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              Real-Time Stream Layer                        │
├─────────────────────────────────────────────────────────────┤
│  • Firebase document stream listener                       │
│  • Cross-device synchronization                            │
│  • External time updates (purchases, rewards)              │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Storage Layer                           │
├─────────────────────────────────────────────────────────────┤
│  • Firestore document persistence                          │
│  • Atomic update operations                                │
│  • Transaction-based time modifications                    │
└─────────────────────────────────────────────────────────────┘
```

### 2. Local Time Tracking Implementation

```dart
class AiAgentProvider extends ChangeNotifier {
  Timer? _usageTimer;
  Timer? _firebaseSyncTimer;
  int _remainingTimeSeconds = 0;
  
  void _startUsageTracking() {
    int lastSyncedTime = _remainingTimeSeconds;
    
    // Local UI updates every second
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTimeSeconds > 0) {
        _remainingTimeSeconds--;
        notifyListeners();
        
        // Auto-stop when time reaches 0
        if (_remainingTimeSeconds <= 0) {
          _logger.w(_tag, 'Time exhausted during usage tracking');
          stopAgent();
        }
      }
    });
    
    // Firebase sync every 5 seconds
    _firebaseSyncTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (_currentSession != null && _currentUid != null) {
        try {
          final timeUsedSinceLastSync = lastSyncedTime - _remainingTimeSeconds;
          
          if (timeUsedSinceLastSync > 0) {
            await _repository.updateUserRemainingTime(
              uid: _currentUid!,
              timeUsedSeconds: timeUsedSinceLastSync,
            );
            
            lastSyncedTime = _remainingTimeSeconds;
          }
        } catch (e) {
          _logger.e(_tag, 'Error syncing time to Firebase: $e');
          // Don't stop the agent on sync errors
        }
      }
    });
  }
}
```

## Firebase Real-Time Synchronization

### 1. Stream-Based Updates
```dart
class AiAgentService {
  Stream<int> getUserRemainingTimeStream(String uid) {
    // Return existing stream if already created
    if (_timeStreamControllers.containsKey(uid)) {
      return _timeStreamControllers[uid]!.stream;
    }

    // Create new stream controller
    final controller = StreamController<int>.broadcast();
    _timeStreamControllers[uid] = controller;

    // Listen to Firebase document changes
    final subscription = _databaseService.documentStream(
      collection: 'users',
      documentId: uid,
    ).listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final userData = snapshot.data()!;
          final remainingTime = userData['agentRemainingTime'] as int? ?? 0;
          
          if (!controller.isClosed) {
            controller.add(remainingTime);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(AiAgentExceptions.streamError(
            'Firebase stream error', 
            error
          ));
        }
      },
    );

    _timeStreamSubscriptions[uid] = subscription;
    return controller.stream;
  }
}
```

### 2. Provider Stream Integration
```dart
class AiAgentProvider extends ChangeNotifier {
  StreamSubscription<int>? _timeStreamSubscription;
  
  Future<void> initialize(String uid) async {
    // Listen to real-time time updates
    _timeStreamSubscription = _repository.getUserRemainingTimeStream(uid).listen(
      (remainingTime) {
        _remainingTimeSeconds = remainingTime;
        
        // Auto-stop agent if time runs out via external update
        if (remainingTime <= 0 && isAgentRunning) {
          _logger.w(_tag, 'Time exhausted via external update, auto-stopping');
          stopAgent();
        }
        
        notifyListeners();
      },
      onError: (error) {
        _logger.e(_tag, 'Error in time stream: $error');
        _setError('Failed to get real-time time updates');
      },
    );
  }
}
```

## Time Update Operations

### 1. Decrease Time (Usage Tracking)
```dart
class UserService {
  Future<int> decreaseUserAgentTime({
    required String uid,
    required int timeUsedSeconds,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        
        if (!snapshot.exists) {
          throw Exception('User not found');
        }
        
        final currentTime = snapshot.data()?['agentRemainingTime'] as int? ?? 0;
        final newTime = (currentTime - timeUsedSeconds).clamp(0, double.infinity).toInt();
        
        transaction.update(userRef, {
          'agentRemainingTime': newTime,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return newTime;
      });
    } catch (e) {
      _logger.e(_tag, 'Error decreasing user agent time: $e');
      rethrow;
    }
  }
}
```

### 2. Increase Time (Purchases/Rewards)
```dart
Future<int> increaseUserAgentTime({
  required String uid,
  required int additionalTimeSeconds,
}) async {
  try {
    final userRef = _firestore.collection('users').doc(uid);
    
    return await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      
      if (!snapshot.exists) {
        throw Exception('User not found');
      }
      
      final currentTime = snapshot.data()?['agentRemainingTime'] as int? ?? 0;
      final newTime = currentTime + additionalTimeSeconds;
      
      transaction.update(userRef, {
        'agentRemainingTime': newTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return newTime;
    });
  } catch (e) {
    _logger.e(_tag, 'Error increasing user agent time: $e');
    rethrow;
  }
}
```

### 3. Reset Time (Admin/Development)
```dart
Future<void> resetUserAgentTime(String uid) async {
  try {
    const defaultTime = 3600; // 1 hour
    
    await _firestore.collection('users').doc(uid).update({
      'agentRemainingTime': defaultTime,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    _logger.i(_tag, 'Reset user $uid agent time to ${defaultTime}s');
  } catch (e) {
    _logger.e(_tag, 'Error resetting user agent time: $e');
    rethrow;
  }
}
```

## Time Validation and Enforcement

### 1. Pre-Session Validation
```dart
class AiAgentRepository {
  Future<bool> canUseAiAgent(String uid) async {
    try {
      final userData = await _userService.getUserData(uid);
      if (userData == null) return false;

      return _aiAgentService.hasRemainingTime(userData.agentRemainingTime);
    } catch (e) {
      _logger.e(_tag, 'Error checking if user can use AI agent: $e');
      return false;
    }
  }
}
```

### 2. Real-Time Enforcement
```dart
class AiAgentService {
  bool hasRemainingTime(int remainingTimeSeconds) {
    return remainingTimeSeconds > 0;
  }
  
  Future<Map<String, dynamic>?> joinAgent({
    required String uid,
    required String channelName,
    required int remainingTimeSeconds,
  }) async {
    // Validate time before starting session
    if (!hasRemainingTime(remainingTimeSeconds)) {
      _logger.w(_tag, 'User $uid has no remaining AI agent time: ${remainingTimeSeconds}s');
      return null; // Indicates insufficient time
    }
    
    // Proceed with agent join
    return await _apiService.joinAiAgent(uid: uid, channelName: channelName);
  }
}
```

### 3. Auto-Stop Mechanisms
```dart
class AiAgentProvider {
  void _setAutoStopTimer() {
    _autoStopTimer?.cancel();
    
    if (_remainingTimeSeconds > 0) {
      // Set timer for exact remaining time
      _autoStopTimer = Timer(Duration(seconds: _remainingTimeSeconds), () {
        _logger.w(_tag, 'Auto-stop timer triggered - time expired');
        if (isAgentRunning) {
          stopAgent(); // Automatic cleanup
        }
      });
    }
  }
}
```

## Time Display and Formatting

### 1. Human-Readable Time Formatting
```dart
class AiAgentService {
  String formatRemainingTime(int remainingTimeSeconds) {
    if (remainingTimeSeconds <= 0) {
      return '0 minutes';
    }
    
    final hours = remainingTimeSeconds ~/ 3600;
    final minutes = (remainingTimeSeconds % 3600) ~/ 60;
    final seconds = remainingTimeSeconds % 60;
    
    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${hours}h';
      }
    } else if (minutes > 0) {
      if (seconds > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${minutes}m';
      }
    } else {
      return '${seconds}s';
    }
  }
}
```

### 2. UI Time Display
```dart
class AiAgentProvider {
  // Formatted display strings
  String get formattedRemainingTime {
    return _formatTime(_remainingTimeSeconds);
  }
  
  String get formattedElapsedTime {
    if (_currentSession == null) return '0:00';
    return _formatTime(_currentSession!.elapsedSeconds);
  }
  
  String _formatTime(int seconds) {
    if (seconds <= 0) return '0:00';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
}
```

## Error Handling and Recovery

### 1. Sync Failure Handling
```dart
// Firebase sync errors don't stop the session
_firebaseSyncTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
  try {
    await _syncTimeToFirebase();
  } catch (e) {
    _logger.e(_tag, 'Error syncing time to Firebase: $e');
    // Continue session - local tracking remains active
    // User won't lose their session due to network issues
  }
});
```

### 2. Stream Error Recovery
```dart
Stream<int> getUserRemainingTimeStream(String uid) {
  return _databaseService.documentStream(
    collection: 'users',
    documentId: uid,
  ).handleError((error) {
    _logger.e(_tag, 'Firebase stream error for user $uid: $error');
    // Return current known value instead of breaking the stream
    return _lastKnownTime ?? 0;
  });
}
```

### 3. Time Preservation on Errors
```dart
Future<bool> stopAgentWithFullCleanup({
  required String agentId,
  required String uid,
  required int timeUsedSeconds,
}) async {
  try {
    final backendStopped = await _aiAgentService.stopAgent(agentId: agentId);
    
    // Update time only if backend confirms successful stop
    if (backendStopped && timeUsedSeconds > 0) {
      await _aiAgentService.decreaseUserAgentTime(
        uid: uid,
        timeUsedSeconds: timeUsedSeconds,
      );
    }
    
    return backendStopped;
  } catch (e) {
    _logger.e(_tag, 'Error in stopAgentWithFullCleanup: $e');
    // On error, preserve user's time by not updating
    return false;
  }
}
```

## Performance Optimizations

### 1. Efficient Timer Management
```dart
// Single timer for UI updates, separate timer for sync
void _startUsageTracking() {
  // High-frequency local updates
  _usageTimer = Timer.periodic(Duration(seconds: 1), _updateLocalTime);
  
  // Low-frequency network sync
  _firebaseSyncTimer = Timer.periodic(Duration(seconds: 5), _syncToFirebase);
}

void _stopUsageTracking() {
  _usageTimer?.cancel();
  _usageTimer = null;
  _firebaseSyncTimer?.cancel();
  _firebaseSyncTimer = null;
}
```

### 2. Batched Updates
```dart
// Accumulate time usage and batch sync to reduce Firebase writes
void _syncToFirebase() async {
  final timeUsedSinceLastSync = _lastSyncedTime - _remainingTimeSeconds;
  
  if (timeUsedSinceLastSync > 0) {
    await _updateFirebaseTime(timeUsedSinceLastSync);
    _lastSyncedTime = _remainingTimeSeconds;
  }
}
```

### 3. Stream Controller Cleanup
```dart
void dispose() {
  // Proper cleanup of stream resources
  for (final subscription in _timeStreamSubscriptions.values) {
    subscription.cancel();
  }
  _timeStreamSubscriptions.clear();
  
  for (final controller in _timeStreamControllers.values) {
    if (!controller.isClosed) {
      controller.close();
    }
  }
  _timeStreamControllers.clear();
}
```

## Future Enhancements

### 1. Time Purchase System
```dart
// Placeholder for future time purchase integration
Future<bool> purchaseAdditionalTime({
  required String uid,
  required int timePackageMinutes,
  required String paymentToken,
}) async {
  // 1. Process payment
  // 2. Add time to user account
  // 3. Update Firebase
  // 4. Notify real-time streams
}
```

### 2. Usage Analytics
```dart
// Track usage patterns for optimization
class TimeUsageAnalytics {
  void recordSessionDuration(String uid, Duration sessionTime) {
    // Track session lengths for analytics
  }
  
  void recordTimeRemaining(String uid, int remainingSeconds) {
    // Track user time consumption patterns
  }
}
```

### 3. Time Rewards System
```dart
// Reward system for active users
Future<void> rewardUserTime({
  required String uid,
  required String rewardReason,
  required int bonusTimeSeconds,
}) async {
  // Add bonus time for achievements, referrals, etc.
}
```
