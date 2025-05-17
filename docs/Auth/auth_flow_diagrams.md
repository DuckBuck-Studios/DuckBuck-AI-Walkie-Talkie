# DuckBuck Authentication Flow Diagrams

This document provides visual diagrams of the authentication flows implemented in the DuckBuck application.

## Table of Contents
1. [Authentication Architecture](#authentication-architecture)
2. [Authentication Flow Sequence](#authentication-flow-sequence)
3. [Phone Authentication Flow](#phone-authentication-flow)
4. [Social Authentication Flow](#social-authentication-flow)
5. [Session Management Flow](#session-management-flow)

## Authentication Architecture

```mermaid
flowchart TB
    subgraph "UI Layer"
        WS[Welcome Screen]
        OB[Onboarding Screens]
        ABS[Auth Bottom Sheet]
        Home[Home Screen]
    end
    
    subgraph "Provider Layer"
        ASP[Auth State Provider]
    end
    
    subgraph "Repository Layer"
        UR[User Repository]
    end
    
    subgraph "Service Layer"
        FAS[Firebase Auth Service]
        SM[Session Manager]
        ASM[Auth Security Manager]
        PS[Preferences Service]
        FS[Firebase Services]
    end
    
    subgraph "External Services"
        FB[Firebase Auth]
        GS[Google Sign-In]
        AS[Apple Sign-In]
    end
    
    %% UI Layer connections
    WS --> OB
    OB --> ABS
    ABS --> ASP
    ASP --> Home
    
    %% Provider Layer connections
    ASP --> UR
    
    %% Repository Layer connections
    UR --> FAS
    UR --> PS
    UR --> FS
    
    %% Service Layer connections
    FAS --> SM
    FAS --> ASM
    FAS --> FB
    
    %% External connections
    FB --> GS
    FB --> AS
    
    %% Styling
    classDef uiLayer fill:#d9f2d9,stroke:#78c2ad,stroke-width:2px
    classDef providerLayer fill:#d9e8f2,stroke:#6c8ebf,stroke-width:2px
    classDef repositoryLayer fill:#fbe7d2,stroke:#e67e22,stroke-width:2px
    classDef serviceLayer fill:#f2e2d9,stroke:#d68910,stroke-width:2px
    classDef externalLayer fill:#e8d9f2,stroke:#8e44ad,stroke-width:2px
    
    class WS,OB,ABS,Home uiLayer
    class ASP providerLayer
    class UR repositoryLayer
    class FAS,SM,ASM,PS,FS serviceLayer
    class FB,GS,AS externalLayer
```

## Authentication Flow Sequence

```mermaid
sequenceDiagram
    actor User
    participant UI as UI Components
    participant Provider as Auth State Provider
    participant Repo as User Repository
    participant Auth as Firebase Auth Service
    participant Firebase as Firebase Auth
    
    User->>UI: Opens app
    UI->>UI: Welcome Screen
    User->>UI: Slides to continue
    UI->>UI: Onboarding Screens
    User->>UI: Completes onboarding
    UI->>UI: Shows Auth Bottom Sheet
    
    alt Google Sign-In
        User->>UI: Selects Google Sign-In
        UI->>Provider: signInWithGoogle()
        Provider->>Repo: signInWithGoogle()
        Repo->>Auth: signInWithGoogle()
        Auth->>Firebase: Sign in with Google
        Firebase-->>Auth: UserCredential
        Auth-->>Repo: UserCredential
        Repo->>Repo: Create/Update User
        Repo-->>Provider: UserModel
        Provider-->>UI: Authentication Success
        UI->>UI: Navigate to Home Screen
    else Apple Sign-In
        User->>UI: Selects Apple Sign-In
        UI->>Provider: signInWithApple()
        Provider->>Repo: signInWithApple()
        Repo->>Auth: signInWithApple()
        Auth->>Firebase: Sign in with Apple
        Firebase-->>Auth: UserCredential
        Auth-->>Repo: UserCredential
        Repo->>Repo: Create/Update User
        Repo-->>Provider: UserModel
        Provider-->>UI: Authentication Success
        UI->>UI: Navigate to Home Screen
    else Phone Authentication
        User->>UI: Selects Phone Auth
        UI->>UI: Shows Phone Entry
        User->>UI: Enters Phone Number
        UI->>Provider: signInWithPhone(phoneNumber)
        Provider->>Repo: signInWithPhoneNumber(phoneNumber)
        Repo->>Auth: verifyPhoneNumber(phoneNumber)
        Auth->>Firebase: Send SMS Verification
        Firebase-->>Auth: Verification ID
        Auth-->>Repo: Verification ID
        Repo-->>Provider: Verification ID
        Provider-->>UI: Show OTP Entry
        UI->>UI: Display OTP Screen
        User->>UI: Enters OTP
        UI->>Provider: verifyOtp(verificationId, otp)
        Provider->>Repo: verifyOtp(verificationId, otp)
        Repo->>Auth: verifyOtpAndSignIn(verificationId, otp)
        Auth->>Firebase: Verify OTP
        Firebase-->>Auth: UserCredential
        Auth-->>Repo: UserCredential
        Repo->>Repo: Create/Update User
        Repo-->>Provider: UserModel
        Provider-->>UI: Authentication Success
        UI->>UI: Navigate to Home Screen
    end
```

## Phone Authentication Flow

```mermaid
flowchart TD
    Start[Start Phone Authentication] --> PhoneEntry[Phone Number Entry Screen]
    PhoneEntry --> ValidatePhone{Validate Phone}
    ValidatePhone -- Invalid --> ShowError[Show Error Message]
    ShowError --> PhoneEntry
    ValidatePhone -- Valid --> SendOTP[Send OTP via Firebase]
    SendOTP --> WaitSMS[Wait for SMS]
    
    WaitSMS --> AutoDetect{Auto Detect?}
    AutoDetect -- Yes --> AutoFill[Auto-fill OTP]
    AutoDetect -- No --> ManualEntry[Manual OTP Entry]
    
    AutoFill --> ValidateOTP{Validate OTP}
    ManualEntry --> ValidateOTP
    
    ValidateOTP -- Invalid --> RetryOTP[Show Error Message]
    RetryOTP --> ManualEntry
    ValidateOTP -- Valid --> SignIn[Sign In with Firebase]
    
    SignIn --> CheckUser{New User?}
    CheckUser -- Yes --> CreateUser[Create User in Firestore]
    CheckUser -- No --> UpdateUser[Update User Data]
    
    CreateUser --> Complete[Authentication Complete]
    UpdateUser --> Complete
    
    %% Styling
    classDef process fill:#d9f2d9,stroke:#78c2ad,stroke-width:2px
    classDef decision fill:#d9e8f2,stroke:#6c8ebf,stroke-width:2px
    classDef error fill:#f2d9d9,stroke:#e74c3c,stroke-width:2px
    classDef endNodes fill:#e8d9f2,stroke:#8e44ad,stroke-width:2px
    
    class PhoneEntry,SendOTP,WaitSMS,AutoFill,ManualEntry,SignIn,CreateUser,UpdateUser process
    class ValidatePhone,AutoDetect,ValidateOTP,CheckUser decision
    class ShowError,RetryOTP error
    class Start,Complete endNodes
```

## Social Authentication Flow

```mermaid
flowchart TD
    Start[Start Social Authentication] --> Method{Select Method}
    Method -- Google --> Google[Initiate Google Auth]
    Method -- Apple --> Apple[Initiate Apple Auth]
    
    Google --> GRequest[Request Google Permissions]
    Apple --> ARequest[Request Apple Permissions]
    
    GRequest --> GAccount{User Granted?}
    ARequest --> AAccount{User Granted?}
    
    GAccount -- No --> Cancel[Authentication Cancelled]
    AAccount -- No --> Cancel
    
    GAccount -- Yes --> GToken[Get OAuth Token]
    AAccount -- Yes --> ANonce[Generate Secure Nonce]
    ANonce --> AToken[Get Apple Token]
    
    GToken --> FirebaseG[Sign in to Firebase with Google]
    AToken --> FirebaseA[Sign in to Firebase with Apple]
    
    FirebaseG --> CheckUser{New User?}
    FirebaseA --> CheckUser
    
    CheckUser -- Yes --> CreateUser[Create User in Firestore]
    CheckUser -- No --> UpdateUser[Update User Data]
    
    CreateUser --> CacheToken[Cache Auth Token]
    UpdateUser --> CacheToken
    
    CacheToken --> Complete[Authentication Complete]
    Cancel --> End[End Authentication Flow]
    
    %% Styling
    classDef process fill:#d9f2d9,stroke:#78c2ad,stroke-width:2px
    classDef decision fill:#d9e8f2,stroke:#6c8ebf,stroke-width:2px
    classDef googleAction fill:#f2d9d9,stroke:#db4437,stroke-width:2px
    classDef appleAction fill:#e6e6e6,stroke:#000000,stroke-width:2px
    classDef endNodes fill:#e8d9f2,stroke:#8e44ad,stroke-width:2px
    
    class Method decision
    class Google,GRequest,GToken,FirebaseG googleAction
    class Apple,ANonce,AToken,FirebaseA appleAction
    class GAccount,AAccount,CheckUser decision
    class CreateUser,UpdateUser,CacheToken process
    class Start,Cancel,Complete,End endNodes
```

## Session Management Flow

```mermaid
flowchart TD
    Start[App Launch] --> CheckToken{Auth Token Exists?}
    CheckToken -- No --> NotAuthenticated[Not Authenticated]
    CheckToken -- Yes --> ValidateToken{Token Valid?}
    
    ValidateToken -- No --> RefreshToken[Attempt to Refresh Token]
    ValidateToken -- Yes --> StartRefreshTimer[Start Refresh Timer]
    
    RefreshToken --> RefreshSucceeded{Refresh Succeeded?}
    RefreshSucceeded -- No --> ClearSession[Clear Session Data]
    RefreshSucceeded -- Yes --> StartRefreshTimer
    
    StartRefreshTimer --> Authenticated[User Authenticated]
    ClearSession --> NotAuthenticated
    
    Authenticated --> AppActivity[App Activities]
    NotAuthenticated --> ShowAuth[Show Authentication UI]
    
    AppActivity --> BackgroundCheck{App in Background?}
    BackgroundCheck -- Yes --> SuspendRefresh[Suspend Token Refresh]
    BackgroundCheck -- No --> ContinueRefresh[Continue Token Refresh]
    
    SuspendRefresh --> ForegroundCheck{Back to Foreground?}
    ForegroundCheck -- Yes --> ValidateToken
    ForegroundCheck -- No --> MaintainState[Maintain Suspension]
    
    ContinueRefresh --> PeriodicRefresh[Refresh Before Expiry]
    PeriodicRefresh --> TokenExpiry{Token Near Expiry?}
    TokenExpiry -- Yes --> RefreshToken
    TokenExpiry -- No --> ContinueRefresh
    
    %% Styling
    classDef process fill:#d9f2d9,stroke:#78c2ad,stroke-width:2px
    classDef decision fill:#d9e8f2,stroke:#6c8ebf,stroke-width:2px
    classDef error fill:#f2d9d9,stroke:#e74c3c,stroke-width:2px
    classDef success fill:#d9e8f2,stroke:#28a745,stroke-width:2px
    classDef endNodes fill:#e8d9f2,stroke:#8e44ad,stroke-width:2px
    
    class CheckToken,ValidateToken,RefreshSucceeded,BackgroundCheck,ForegroundCheck,TokenExpiry decision
    class RefreshToken,StartRefreshTimer,ClearSession,SuspendRefresh,ContinueRefresh,PeriodicRefresh process
    class Authenticated,ContinueRefresh success
    class NotAuthenticated,ClearSession error
    class Start,ShowAuth,AppActivity,MaintainState endNodes
```
