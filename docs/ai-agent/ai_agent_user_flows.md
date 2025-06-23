# AI Agent User Flows

This document describes the key user interaction flows within the AI Agent feature, from initial setup to session completion.

## Primary User Flows

### 1. First-Time AI Agent Access

```
┌─ User opens AI Agent screen
│
├─ Provider initializes with user UID
│  ├─ Fetch user's remaining time from Firebase
│  ├─ Setup real-time time stream listener
│  └─ Display current time allowance
│
├─ User sees welcome interface
│  ├─ AI Assistant logo with no animations
│  ├─ Time display: "Time: 1h 0m" (default allowance)
│  └─ "Join AI Agent" button (enabled)
│
└─ User ready to start first session
```

### 2. Starting an AI Agent Session

```
┌─ User taps "Join AI Agent" button
│
├─ Provider changes state: IDLE → STARTING
│  ├─ Button shows loading state: "Starting..."  
│  ├─ Logo begins wave animations
│  └─ UI provides immediate feedback
│
├─ Agora Channel Setup (Priority 1 - Fast UI Update)
│  ├─ Generate channel name: "ai_{userUid}"
│  ├─ Request Agora token from backend
│  ├─ Initialize Agora RTC engine
│  ├─ Join Agora channel with AI audio scenario
│  └─ UI immediately shows "Connecting..." state
│
├─ Session Creation (Immediate)
│  ├─ Create temporary AiAgentSession object
│  ├─ Initialize audio control states
│  ├─ Start usage tracking timers
│  ├─ Enable proximity sensor (if earpiece mode)
│  └─ Display call controls interface
│
├─ Backend AI Agent Connection (Background)
│  ├─ Validate user has remaining time
│  ├─ Call backend API: POST /api/agora/ai-agent/join
│  ├─ Receive real agent data (agentId, status)
│  ├─ Update session with backend response
│  └─ Provider state: STARTING → RUNNING
│
└─ Session Active
   ├─ UI shows "running" state with full controls
   ├─ Time tracking: elapsed time display
   ├─ Audio controls: mute, speaker, end call
   └─ AI speaking indicators and animations
```

### 3. Active AI Agent Session

```
┌─ Session Running State
│
├─ Real-Time UI Updates
│  ├─ Elapsed time: "Elapsed: 2:34"
│  ├─ Wave animations around logo
│  ├─ AI speaking indicators (random patterns)
│  └─ Responsive audio control states
│
├─ Audio Control Interactions
│  ├─ Microphone toggle
│  │  ├─ User taps mic button
│  │  ├─ Haptic feedback
│  │  ├─ Call Agora SDK toggle method
│  │  ├─ Update button visual state
│  │  └─ Maintain session continuity
│  │
│  └─ Speaker toggle
│     ├─ User taps speaker button
│     ├─ Toggle between earpiece/speaker mode
│     ├─ Update proximity sensor behavior
│     │  ├─ Earpiece: Enable proximity detection
│     │  └─ Speaker: Disable proximity detection
│     └─ Update button visual state
│
├─ Proximity Sensor Behavior (Earpiece Mode)
│  ├─ Phone near ear → Screen dims automatically
│  ├─ Phone away from ear → Screen brightens
│  └─ No manual intervention required
│
├─ Time Management
│  ├─ Local timer decrements every second
│  ├─ Firebase sync every 5 seconds
│  ├─ Real-time stream updates from Firebase
│  └─ Auto-stop warning when low time
│
└─ Background Processing
   ├─ Continuous audio streaming through Agora
   ├─ AI agent processing on backend
   ├─ Session state synchronization
   └─ Error monitoring and recovery
```

### 4. Session Termination Flows

#### 4a. User-Initiated Session End
```
┌─ User taps "End Call" button
│
├─ Provider state: RUNNING → STOPPING
│  ├─ Disable all audio controls
│  ├─ Show "Stopping..." state
│  └─ Begin cleanup process
│
├─ Backend Agent Stop
│  ├─ Call API: POST /api/agora/ai-agent/stop
│  ├─ Send agentId from current session
│  └─ Wait for backend confirmation
│
├─ Agora Channel Cleanup
│  ├─ Leave Agora RTC channel
│  ├─ Release audio resources
│  └─ Stop proximity sensor
│
├─ Time Update
│  ├─ Calculate total session duration
│  ├─ Update user's remaining time in Firebase
│  └─ Sync final time values
│
├─ Resource Cleanup
│  ├─ Cancel all timers
│  ├─ Close stream controllers
│  ├─ Clear session data
│  └─ Reset UI state
│
└─ Return to Idle
   ├─ Provider state: STOPPING → IDLE
   ├─ Display updated remaining time
   ├─ Enable "Join AI Agent" button (if time remains)
   └─ Stop all animations
```

#### 4b. Automatic Session End (Time Expired)
```
┌─ Time tracking detects remaining time = 0
│
├─ Automatic trigger from multiple sources:
│  ├─ Local timer countdown
│  ├─ Firebase real-time stream update
│  └─ Auto-stop timer expiration
│
├─ Provider automatically calls stopAgent()
│  ├─ User sees immediate UI feedback
│  ├─ Same cleanup process as manual stop
│  └─ No user interaction required
│
├─ Post-Session State
│  ├─ Time display: "Time: 0:00"
│  ├─ "Join AI Agent" button disabled
│  ├─ Message: "No remaining AI agent time"
│  └─ Options to purchase more time (future)
│
└─ Session completely terminated
```

### 5. Error Handling Flows

#### 5a. Connection Failure During Start
```
┌─ User attempts to start session
│
├─ Agora connection fails OR Backend API fails
│  ├─ Provider state: STARTING → ERROR
│  ├─ Automatic cleanup of partial resources
│  └─ User sees error message
│
├─ Error Recovery Options
│  ├─ "Retry" button to attempt again
│  ├─ "Cancel" to return to idle state
│  └─ Automatic retry with exponential backoff
│
└─ User Experience
   ├─ Clear error messaging
   ├─ No stuck states or loading screens
   └─ Graceful fallback to previous state
```

#### 5b. Session Interruption
```
┌─ Active session encounters error
│  ├─ Network connectivity loss
│  ├─ Backend service failure
│  └─ Agora RTC issues
│
├─ Error Handling
│  ├─ Preserve user's time investment
│  ├─ Automatic session state save
│  ├─ Background reconnection attempts
│  └─ User notification of issues
│
├─ Recovery Scenarios
│  ├─ Successful reconnection → Resume session
│  ├─ Partial recovery → Continue with limitations
│  └─ Complete failure → Clean termination
│
└─ User Communication
   ├─ Real-time status updates
   ├─ Clear recovery instructions
   └─ Time credit preservation when possible
```

### 6. Platform-Specific Behaviors

#### 6a. iOS (Cupertino) Experience
```
┌─ Native iOS UI patterns
│  ├─ CupertinoPageScaffold and CupertinoNavigationBar
│  ├─ Cupertino buttons and activity indicators
│  ├─ iOS-style alert dialogs
│  └─ System color palette integration
│
├─ iOS-Specific Features
│  ├─ Haptic feedback on interactions
│  ├─ Native proximity sensor integration
│  ├─ iOS audio session management
│  └─ Background app state handling
│
└─ iOS User Flow Differences
   ├─ CupertinoAlertDialog for errors
   ├─ iOS-style loading indicators
   └─ Native navigation patterns
```

#### 6b. Android (Material) Experience
```
┌─ Material Design 3 patterns
│  ├─ Material Scaffold and AppBar
│  ├─ Material buttons and progress indicators
│  ├─ Material alert dialogs
│  └─ Theme-based color system
│
├─ Android-Specific Features
│  ├─ Material haptic feedback patterns
│  ├─ Android proximity sensor handling
│  ├─ Android audio focus management
│  └─ Android lifecycle awareness
│
└─ Android User Flow Differences
   ├─ SnackBar for error notifications
   ├─ Material progress indicators
   └─ Android navigation behaviors
```

## User Experience Principles

### 1. Immediate Feedback
- UI updates happen before network operations complete
- Loading states provide clear progress indication
- User actions always produce immediate visual response

### 2. Graceful Degradation
- System remains functional even with partial failures
- Audio controls work independently of backend connection
- Time tracking continues even during network issues

### 3. Resource Preservation
- User's time investment is protected during errors
- Session state is preserved during brief interruptions
- Automatic cleanup prevents resource leaks

### 4. Clear Communication
- Real-time status updates throughout the session
- Error messages provide actionable guidance
- Time remaining is always visible and accurate

### 5. Platform Consistency
- Native UI patterns for each platform
- Platform-appropriate feedback mechanisms
- Consistent behavior across iOS and Android

## Accessibility Considerations

### 1. Screen Reader Support
- Semantic labels for all interactive elements
- Dynamic content announcements for state changes
- Clear focus management during state transitions

### 2. Motor Accessibility
- Large touch targets for audio controls
- Alternative ways to access all functionality
- Reduced motion options for animations

### 3. Cognitive Accessibility
- Simple, clear interface with minimal cognitive load
- Consistent interaction patterns
- Clear visual hierarchy and information organization

## Performance Considerations

### 1. Startup Performance
- Lazy loading of resources until needed
- Efficient state initialization
- Minimal blocking operations

### 2. Runtime Performance
- Efficient animation patterns
- Optimized timer usage
- Memory-conscious resource management

### 3. Network Efficiency
- Minimal API calls during active session
- Efficient data synchronization
- Graceful handling of poor connectivity
