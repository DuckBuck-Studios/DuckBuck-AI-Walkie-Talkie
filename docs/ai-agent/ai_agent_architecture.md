# AI Agent Architecture

This document outlines the architecture and design patterns of the AI Agent system in DuckBuck.

## System Overview

The AI Agent system enables real-time voice conversations between users and an AI assistant through a multi-layered architecture that handles audio communication, time management, and state synchronization.

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
├─────────────────────────────────────────────────────────────┤
│  AiAgentScreen (iOS/Android) │ Call Controls │ Animations   │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    State Management                         │
├─────────────────────────────────────────────────────────────┤
│           AiAgentProvider (ChangeNotifier)                  │
│  • Session state tracking    • Time management              │
│  • Audio control states      • Real-time updates           │
│  • Error handling           • Resource lifecycle           │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  Business Logic Layer                       │
├─────────────────────────────────────────────────────────────┤
│                  AiAgentRepository                          │
│  • Session orchestration    • Time calculations            │
│  • Full setup/cleanup      • User data integration         │
│  • Error recovery          • Audio state management        │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                            │
├───────────────────┬───────────────────┬─────────────────────┤
│   AiAgentService  │    UserService    │   SensorService     │
│ • Agora integration│ • Time tracking   │ • Proximity detect │
│ • Backend API calls│ • User data mgmt  │ • Screen control   │
│ • Audio controls   │ • Firebase sync   │ • Audio scenarios  │
└───────────────────┴───────────────────┴─────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                      │
├───────────────────┬───────────────────┬─────────────────────┤
│    ApiService     │  AgoraService     │ FirebaseDatabase    │
│ • HTTP requests   │ • RTC engine      │ • Real-time sync   │
│ • Authentication  │ • Audio routing   │ • User data store  │
│ • Error handling  │ • Channel mgmt    │ • Stream listening │
└───────────────────┴───────────────────┴─────────────────────┘
```

## Core Components

### 1. AiAgentProvider (State Management)

**Responsibility**: Central state management for AI agent operations

**Key Features**:
- Session lifecycle management (`idle` → `starting` → `running` → `stopping`)
- Real-time time tracking with Firebase synchronization
- Audio control state management (microphone, speaker)
- Proximity sensor integration for earpiece mode
- Error state handling and recovery

**State Flow**:
```
┌─────────┐    startAgent()    ┌──────────┐    backend connects    ┌─────────┐
│  IDLE   ├──────────────────→│ STARTING ├─────────────────────→│ RUNNING │
└─────────┘                   └──────────┘                       └─────────┘
     ▲                             │                                   │
     │                             │ (on error)                       │
     │         stopAgent()         ▼                                   │
     └─────────────────────────┌───────┐◄──────────────────────────────┘
                               │ ERROR │        stopAgent()
                               └───────┘
```

### 2. AiAgentRepository (Business Logic)

**Responsibility**: Orchestrates AI agent operations with proper resource management

**Key Methods**:
- `joinAgentWithFullSetup()`: Complete Agora + backend AI agent setup
- `stopAgentWithFullCleanup()`: Proper session termination with time updates
- `joinAgoraChannelOnly()`: Agora-only connection for immediate UI feedback
- `joinAiAgentOnly()`: Backend AI agent connection after Agora setup

**Architecture Pattern**: Repository pattern abstracting business logic from UI and services

### 3. AiAgentService (Core Service)

**Responsibility**: Direct integration with Agora RTC and backend API

**Key Features**:
- Agora engine initialization and channel management
- Token-based authentication with backend
- Audio control operations (mic/speaker toggle)
- Real-time time stream management with Firebase
- Automatic cleanup and resource disposal

### 4. Data Models

#### AiAgentResponse
```dart
class AiAgentResponse {
  final bool success;
  final String message;
  final AiAgentData? data;
}
```

#### AiAgentData
```dart
class AiAgentData {
  final String agentId;      // Backend agent identifier
  final String agentName;    // Human-readable agent name
  final String channelName;  // Agora channel name
  final String status;       // Agent status (started/stopped)
  final int createTs;        // Creation timestamp
}
```

#### AiAgentSession
```dart
class AiAgentSession {
  final AiAgentData agentData;
  final DateTime startTime;
  final String uid;          // User identifier
}
```

## Data Flow Patterns

### 1. Session Start Flow

```
User Tap "Join" 
    ↓
Provider.startAgent()
    ↓
Repository.joinAgentWithFullSetup()
    ↓
┌─ Service.joinAgoraChannelOnly() ── Immediate UI Update ──┐
│                                                          │
│  ┌─ Get Agora Token                                      │
│  ├─ Initialize Agora Engine                              │
│  ├─ Join Channel with AI scenario                        │
│  └─ Update UI to "starting" state                        │
│                                                          │
└─ Service.joinAiAgentOnly() ── Background Connection ─────┤
                                                           │
   ┌─ Validate user time                                   │
   ├─ Call backend API                                     │
   ├─ Get real agent data                                  │
   └─ Update session with backend response                 │
                                                           ▼
                                               UI shows "running" state
```

### 2. Time Management Flow

```
Session Start
    ↓
Start Local Timer (1 second intervals)
    ↓
┌─ Update UI time display
├─ Check for time expiration  
└─ Auto-stop if time = 0
    ↓
Start Firebase Sync Timer (5 second intervals)
    ↓
┌─ Calculate time used since last sync
├─ Update Firebase with remaining time
└─ Handle sync errors gracefully
    ↓
Real-time Firebase Stream
    ↓
┌─ Listen to time changes
├─ Update UI immediately
└─ Trigger auto-stop if needed
```

### 3. Audio Control Flow

```
User Toggle Mic/Speaker
    ↓
Provider Audio Method
    ↓
Repository Audio Method
    ↓
Service Audio Method
    ↓
┌─ Call Agora SDK method
├─ Get actual audio state
└─ Update provider state
    ↓
Proximity Sensor Update
    ↓
┌─ Start sensor if earpiece mode
├─ Stop sensor if speaker mode  
└─ Update screen control behavior
    ↓
UI State Update
```

## Error Handling Architecture

### Exception Hierarchy

```
AiAgentException
├─ Network Errors (API failures)
├─ Authentication Errors (token issues)
├─ Time Management Errors (insufficient time)
├─ Agora Errors (RTC failures)
├─ Backend Errors (AI agent failures)
└─ Stream Errors (Firebase sync issues)
```

### Error Recovery Patterns

1. **Circuit Breaker**: Prevents cascading failures in API service
2. **Graceful Degradation**: UI remains functional even with backend failures
3. **Automatic Cleanup**: Resources are cleaned up on any error
4. **State Recovery**: Provider returns to safe states on errors
5. **User Feedback**: Clear error messages with actionable guidance

## Performance Optimizations

### 1. Memory Management
- Automatic disposal of stream controllers and subscriptions
- Timer cleanup on session end
- Proximity sensor resource management
- Animation controller lifecycle management

### 2. Network Optimization
- Token caching and reuse
- Rate limiting with exponential backoff
- Connection pooling in HTTP client
- Minimal data payloads

### 3. UI Performance
- Efficient animation patterns with `flutter_animate`
- Conditional rendering based on states
- Platform-specific optimizations (iOS/Android)
- Reduced rebuild frequency with targeted `notifyListeners()`

## Security Considerations

### 1. Authentication
- Firebase ID token authentication for all API calls
- API key validation on backend
- Automatic token refresh handling

### 2. Data Protection
- Encrypted audio transmission through Agora
- Secure channel name generation
- No sensitive data in logs or error messages

### 3. Access Control
- Time-based usage limits
- User-specific session isolation
- Backend validation of all requests

## Scalability Design

### 1. Horizontal Scaling
- Stateless service design
- Database-independent time tracking
- Load balancer compatibility

### 2. Resource Efficiency
- Connection pooling and reuse
- Lazy loading of resources
- Memory-efficient stream handling

### 3. Monitoring and Observability
- Comprehensive logging at all layers
- Error tracking and reporting
- Performance metrics collection
