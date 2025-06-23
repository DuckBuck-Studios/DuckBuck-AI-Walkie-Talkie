# AI Agent Code Organization

This document provides a comprehensive overview of the AI Agent codebase structure, component relationships, and architectural patterns.

## Directory Structure

```
lib/
├── features/ai_agent/
│   ├── models/
│   │   └── ai_agent_models.dart           # Data models for AI agent operations
│   ├── providers/
│   │   └── ai_agent_provider.dart         # State management and UI logic
│   ├── screens/
│   │   └── ai_agent_screen.dart           # Main UI screen with controls
│   └── README.md                          # Feature-specific documentation
│
├── core/
│   ├── exceptions/
│   │   └── ai_agent_exceptions.dart       # AI agent specific exceptions
│   ├── repositories/
│   │   └── ai_agent_repository.dart       # Business logic orchestration
│   ├── services/
│   │   ├── ai_agent/
│   │   │   ├── ai_agent_service.dart      # Core AI agent service implementation
│   │   │   └── ai_agent_service_interface.dart # Service contract definition
│   │   ├── api/
│   │   │   └── api_service.dart           # HTTP API integration (joinAiAgent, stopAiAgent)
│   │   ├── agora/
│   │   │   ├── agora_service.dart         # Agora RTC integration
│   │   │   └── agora_token_service.dart   # Token management for Agora
│   │   ├── user/
│   │   │   └── user_service.dart          # User data and time management
│   │   ├── sensors/
│   │   │   └── sensor_service.dart        # Proximity sensor integration
│   │   └── logger/
│   │       └── logger_service.dart        # Logging infrastructure
│   └── app/
       └── provider_registry.dart         # Provider registration and DI setup
```

## Core Components Deep Dive

### 1. Models Layer (`features/ai_agent/models/`)

#### ai_agent_models.dart
```dart
// Primary data structures
class AiAgentResponse {
  final bool success;
  final String message;
  final AiAgentData? data;
}

class AiAgentData {
  final String agentId;      // Backend unique identifier
  final String agentName;    // Human-readable name
  final String channelName;  // Agora channel identifier
  final String status;       // Backend agent status
  final int createTs;        // Creation timestamp
}

class AiAgentSession {
  final AiAgentData agentData;
  final DateTime startTime;
  final String uid;          // User identifier
}

enum AiAgentState {
  idle,                      // No active session
  starting,                  // Session initiation in progress
  running,                   // Active session with AI agent
  stopping,                  // Session termination in progress
  error,                     // Error state with recovery options
}
```

**Design Principles**:
- Immutable data structures with factory constructors
- JSON serialization support for API integration
- Computed properties for derived values (e.g., `isRunning`, `elapsedTime`)
- Type-safe state enumeration

### 2. UI Layer (`features/ai_agent/screens/`)

#### ai_agent_screen.dart
```dart
class AiAgentScreen extends StatefulWidget {
  // Platform-adaptive UI implementation
  
  Widget build(BuildContext context) {
    return Consumer<AiAgentProvider>(
      builder: (context, provider, child) {
        return PopScope(
          canPop: !provider.isAgentRunning,  // Prevent back during calls
          child: Platform.isIOS 
              ? _buildCupertinoScreen(context, provider)
              : _buildMaterialScreen(context, provider),
        );
      },
    );
  }
}
```

**Key Features**:
- **Platform Adaptation**: Separate iOS (Cupertino) and Android (Material) implementations
- **State-Driven UI**: Consumer pattern for reactive updates
- **Navigation Protection**: Prevents accidental exit during active sessions
- **Animation Integration**: Flutter Animate for smooth transitions
- **Audio Control Interface**: Dedicated call controls with haptic feedback

**UI Component Structure**:
```
AiAgentScreen
├── Logo with Wave Animations
│   ├── Static logo (idle state)
│   ├── Concentric wave rings (active states)
│   └── AI speaking pulse indicators
├── Time Display
│   ├── Remaining time (idle)
│   └── Elapsed time (active)
├── Action Button (idle state)
│   ├── "Join AI Agent"
│   └── Loading states
└── Call Controls (active state)
    ├── Microphone toggle
    ├── End call button
    └── Speaker toggle
```

### 3. State Management (`features/ai_agent/providers/`)

#### ai_agent_provider.dart
```dart
class AiAgentProvider extends ChangeNotifier {
  // State management for AI agent operations
  
  // Core state properties
  AiAgentState _state = AiAgentState.idle;
  AiAgentSession? _currentSession;
  String? _errorMessage;
  int _remainingTimeSeconds = 0;
  
  // Audio control states
  bool _isMicrophoneMuted = false;
  bool _isSpeakerEnabled = true;
  bool _isAiSpeaking = false;
  
  // Resource management
  Timer? _usageTimer;
  Timer? _firebaseSyncTimer;
  StreamSubscription<int>? _timeStreamSubscription;
}
```

**State Management Patterns**:

1. **Two-Phase Session Start**: 
   ```dart
   startAgent() {
     // Phase 1: Immediate UI update after Agora join
     joinAgoraChannelOnly() → Update UI to "starting"
     
     // Phase 2: Background AI agent connection
     connectAiAgentInBackground() → Update UI to "running"
   }
   ```

2. **Real-Time Time Tracking**:
   ```dart
   _startUsageTracking() {
     // Local UI updates every second
     _usageTimer = Timer.periodic(Duration(seconds: 1), ...);
     
     // Firebase sync every 5 seconds
     _firebaseSyncTimer = Timer.periodic(Duration(seconds: 5), ...);
   }
   ```

3. **Audio State Synchronization**:
   ```dart
   toggleMicrophone() async {
     await _repository.toggleMicrophone();
     _isMicrophoneMuted = await _repository.isMicrophoneMutedAsync();
     notifyListeners();
   }
   ```

### 4. Business Logic (`core/repositories/`)

#### ai_agent_repository.dart
```dart
class AiAgentRepository {
  // Orchestrates AI agent operations with proper resource management
  
  Future<Map<String, dynamic>?> joinAgentWithFullSetup({
    required String uid,
  }) async {
    // 1. Validate user has remaining time
    // 2. Setup Agora channel with audio scenario
    // 3. Connect backend AI agent
    // 4. Return response data or null
  }
  
  Future<bool> stopAgentWithFullCleanup({
    required String agentId,
    required String uid,
    required int timeUsedSeconds,
  }) async {
    // 1. Stop backend AI agent
    // 2. Leave Agora channel
    // 3. Update user's remaining time
    // 4. Clean up all resources
  }
}
```

**Repository Responsibilities**:
- **Orchestration**: Coordinates multiple services for complex operations
- **Data Validation**: Ensures user eligibility and data consistency
- **Error Recovery**: Handles partial failures with appropriate cleanup
- **Resource Management**: Manages lifecycle of audio and network resources

### 5. Service Layer (`core/services/`)

#### ai_agent_service.dart
```dart
class AiAgentService implements AiAgentServiceInterface {
  // Core service for AI agent operations
  
  Future<Map<String, dynamic>?> joinAgentWithAgoraSetup({
    required String uid,
  }) async {
    // 1. Create channel name: "ai_{uid}"
    // 2. Get Agora token from backend
    // 3. Initialize Agora engine
    // 4. Join channel with AI audio scenario
    // 5. Wait 500ms for channel stability
    // 6. Validate user time eligibility
    // 7. Call backend AI agent API
    // 8. Return agent response data
  }
}
```

**Service Integration Points**:
```
AiAgentService Dependencies:
├── ApiService (HTTP operations)
├── AgoraTokenService (token generation)
├── AgoraService (RTC operations)
├── UserService (time management)
├── FirebaseDatabaseService (real-time data)
└── LoggerService (observability)
```

### 6. Exception Handling (`core/exceptions/`)

#### ai_agent_exceptions.dart
```dart
class AiAgentException implements Exception {
  final String code;                    // Error categorization
  final String message;                 // Human-readable description
  final dynamic originalError;          // Source error for debugging
  final AiAgentOperation? operation;    // Context of failure
}

class AiAgentErrorCodes {
  // Comprehensive error code definitions
  static const String joinFailed = 'ai-agent/join-failed';
  static const String stopFailed = 'ai-agent/stop-failed';
  static const String insufficientTime = 'ai-agent/insufficient-time';
  static const String networkError = 'ai-agent/network-error';
  // ... additional error codes
}
```

**Exception Architecture**:
- **Hierarchical Error Codes**: Structured error categorization
- **Context Preservation**: Maintains operation context for debugging
- **Factory Methods**: Convenient exception creation for common scenarios
- **Error Recovery**: Provides actionable error information

## Component Communication Patterns

### 1. UI → Provider → Repository → Service

```dart
// UI Layer
onPressed: () => provider.startAgent()

// Provider Layer  
startAgent() → repository.joinAgentWithFullSetup()

// Repository Layer
joinAgentWithFullSetup() → service.joinAgentWithAgoraSetup()

// Service Layer
joinAgentWithAgoraSetup() → [ApiService, AgoraService, UserService]
```

### 2. Real-Time Data Flow

```dart
// Firebase → Service → Provider → UI
FirebaseDatabase
  ↓ (real-time stream)
AiAgentService.getUserRemainingTimeStream()
  ↓ (stream subscription)
AiAgentProvider._timeStreamSubscription
  ↓ (notifyListeners)
AiAgentScreen (Consumer<AiAgentProvider>)
```

### 3. Error Propagation

```dart
// Service Layer (throws)
throw AiAgentExceptions.joinFailed(reason);

// Repository Layer (catches & handles)
try {
  await service.operation();
} catch (e) {
  logger.error(e);
  return null; // or rethrow based on context
}

// Provider Layer (updates UI state)
try {
  await repository.operation();
} catch (e) {
  _setError(e.message);
}
```

## Dependency Injection Patterns

### Service Locator Pattern
```dart
class AiAgentService {
  AiAgentService({
    ApiService? apiService,
    LoggerService? logger,
    // ... other dependencies
  }) : _apiService = apiService ?? serviceLocator<ApiService>(),
       _logger = logger ?? serviceLocator<LoggerService>();
}
```

### Provider Registration
```dart
// provider_registry.dart
MultiProvider(
  providers: [
    ChangeNotifierProvider<AiAgentProvider>(
      create: (_) => AiAgentProvider(),
    ),
    // ... other providers
  ],
)
```

## Resource Management Patterns

### 1. Automatic Cleanup
```dart
@override
void dispose() {
  // Cancel timers
  _stopUsageTracking();
  
  // Cancel stream subscriptions
  _timeStreamSubscription?.cancel();
  
  // Stop sensors
  _stopProximitySensor();
  
  // Dispose repository resources
  _repository.dispose();
  
  super.dispose();
}
```

### 2. Stream Controller Management
```dart
class AiAgentService {
  final Map<String, StreamController<int>> _timeStreamControllers = {};
  final Map<String, StreamSubscription> _timeStreamSubscriptions = {};
  
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _timeStreamSubscriptions.values) {
      subscription.cancel();
    }
    
    // Close all controllers
    for (final controller in _timeStreamControllers.values) {
      controller.close();
    }
  }
}
```

## Testing Architecture

### 1. Unit Test Structure
```dart
// Testable service with dependency injection
class AiAgentService {
  AiAgentService({
    required ApiService apiService,
    required LoggerService logger,
  });
}

// Test with mocked dependencies
test('should join agent successfully', () async {
  final mockApiService = MockApiService();
  final service = AiAgentService(
    apiService: mockApiService,
    logger: MockLoggerService(),
  );
  
  // Test implementation
});
```

### 2. Widget Test Patterns
```dart
testWidgets('should show loading state when starting agent', (tester) async {
  final mockProvider = MockAiAgentProvider();
  when(mockProvider.state).thenReturn(AiAgentState.starting);
  
  await tester.pumpWidget(
    ChangeNotifierProvider<AiAgentProvider>.value(
      value: mockProvider,
      child: AiAgentScreen(),
    ),
  );
  
  expect(find.text('Starting...'), findsOneWidget);
});
```

## Code Quality Patterns

### 1. Interface Segregation
```dart
abstract class AiAgentServiceInterface {
  Future<Map<String, dynamic>?> joinAgentWithAgoraSetup({required String uid});
  Future<bool> stopAgentAndLeaveChannel();
  // ... focused interface methods
}
```

### 2. Single Responsibility
- **Models**: Data structure definitions only
- **Providers**: State management and UI coordination
- **Repositories**: Business logic orchestration
- **Services**: Specific technology integration

### 3. Error Handling Consistency
```dart
// Consistent error handling pattern across layers
try {
  final result = await operation();
  _logger.i(_tag, 'Operation successful');
  return result;
} catch (e) {
  _logger.e(_tag, 'Operation failed: $e');
  if (e is SpecificException) rethrow;
  throw GeneralException('Operation failed', e);
}
```

## Performance Considerations

### 1. Efficient State Updates
```dart
// Targeted notifyListeners calls
void _updateSpecificState() {
  // Only notify when state actually changes
  if (_previousValue != _newValue) {
    _previousValue = _newValue;
    notifyListeners();
  }
}
```

### 2. Memory Management
```dart
// Proper resource disposal
void _disposeUserTimeStream(String uid) {
  _timeStreamSubscriptions.remove(uid)?.cancel();
  _timeStreamControllers.remove(uid)?.close();
}
```

### 3. Network Optimization
```dart
// Batch updates to reduce API calls
Timer.periodic(Duration(seconds: 5), (timer) {
  if (_hasChangesToSync) {
    _syncChangesToFirebase();
    _hasChangesToSync = false;
  }
});
```
