# AI Agent Backend Integration

This document details the integration between the DuckBuck Flutter app and the backend AI agent services, including API endpoints, authentication, and data flow patterns.

## API Endpoints

### 1. Join AI Agent
**Endpoint**: `POST /api/agora/ai-agent/join`

**Purpose**: Invites an AI agent to join a specific Agora channel for voice conversation

**Request Format**:
```json
{
  "uid": "firebase_user_uid",
  "channel_name": "ai_firebase_user_uid"
}
```

**Headers**:
```
Authorization: Bearer {firebase_id_token}
x-api-key: {backend_api_key}
Content-Type: application/json
```

**Success Response** (200):
```json
{
  "success": true,
  "message": "AI agent successfully joined channel",
  "data": {
    "agent_id": "agent_12345_timestamp",
    "agent_name": "AI Assistant",
    "channel_name": "ai_firebase_user_uid",
    "status": "started",
    "create_ts": 1699123456789
  }
}
```

**Error Responses**:
```json
// Authentication Error (401)
{
  "error": "Authentication failed - invalid Firebase token",
  "code": "AUTH_FAILED"
}

// Forbidden (403)
{
  "error": "Access forbidden - invalid API key",
  "code": "ACCESS_FORBIDDEN"
}

// Bad Request (400)
{
  "error": "Bad request - invalid parameters",
  "code": "BAD_REQUEST",
  "details": "Missing required field: uid"
}

// Service Unavailable (503)
{
  "error": "Service temporarily unavailable",
  "code": "SERVICE_UNAVAILABLE"
}
```

### 2. Stop AI Agent
**Endpoint**: `POST /api/agora/ai-agent/stop`

**Purpose**: Stops a running AI agent and removes it from the Agora channel

**Request Format**:
```json
{
  "agent_id": "agent_12345_timestamp"
}
```

**Headers**:
```
Authorization: Bearer {firebase_id_token}
x-api-key: {backend_api_key}
Content-Type: application/json
```

**Success Response** (200):
```json
{
  "success": true,
  "message": "AI agent successfully stopped"
}
```

**Error Response** (404):
```json
{
  "error": "AI agent not found or already stopped",
  "code": "AGENT_NOT_FOUND"
}
```

## Authentication Flow

### 1. Firebase ID Token Generation
```dart
// In ApiService
Future<String?> _getValidToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  try {
    // Force token refresh if needed
    final token = await user.getIdToken(true);
    return token;
  } catch (e) {
    _logger.e(_tag, 'Failed to get Firebase ID token: $e');
    return null;
  }
}
```

### 2. Token Usage in Requests
```dart
Future<Map<String, dynamic>?> joinAiAgent({
  required String uid,
  required String channelName,
}) async {
  final idToken = await _getValidToken();
  if (idToken == null) {
    throw const ApiException(
      'Authentication failed - unable to get Firebase token',
      statusCode: 401,
    );
  }
  
  final response = await _dio.post(
    '/api/agora/ai-agent/join',
    data: {'uid': uid, 'channel_name': channelName},
    options: Options(
      headers: {
        'Authorization': 'Bearer $idToken',
        'x-api-key': _apiKey,
      },
    ),
  );
}
```

## Integration Architecture

### 1. Request Flow
```
Flutter App
    ↓ (Firebase ID Token + API Key)
Backend API Gateway
    ↓ (Token Validation)
AI Agent Service
    ↓ (Agora Integration)
Agora RTC Platform
    ↓ (Audio Stream)
AI Processing Service
    ↓ (Voice Response)
Agora RTC Platform
    ↓ (Audio Stream)
Flutter App (User hears AI)
```

### 2. Channel Naming Convention
```dart
// Channel name format: "ai_{firebase_uid}"
final channelName = 'ai_$uid';

// Examples:
// User UID: "abc123def456"
// Channel: "ai_abc123def456"
```

### 3. Agent ID Format
```
// Backend generates agent IDs in format:
"agent_{random_id}_{timestamp}"

// Example:
"agent_xyz789_1699123456789"
```

## Error Handling Integration

### 1. Circuit Breaker Pattern
```dart
class ApiService {
  bool _isCircuitBreakerOpen = false;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  
  Future<T> _executeWithCircuitBreaker<T>(Future<T> Function() operation) async {
    if (_isCircuitBreakerOpen) {
      throw const ApiException(
        'Service temporarily unavailable due to circuit breaker',
        statusCode: 503,
        errorCode: 'CIRCUIT_BREAKER_OPEN',
      );
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
}
```

### 2. Rate Limiting Handling
```dart
Future<void> _handleRateLimit() async {
  final now = DateTime.now();
  if (_lastRequestTime != null) {
    final timeSinceLastRequest = now.difference(_lastRequestTime!);
    if (timeSinceLastRequest < _minRequestInterval) {
      final waitTime = _minRequestInterval - timeSinceLastRequest;
      await Future.delayed(waitTime);
    }
  }
  _lastRequestTime = now;
}
```

### 3. Exponential Backoff
```dart
Future<T> _retryWithBackoff<T>(
  Future<T> Function() operation,
  {int maxRetries = 3}
) async {
  int attempt = 0;
  while (attempt < maxRetries) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) rethrow;
      
      final delay = Duration(seconds: pow(2, attempt).toInt());
      await Future.delayed(delay);
    }
  }
  throw Exception('Max retries exceeded');
}
```

## Data Synchronization

### 1. Real-Time Time Tracking
```dart
// Client-side time tracking
class AiAgentProvider {
  void _startUsageTracking() {
    // Local UI updates (every second)
    _usageTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _remainingTimeSeconds--;
      notifyListeners();
    });
    
    // Firebase sync (every 5 seconds)
    _firebaseSyncTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _syncTimeToFirebase();
    });
  }
}
```

### 2. Firebase Integration
```dart
// Real-time time updates from Firebase
Stream<int> getUserRemainingTimeStream(String uid) {
  return _databaseService.documentStream(
    collection: 'users',
    documentId: uid,
  ).map((snapshot) {
    final userData = snapshot.data();
    return userData?['agentRemainingTime'] as int? ?? 0;
  });
}
```

## Security Considerations

### 1. Token Security
- Firebase ID tokens are automatically refreshed
- Tokens have short expiration times (1 hour)
- No long-lived credentials stored in app
- API keys are environment-specific

### 2. Request Validation
```dart
// Backend validates all requests
{
  "firebase_uid": "extracted_from_token",
  "api_key": "validated_against_environment",
  "request_params": "validated_for_format_and_content"
}
```

### 3. Channel Security
```dart
// Agora tokens are generated per-channel and user
final tokenResponse = await _agoraTokenService.generateToken(
  channelId: channelName,
  uid: uid, // Optional: backend can assign UID
);
```

## Performance Optimizations

### 1. Connection Pooling
```dart
// Dio HTTP client with connection pooling
final dio = Dio(BaseOptions(
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 30),
  persistentConnection: true,
));
```

### 2. Request Caching
```dart
// Token caching to avoid repeated Firebase calls
class TokenCache {
  String? _cachedToken;
  DateTime? _tokenExpiry;
  
  Future<String?> getValidToken() async {
    if (_cachedToken != null && 
        _tokenExpiry != null && 
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }
    
    // Refresh token
    return await _refreshToken();
  }
}
```

### 3. Batched Updates
```dart
// Batch time updates to reduce Firebase writes
class TimeUpdateBatcher {
  final Map<String, int> _pendingUpdates = {};
  Timer? _batchTimer;
  
  void scheduleUpdate(String uid, int timeUsed) {
    _pendingUpdates[uid] = (_pendingUpdates[uid] ?? 0) + timeUsed;
    
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration(seconds: 5), () async {
      await _flushUpdates();
    });
  }
}
```

## Monitoring and Observability

### 1. Request Logging
```dart
// Comprehensive request/response logging
void _logRequest(String method, String path, Map<String, dynamic>? data) {
  _logger.i(_tag, 'API Request: $method $path');
  if (data != null) {
    _logger.d(_tag, 'Request Data: ${jsonEncode(data)}');
  }
}

void _logResponse(Response response) {
  _logger.i(_tag, 'API Response: ${response.statusCode} ${response.statusMessage}');
  if (response.data != null) {
    _logger.d(_tag, 'Response Data: ${jsonEncode(response.data)}');
  }
}
```

### 2. Error Tracking
```dart
void _onRequestFailure() {
  _failureCount++;
  _lastFailureTime = DateTime.now();
  
  // Open circuit breaker after 5 consecutive failures
  if (_failureCount >= 5) {
    _isCircuitBreakerOpen = true;
    _logger.e(_tag, 'Circuit breaker opened due to consecutive failures');
    
    // Auto-reset after 1 minute
    Timer(Duration(minutes: 1), () {
      _isCircuitBreakerOpen = false;
      _failureCount = 0;
      _logger.i(_tag, 'Circuit breaker reset');
    });
  }
}
```

### 3. Performance Metrics
```dart
// Track API call performance
class ApiMetrics {
  void recordApiCall(String endpoint, Duration duration, bool success) {
    _logger.i(_tag, 'API Call: $endpoint took ${duration.inMilliseconds}ms, success: $success');
    
    // Send to analytics service
    _analyticsService.track('api_call', {
      'endpoint': endpoint,
      'duration_ms': duration.inMilliseconds,
      'success': success,
    });
  }
}
```

## Backend Service Architecture

### 1. Expected Backend Components
```
API Gateway
├── Authentication Middleware (Firebase token validation)
├── Rate Limiting Middleware
└── Request Routing

AI Agent Service
├── Agora Integration (channel management)
├── AI Model Integration (voice processing)
├── Session Management (agent lifecycle)
└── Error Handling

Database
├── User Management (time tracking)
├── Session Logs (audit trail)
└── Agent Metadata (active sessions)
```

### 2. Scaling Considerations
- **Horizontal Scaling**: Stateless service design allows for load balancing
- **Database Optimization**: Indexed queries for user lookups
- **Connection Pooling**: Efficient resource utilization
- **Caching**: Redis for frequently accessed data

### 3. Reliability Features
- **Health Checks**: Endpoint monitoring for service availability
- **Graceful Degradation**: Partial functionality during service issues
- **Auto-Recovery**: Automatic restart of failed services
- **Backup Systems**: Redundant infrastructure for high availability

## Testing Integration

### 1. Mock Backend for Development
```dart
class MockApiService implements ApiService {
  @override
  Future<Map<String, dynamic>?> joinAiAgent({
    required String uid,
    required String channelName,
  }) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500));
    
    // Return mock successful response
    return {
      'success': true,
      'data': {
        'agent_id': 'mock_agent_${DateTime.now().millisecondsSinceEpoch}',
        'agent_name': 'Mock AI Assistant',
        'channel_name': channelName,
        'status': 'started',
        'create_ts': DateTime.now().millisecondsSinceEpoch,
      }
    };
  }
}
```

### 2. Integration Testing
```dart
group('AI Agent Backend Integration', () {
  test('should successfully join AI agent', () async {
    final apiService = ApiService(baseUrl: testServerUrl);
    
    final response = await apiService.joinAiAgent(
      uid: testUserId,
      channelName: 'ai_$testUserId',
    );
    
    expect(response, isNotNull);
    expect(response!['success'], isTrue);
    expect(response['data']['agent_id'], isNotNull);
  });
});
```
