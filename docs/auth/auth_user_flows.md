# Authentication User Flows

This document describes the detailed user flows for authentication in the DuckBuck application. These flows illustrate the interactions between components in the authentication system, showing how data and control flow during authentication processes.

## User Flow Diagrams

### New User Sign-Up Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as UI Layer
    participant Provider as Auth Provider
    participant Security as Auth Security
    participant Repository as User Repository
    participant Auth as Auth Service
    participant DB as User Service
    participant Storage as Preferences Service
    participant Analytics as Analytics Service
    participant External as External Auth
    participant Firestore as Firestore
    participant FCM as Push Notifications
    
    User->>UI: Opens App
    UI->>Provider: checkAuthState()
    Provider->>Repository: getCurrentUser()
    Repository->>Storage: getStoredUser()
    Storage-->>Repository: null (no stored user)
    Repository-->>Provider: null (not authenticated)
    Provider-->>UI: Not authenticated
    UI->>UI: Show Welcome Screen
    
    User->>UI: Selects Authentication Method
    UI->>UI: Show loading indicator
    
    alt Google Sign-In
        UI->>Provider: signInWithGoogle()
        Provider->>Repository: signInWithGoogle()
        Repository->>Analytics: logEvent("google_auth_attempt")
        Repository->>Auth: signInWithGoogle()
        Auth->>External: Google Auth SDK
        External-->>User: Google consent dialog
        User->>External: Grants permissions
        External-->>Auth: Google Credentials
        Auth->>Security: validateCredentials()
        Security-->>Auth: Valid credentials
        Auth->>External: Firebase Auth
        External-->>Auth: UserCredential
        Auth-->>Repository: UserCredential
    else Apple Sign-In
        UI->>Provider: signInWithApple()
        Provider->>Repository: signInWithApple()
        Repository->>Analytics: logEvent("apple_auth_attempt")
        Repository->>Auth: signInWithApple()
        Auth->>External: Apple Auth SDK
        External-->>User: Apple consent dialog
        User->>External: Grants permissions
        External-->>Auth: Apple Credentials
        Auth->>Security: validateCredentials()
        Security-->>Auth: Valid credentials
        Auth->>External: Firebase Auth
        External-->>Auth: UserCredential
        Auth-->>Repository: UserCredential
    else Phone Auth
        UI->>Provider: verifyPhoneNumber()
        Provider->>Repository: verifyPhoneNumber()
        Repository->>Analytics: logEvent("phone_auth_attempt")
        Repository->>Auth: verifyPhoneNumber()
        Auth->>Security: validatePhoneRequest()
        Security-->>Auth: Request valid
        Auth->>External: Firebase Phone Auth
        External-->>User: SMS with OTP
        Note over UI,User: Auto-detection attempted on Android
        UI->>UI: Show OTP input screen
        User->>UI: Enters OTP
        UI->>Provider: verifyOtpAndSignIn()
        Provider->>Repository: verifyOtpAndSignIn()
        Repository->>Auth: verifyOtpAndSignIn()
        Auth->>External: Firebase Verify OTP
        External-->>Auth: UserCredential
        Auth-->>Repository: UserCredential
    end
    
    Repository->>Repository: Check if user exists
    Repository->>Security: generateAppSignature()
    Security-->>Repository: App signature
    
    Repository->>Repository: Create UserModel
    Repository->>DB: createUserData(userModel)
    DB->>Firestore: Create document in users collection
    Firestore-->>DB: Document created
    
    Repository->>Analytics: logEvent("new_user_signup", method)
    Analytics->>Analytics: Record conversion
    
    Repository->>FCM: registerDeviceToken()
    FCM-->>Repository: Token registered
    
    Repository->>Storage: cacheUserData(userModel)
    Storage-->>Repository: Data cached
    
    Repository->>Security: initializeSession(userModel)
    Security-->>Repository: Session initialized

    Repository-->>Provider: (UserModel, isNewUser: true)
    Provider-->>UI: (UserModel, isNewUser: true)
    UI->>UI: Hide loading indicator
    
    UI->>UI: Navigate to Profile Completion
    UI->>Analytics: screenView("profile_completion")
    
    User->>UI: Enters name
    User->>UI: Uploads profile photo
    UI->>UI: Show loading indicator
    UI->>Provider: updateProfile(name, photoUrl)
    Provider->>Repository: updateProfile(name, photoUrl)
    Repository->>Auth: updateProfile(name, photoUrl)
    Auth->>External: Firebase Update Profile
    External-->>Auth: Profile updated
    
    Repository->>DB: updateUserProfile(name, photoUrl)
    DB->>Firestore: Update user document
    Firestore-->>DB: Document updated
    
    UI->>Provider: markUserOnboardingComplete()
    Provider->>Repository: markUserOnboardingComplete()
    Repository->>DB: markUserOnboardingComplete()
    DB->>Firestore: Update isOnboardingComplete flag
    Repository->>Analytics: logEvent("profile_completion_success")
    
    UI->>UI: Hide loading indicator
    UI->>UI: Navigate to Home Screen
    UI->>Analytics: screenView("home_screen")
    
    opt Social Auth Only
        Repository->>Repository: Send welcome email via Cloud Function
        Note over Repository,External: Triggered by Firestore write
    end
```

### Returning User Sign-In Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as UI Layer
    participant Provider as Auth Provider
    participant Security as Auth Security
    participant Repository as User Repository
    participant Auth as Auth Service
    participant DB as User Service
    participant Storage as Preferences Service
    participant Analytics as Analytics Service
    participant FCM as Push Notifications
    participant External as External Auth
    participant Firestore as Firestore
    
    User->>UI: Opens App
    UI->>Provider: checkAuthState()
    Provider->>Repository: getCurrentUser()
    
    alt Token Found in Local Storage
        Repository->>Storage: getStoredUser()
        Storage-->>Repository: Cached user data
        Repository->>Security: checkTokenValidity()
        
        alt Valid Token
            Security-->>Repository: Token valid
            Repository->>DB: getUserData(uid)
            DB->>Firestore: Fetch user document
            Firestore-->>DB: User document
            DB-->>Repository: Latest user data
            Repository->>FCM: refreshToken()
            Repository-->>Provider: UserModel (authenticated)
            Provider-->>UI: Authenticated
            UI->>UI: Navigate to Home Screen
            Note over UI,User: Skip auth screens
        else Expired Token
            Security-->>Repository: Token expired
            Repository->>Repository: clearAuthState()
            Repository-->>Provider: null (not authenticated)
            Provider-->>UI: Not authenticated
            UI->>UI: Show Welcome Screen
        end
    else No Stored Token
        Storage-->>Repository: null (no stored user)
        Repository-->>Provider: null (not authenticated)
        Provider-->>UI: Not authenticated
        UI->>UI: Show Welcome Screen
    end
    
    User->>UI: Selects Authentication Method
    UI->>UI: Show loading indicator
    
    alt Google Sign-In
        UI->>Provider: signInWithGoogle()
        Provider->>Repository: signInWithGoogle()
        Repository->>Analytics: logEvent("google_signin_attempt")
        Repository->>Auth: signInWithGoogle()
        Auth->>External: Google Auth SDK
        External-->>Auth: Google Credentials
        Auth->>Security: validateCredentials()
        Security-->>Auth: Valid credentials
        Auth->>External: Firebase Auth
        External-->>Auth: UserCredential
        Auth-->>Repository: UserCredential
    else Apple Sign-In
        UI->>Provider: signInWithApple()
        Provider->>Repository: signInWithApple()
        Repository->>Analytics: logEvent("apple_signin_attempt")
        Repository->>Auth: signInWithApple()
        Auth->>External: Apple Auth SDK
        External-->>Auth: Apple Credentials
        Auth->>Security: validateCredentials()
        Security-->>Auth: Valid credentials
        Auth->>External: Firebase Auth
        External-->>Auth: UserCredential
        Auth-->>Repository: UserCredential
    else Phone Auth
        UI->>Provider: verifyPhoneNumber()
        Provider->>Repository: verifyPhoneNumber()
        Repository->>Analytics: logEvent("phone_signin_attempt")
        Repository->>Auth: verifyPhoneNumber()
        Auth->>Security: validatePhoneRequest()
        Security-->>Auth: Request valid
        Auth->>External: Firebase Phone Auth
        External-->>User: SMS with OTP
        Note over UI,User: Auto-detection attempted on Android
        UI->>UI: Show OTP input screen
        User->>UI: Enters OTP
        UI->>Provider: verifyOtpAndSignIn()
        Provider->>Repository: verifyOtpAndSignIn()
        Repository->>Auth: verifyOtpAndSignIn()
        Auth->>External: Firebase Verify OTP
        External-->>Auth: UserCredential
        Auth-->>Repository: UserCredential
    end
    
    Repository->>Repository: Generate UserModel from credentials
    Repository->>DB: getUserData(uid)
    DB->>Firestore: Fetch user document
    Firestore-->>DB: User Document
    DB-->>Repository: Existing User Data
    Repository->>Repository: Merge user data with credentials
    
    Repository->>Analytics: logEvent("user_signin_success", authMethod)
    Analytics->>Analytics: Record successful sign-in
    
    Repository->>FCM: registerDeviceToken(uid)
    FCM-->>Repository: Token updated
    
    Repository->>Security: generateAppSignature()
    Security-->>Repository: App signature
    Repository->>Security: initializeSession(user)
    Security-->>Repository: Session initialized
    
    Repository->>Storage: cacheUserData(userModel)
    Storage-->>Repository: Data cached
    
    Repository->>Repository: Check for account updates
    Repository->>DB: updateLastLogin(uid)
    DB->>Firestore: Update lastLoginAt field
    
    Repository-->>Provider: (UserModel, isNewUser: false)
    Provider-->>UI: (UserModel, isNewUser: false)
    UI->>UI: Hide loading indicator
    
    UI->>UI: Navigate to Home Screen
    UI->>Analytics: screenView("home_screen")
    
    opt Security Analysis
        Repository->>Analytics: logEvent("login_location_change", isNewLocation)
        Note over Repository,Analytics: Optional security checks
    end
```

### Sign-Out Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as UI Layer
    participant Provider as Auth Provider
    participant Security as Auth Security Manager
    participant Repository as User Repository
    participant Notif as Notifications Service
    participant Auth as Auth Service
    participant Storage as Preferences Service
    participant Analytics as Analytics Service
    participant External as External Auth
    participant Firestore as Firestore
    
    User->>UI: Taps Sign Out Button
    UI->>UI: Show confirmation dialog
    User->>UI: Confirms sign out
    UI->>UI: Show loading indicator
    UI->>Provider: signOut()
    
    Provider->>Security: endUserSession()
    Security->>Security: Clear Session Timer
    Security->>Security: Invalidate tokens
    
    Provider->>Repository: signOut()
    Repository->>Analytics: logEvent("user_signout")
    
    Repository->>Repository: Get current user ID
    Repository->>Notif: unregisterToken(userId)
    Notif->>External: Delete FCM Token mapping
    
    Repository->>Auth: signOut()
    Auth->>External: Firebase Sign Out
    External-->>Auth: Sign Out Complete
    alt Social Auth
        Auth->>External: Sign Out from Google/Apple
        External-->>Auth: Social Sign Out Complete
    end
    
    Repository->>Storage: clearAuthData()
    Storage-->>Repository: Data cleared
    
    Repository->>DB: updateLastSeen(userId)
    DB->>Firestore: Update lastSeen timestamp
    Firestore-->>DB: Update complete
    
    Repository-->>Provider: Sign Out Complete
    Provider-->>UI: Sign Out Complete
    
    UI->>UI: Hide loading indicator
    UI->>UI: Navigate to Welcome Screen
    UI->>Analytics: screenView("welcome_screen")
    UI->>UI: Navigate to Welcome Screen
```

### Session Management Flow

```mermaid
sequenceDiagram
    participant UI as UI Layer
    participant App as App Lifecycle
    participant Security as Auth Security Manager
    participant Session as Session Manager
    participant Repository as User Repository
    participant Provider as Auth Provider
    
    note over App: App Initialization
    App->>Security: initialize(onSessionExpired)
    Security->>Session: create()
    
    note over App: User Authentication
    App->>Security: startUserSession()
    Security->>Session: startSessionTimer()
    
    alt User Interaction
        UI->>App: User Activity
        App->>Security: updateUserActivity()
        Security->>Session: updateActivity()
        Session->>Session: Reset Timer
    end
    
    alt Session Timeout
        Session->>Session: Timer Expires
        Session->>Security: onSessionExpired()
        Security->>Repository: signOut()
        Repository->>Provider: signOut()
        Provider->>UI: Update Auth State
        UI->>UI: Show Session Expired Message
        UI->>UI: Navigate to Welcome Screen
    end
    
    alt Manual Sign Out
        UI->>Provider: signOut()
        Provider->>Security: endUserSession()
        Security->>Session: clearSession()
    end
```

### Password Reset Flow

```mermaid
sequenceDiagram
    actor User
    participant UI as UI Layer
    participant Provider as Auth Provider
    participant Repository as User Repository
    participant Auth as Auth Service
    participant Analytics as Analytics Service
    participant External as External Auth
    
    User->>UI: Taps "Forgot Password" 
    UI->>UI: Navigate to Password Reset Screen
    UI->>Analytics: screenView("password_reset_screen")
    
    User->>UI: Enters Email Address
    UI->>UI: Validate Email Format
    UI->>UI: Show loading indicator
    UI->>Provider: resetPassword(email)
    Provider->>Repository: resetPassword(email)
    Repository->>Analytics: logEvent("password_reset_request")
    Repository->>Auth: sendPasswordResetEmail(email)
    Auth->>External: Firebase Password Reset
    
    alt Email Found
        External-->>Auth: Reset Email Sent
        Auth-->>Repository: Success
        Repository-->>Provider: Success
        Provider-->>UI: Success
        UI->>UI: Hide loading indicator
        UI->>UI: Show Success Message
        UI->>Analytics: logEvent("password_reset_email_sent")
    else Email Not Found
        External-->>Auth: User Not Found Error
        Auth-->>Repository: User Not Found Error
        Repository-->>Provider: User Not Found Error
        Provider-->>UI: User Not Found Error
        UI->>UI: Hide loading indicator
        UI->>UI: Show Error Message
        UI->>Analytics: logEvent("password_reset_error", "user_not_found")
    end
    
    note over User,External: User receives email and clicks reset link
    
    User->>External: Opens Reset Link in Email
    External->>External: Firebase Reset Page
    User->>External: Enters New Password
    External->>External: Password Updated
    
    note over User,UI: Next login uses new password
```

## Detailed Authentication Workflows

### Google Authentication

1. **Authentication Initiation**
   - User taps Google sign-in button
   - UI shows loading indicator
   - Analytics logs auth attempt

2. **Credential Acquisition**
   - SDK presents Google account picker
   - User selects account
   - Google returns OAuth tokens

3. **Firebase Authentication**
   - Google credentials exchanged for Firebase credentials
   - Firebase returns UserCredential object

4. **User Processing**
   - UserModel created from Firebase User
   - Check if user is new to Firestore
   - If new: Create user document with isNewUser flag
   - If existing: Update last login timestamp

5. **Post-Authentication**
   - Cache user data in preferences
   - Register FCM token for notifications
   - Start session timer
   - Log analytics event (sign-up or login)
   - Update UI state

6. **User Flow Branching**
   - If new user: Navigate to Profile Completion
   - If returning user: Navigate to Home Screen

### Apple Authentication

1. **Authentication Initiation**
   - User taps Apple sign-in button
   - UI shows loading indicator
   - Analytics logs auth attempt

2. **Platform-Specific Flow**
   - On iOS/macOS: Native Apple Sign-In flow
   - On Android: Web authentication flow with redirect

3. **Credential Processing**
   - Generate secure nonce for CSRF protection
   - Retrieve Apple ID credentials
   - Create Firebase credential from Apple tokens

4. **Firebase Authentication**
   - Apple credentials exchanged for Firebase credentials
   - Firebase returns UserCredential object

5. **User Processing**
   - UserModel created from Firebase User
   - Check if user is new to Firestore
   - If new: Create user document with isNewUser flag
   - If existing: Update last login timestamp

6. **Post-Authentication**
   - Cache user data in preferences
   - Register FCM token for notifications
   - Start session timer
   - Log analytics event (sign-up or login)
   - Update UI state

7. **User Flow Branching**
   - If new user: Navigate to Profile Completion
   - If returning user: Navigate to Home Screen

### Phone Authentication

1. **Phone Number Entry**
   - User enters phone number in formatted field
   - UI validates phone format
   - Analytics logs phone verification attempt

2. **Verification Code Request**
   - Phone number sent to Firebase
   - Firebase sends SMS with OTP
   - UI shows OTP entry screen

3. **OTP Verification**
   - User enters OTP code
   - Code sent to Firebase for verification
   - Firebase returns UserCredential on success

4. **User Processing**
   - UserModel created from Firebase User
   - Check if user is new to Firestore
   - If new: Create user document with isNewUser flag
   - If existing: Update last login timestamp

5. **Post-Authentication**
   - Cache user data in preferences
   - Register FCM token for notifications
   - Start session timer
   - Log analytics event (sign-up or login)
   - Update UI state

6. **User Flow Branching**
   - If new user: Navigate to Profile Completion
   - If returning user: Navigate to Home Screen

### Profile Completion

1. **Data Collection**
   - User enters display name
   - User optionally uploads profile photo
   - Validate inputs

2. **Profile Update**
   - Upload photo to Firebase Storage (if selected)
   - Update user profile in Firebase Auth
   - Update user data in Firestore

3. **Onboarding Completion**
   - Mark user onboarding as complete (remove isNewUser flag)
   - Send welcome email for social auth users
   - Log analytics event for profile completion

4. **Navigation**
   - Transition to Home Screen

### Auto-Login

1. **App Initialization**
   - Check Firebase currentUser
   - Check preferences isLoggedIn flag

2. **Synchronization**
   - If both agree user is logged in: Restore session
   - If mismatch: Clear preferences and require new login

3. **Session Restoration**
   - Load cached user data
   - Start session timer
   - Register FCM token
   - Navigate directly to Home Screen

## Error Handling Strategies

### Network Errors
- Retry mechanism for transient network failures
- Clear error messages to distinguish network from auth failures
- Local caching to minimize network dependency

### Authentication Failures
- Standardized error messages for common scenarios
- Detailed logging for debugging purposes
- Analytics to track failure patterns

### Platform-Specific Issues
- Separate handling for iOS/Android differences in social auth
- Fallback mechanisms when platform features are unavailable
- Platform detection for optimal authentication flow

### Security Concerns
- Token refresh failures trigger re-authentication
- Invalid sessions are cleared immediately
- Suspicious activities trigger additional verification
- Comprehensive logging for security auditing
