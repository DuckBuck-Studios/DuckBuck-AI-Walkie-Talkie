# Walkie-Talkie User Flows - Enhanced v2.0

This document describes the comprehensive user flows for the walkie-talkie system in the DuckBuck application. These flows illustrate the complete journey from call initiation through FCM processing to audio communication, including the Kotlin service layer, Agora RTC integration, background processing, and notification system.

## Architecture Flow Integration

The user flows incorporate all the enhanced features from the DuckBuck walkie-talkie architecture v2.0:

- **Foreground Service Architecture**: Persistent background processing with WalkieTalkieService
- **Simplified Call State Management**: Optimized state machine (JOINING → ACTIVE → ENDING → ENDED)
- **Advanced FCM Processing**: Smart message handling with app state detection
- **Agora RTC Integration**: Professional real-time audio communication
- **Cross-Platform Bridge**: Seamless Flutter-Kotlin communication
- **Smart Notification System**: Speaker detection with self-filtering
- **Audio Management**: Professional audio routing and hardware integration
- **Performance Optimization**: Memory management and battery efficiency

## User Flow Diagrams

### Complete Walkie-Talkie Call Flow

```mermaid
sequenceDiagram
    actor UserA as User A (Caller)
    actor UserB as User B (Receiver)
    participant FlutterA as Flutter UI (A)
    participant BridgeA as Bridge Layer (A)
    participant KotlinA as Kotlin Service (A)
    participant AgoraA as Agora SDK (A)
    participant FCM as Firebase FCM
    participant FlutterB as Flutter UI (B)
    participant BridgeB as Bridge Layer (B)
    participant KotlinB as Kotlin Service (B)
    participant AgoraB as Agora SDK (B)
    participant NotifB as Notification (B)
    
    %% Call Initiation (User A)
    UserA->>FlutterA: Selects friend to call
    FlutterA->>FlutterA: Show call screen
    FlutterA->>BridgeA: joinChannel(channelId, token, uid)
    BridgeA->>KotlinA: Process join request
    
    %% Kotlin Service Setup (User A)
    KotlinA->>KotlinA: Start WalkieTalkieService
    KotlinA->>KotlinA: Acquire wake lock
    KotlinA->>KotlinA: saveIncomingCallData(JOINING)
    KotlinA->>AgoraA: Join Agora channel
    AgoraA-->>KotlinA: Channel joined successfully
    KotlinA->>KotlinA: markCallAsJoined(ACTIVE)
    KotlinA->>KotlinA: Show persistent notification
    
    %% FCM Notification (User A → User B)
    KotlinA->>FCM: Send call FCM to User B
    FCM->>KotlinB: FCM message received
    
    %% FCM Processing (User B)
    KotlinB->>KotlinB: FcmServiceOrchestrator processes FCM
    KotlinB->>KotlinB: FcmDataHandler extracts call data
    KotlinB->>KotlinB: FcmAppStateDetector checks app state
    
    alt App in Foreground
        KotlinB->>FlutterB: Trigger call UI via CallUITrigger
        FlutterB->>FlutterB: Show incoming call screen
    else App in Background/Killed
        KotlinB->>NotifB: Show call notification
    end
    
    %% Auto-Connect (User B)
    KotlinB->>KotlinB: saveIncomingCallData(JOINING)
    KotlinB->>KotlinB: Start WalkieTalkieService
    KotlinB->>KotlinB: Acquire wake lock
    KotlinB->>AgoraB: Auto-join Agora channel
    AgoraB-->>KotlinB: Channel joined successfully
    KotlinB->>KotlinB: markCallAsJoined(ACTIVE)
    KotlinB->>KotlinB: Show persistent notification
    
    %% Active Communication Loop
    loop During Call
        %% User A speaks
        UserA->>FlutterA: Press push-to-talk
        FlutterA->>BridgeA: enableMicrophone()
        BridgeA->>KotlinA: Enable audio transmission
        KotlinA->>AgoraA: Start audio stream
        AgoraA->>AgoraB: Audio transmission
        AgoraB->>KotlinB: Audio received
        KotlinB->>KotlinB: Detect speaker (User A)
        KotlinB->>NotifB: Show "User A is speaking" notification
        AgoraB->>FlutterB: Audio output
        
        UserA->>FlutterA: Release push-to-talk
        FlutterA->>BridgeA: disableMicrophone()
        BridgeA->>KotlinA: Disable audio transmission
        KotlinA->>AgoraA: Stop audio stream
        KotlinB->>NotifB: Hide speaker notification
        
        %% User B speaks
        UserB->>FlutterB: Press push-to-talk
        FlutterB->>BridgeB: enableMicrophone()
        BridgeB->>KotlinB: Enable audio transmission
        KotlinB->>AgoraB: Start audio stream
        AgoraB->>AgoraA: Audio transmission
        AgoraA->>KotlinA: Audio received
        KotlinA->>KotlinA: Detect speaker (User B) - NO notification (self-filter)
        AgoraA->>FlutterA: Audio output
        
        UserB->>FlutterB: Release push-to-talk
        FlutterB->>BridgeB: disableMicrophone()
        BridgeB->>KotlinB: Disable audio transmission
        KotlinB->>AgoraB: Stop audio stream
    end
    
    %% Call Termination (User A ends call)
    UserA->>FlutterA: End call button
    FlutterA->>BridgeA: leaveChannel()
    BridgeA->>KotlinA: Process leave request
    KotlinA->>KotlinA: markCallAsEnding(ENDING)
    KotlinA->>AgoraA: Leave Agora channel
    AgoraA-->>KotlinA: Channel left
    KotlinA->>KotlinA: markCallAsEnded(ENDED)
    KotlinA->>KotlinA: Clear call data
    KotlinA->>KotlinA: Release wake lock
    KotlinA->>KotlinA: Stop WalkieTalkieService
    FlutterA->>FlutterA: Return to home screen
    
    %% Auto-disconnect (User B)
    AgoraB->>KotlinB: Channel left (User A disconnected)
    KotlinB->>KotlinB: markCallAsEnding(ENDING)
    KotlinB->>AgoraB: Leave Agora channel
    AgoraB-->>KotlinB: Channel left
    KotlinB->>KotlinB: markCallAsEnded(ENDED)
    KotlinB->>KotlinB: Clear call data
    KotlinB->>KotlinB: Release wake lock
    KotlinB->>KotlinB: Stop WalkieTalkieService
    FlutterB->>FlutterB: Return to home screen
```

### FCM Processing Flow - Background App Handling

```mermaid
sequenceDiagram
    participant FCM as Firebase FCM
    participant KotlinSvc as Kotlin Service
    participant FDH as FcmDataHandler
    participant FASD as FcmAppStateDetector
    participant CSPM as CallStatePersistenceManager
    participant WTS as WalkieTalkieService
    participant Agora as Agora SDK
    participant NotifMgr as NotificationManager
    participant FlutterUI as Flutter UI
    
    FCM->>KotlinSvc: FCM message received
    KotlinSvc->>FDH: extractCallData(remoteMessage)
    
    %% Data Validation
    FDH->>FDH: Validate FCM payload
    alt Valid Call Data
        FDH-->>KotlinSvc: CallData(token, uid, channelId, etc.)
    else Invalid Data
        FDH-->>KotlinSvc: null
        KotlinSvc->>KotlinSvc: Log error and ignore
    end
    
    %% App State Detection
    KotlinSvc->>FASD: isAppInForeground(context)
    FASD->>FASD: Check ActivityManager
    FASD-->>KotlinSvc: App state (foreground/background)
    
    alt App in Foreground
        KotlinSvc->>FlutterUI: Trigger incoming call screen
        FlutterUI->>FlutterUI: Show call interface
    else App in Background/Killed
        KotlinSvc->>NotifMgr: Show incoming call notification
        NotifMgr->>NotifMgr: Display call notification
    end
    
    %% Auto-Connect Process
    KotlinSvc->>CSPM: saveIncomingCallData(callData)
    CSPM->>CSPM: Store call data with JOINING state
    CSPM-->>KotlinSvc: Data saved
    
    KotlinSvc->>WTS: Start WalkieTalkieService
    WTS->>WTS: Acquire wake lock
    WTS->>WTS: Create foreground notification
    WTS->>Agora: Join channel with call data
    
    Agora-->>WTS: Channel join success
    WTS->>CSPM: markCallAsJoined(ACTIVE)
    CSPM->>CSPM: Update state to ACTIVE
    WTS->>WTS: Update notification status
    
    %% Background Processing Ready
    WTS->>WTS: Service running in background
    Note over WTS: Ready for audio communication<br/>even if app is killed
```

### Audio Management Flow

```mermaid
sequenceDiagram
    participant User
    participant FlutterUI as Flutter UI
    participant Bridge as Bridge Layer
    participant Kotlin as Kotlin Service
    participant VAM as VolumeAcquireManager
    participant AM as Android AudioManager
    participant Agora as Agora SDK
    participant Hardware as Audio Hardware
    
    %% Audio Setup on Call Start
    Kotlin->>VAM: acquireAudioFocus()
    VAM->>AM: requestAudioFocus()
    AM-->>VAM: Audio focus granted
    VAM-->>Kotlin: Audio focus acquired
    
    Kotlin->>Agora: Configure audio settings
    Agora->>Agora: Set audio scenario (CHATROOM_ENTERTAINMENT)
    Agora->>Agora: Set channel profile (COMMUNICATION)
    Agora->>Hardware: Initialize audio hardware
    
    %% Push-to-Talk Activation
    User->>FlutterUI: Press push-to-talk button
    FlutterUI->>Bridge: enableMicrophone()
    Bridge->>Kotlin: Enable audio transmission
    Kotlin->>Agora: enableLocalAudio(true)
    Agora->>Hardware: Activate microphone
    Hardware->>Agora: Audio input stream
    Agora->>Agora: Process and transmit audio
    
    %% Audio Reception
    Agora->>Agora: Receive remote audio
    Agora->>Hardware: Output to speaker/earpiece
    Hardware->>User: Audio playback
    
    %% Push-to-Talk Deactivation
    User->>FlutterUI: Release push-to-talk button
    FlutterUI->>Bridge: disableMicrophone()
    Bridge->>Kotlin: Disable audio transmission
    Kotlin->>Agora: enableLocalAudio(false)
    Agora->>Hardware: Deactivate microphone
    
    %% Audio Cleanup on Call End
    Kotlin->>Agora: Leave channel
    Agora->>Hardware: Release audio hardware
    Kotlin->>VAM: releaseAudioFocus()
    VAM->>AM: abandonAudioFocus()
    AM-->>VAM: Audio focus released
```

### Notification System Flow

```mermaid
sequenceDiagram
    participant Agora as Agora SDK
    participant Kotlin as Kotlin Service
    participant COM as ChannelOccupancyManager
    participant CNM as CallNotificationManager
    participant UNM as UniversalNotificationManager
    participant NM as Android NotificationManager
    participant User
    
    %% Speaker Detection
    Agora->>Kotlin: onUserJoined(uid, elapsed)
    Kotlin->>COM: User joined channel
    COM->>COM: Track user presence
    
    Agora->>Kotlin: onActiveSpeaker(uid)
    Kotlin->>COM: activeSpeaker detected
    COM->>COM: Identify speaker
    
    alt Speaker is Remote User (not self)
        COM->>CNM: showSpeakerNotification(username, photo)
        CNM->>CNM: Build notification with speaker info
        CNM->>UNM: displayNotification(notification)
        UNM->>NM: Show notification
        NM->>User: Display "UserX is speaking"
        
        %% Auto-hide after speaking stops
        Agora->>Kotlin: onActiveSpeaker(null) // Speaking stopped
        Kotlin->>CNM: hideSpeakerNotification()
        CNM->>UNM: hideNotification()
        UNM->>NM: Dismiss notification
    else Speaker is Self
        COM->>COM: Do nothing (self-filter)
        Note over COM: No notification for own voice
    end
    
    %% Persistent Call Status
    loop During Active Call
        Kotlin->>UNM: Update persistent notification
        UNM->>UNM: Show "In walkie-talkie call"
        UNM->>NM: Display ongoing notification
        Note over NM: Prevents service from being killed
    end
```

## Key User Experience Features

### 1. Seamless Background Operation
- **Auto-Connect**: Incoming calls connect automatically via FCM
- **Background Persistence**: WalkieTalkieService keeps calls active when app is backgrounded
- **Wake Lock Management**: Ensures device stays responsive during calls
- **Battery Optimization**: Minimal power consumption when not actively speaking

### 2. Smart Notification System
- **Speaker Detection**: Shows who is currently speaking
- **Self-Filtering**: Never shows notifications for user's own voice
- **Rich Notifications**: Displays speaker name and profile photo
- **Persistent Status**: Ongoing notification shows call status

### 3. Professional Audio Quality
- **Low Latency**: Optimized for real-time communication
- **Audio Focus**: Proper integration with Android audio system
- **Hardware Integration**: Works with Bluetooth, wired headsets
- **Echo Cancellation**: Built-in noise reduction and audio processing

### 4. Robust State Management
- **Simplified States**: JOINING → ACTIVE → ENDING → ENDED
- **Persistent Storage**: Call state survives app kills and device restarts
- **Error Recovery**: Automatic reconnection and error handling
- **Cross-Platform Sync**: Flutter UI stays synchronized with Kotlin service

### 5. Performance Optimization
- **Memory Efficient**: Proper resource cleanup and disposal
- **CPU Optimization**: Minimal processing when not in active call
- **Network Efficient**: Optimized audio compression and transmission
- **Battery Conscious**: Smart power management throughout call lifecycle

This comprehensive user flow documentation ensures reliable walkie-talkie functionality across all Android scenarios including backgrounded apps, killed processes, locked devices, and various hardware configurations.
