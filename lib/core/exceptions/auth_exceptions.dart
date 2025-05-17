/// Custom exception for authentication-related errors
class AuthException implements Exception {
  /// Error code for categorizing the error
  final String code;
  
  /// Human-readable message
  final String message;
  
  /// Optional stack trace or original error for debugging
  final dynamic originalError;
  
  /// The authentication method that was being used when the exception occurred
  final AuthMethod? authMethod;
  
  /// Creates a new authentication exception
  AuthException(this.code, this.message, [this.originalError, this.authMethod]);
  
  @override
  String toString() => 'AuthException($code, ${authMethod?.name ?? 'unknown'}): $message';
}

/// Authentication methods supported by the app
enum AuthMethod {
  google,
  apple,
  phone
}

/// Error codes for authentication-related operations
class AuthErrorCodes {
  // General errors
  static const String unknown = 'auth/unknown';
  static const String networkError = 'auth/network-error';
  static const String operationNotAllowed = 'auth/operation-not-allowed';
  static const String databaseError = 'auth/database-error';
  static const String tooManyRequests = 'auth/too-many-requests';
  static const String invalidCredential = 'auth/invalid-credential';
  static const String wrongPassword = 'auth/wrong-password';
  
  // User account errors
  static const String userDisabled = 'auth/user-disabled';
  static const String userNotFound = 'auth/user-not-found';
  static const String accountExistsWithDifferentCredential = 'auth/account-exists-with-different-credential';
  static const String notLoggedIn = 'auth/not-logged-in';
  static const String userDeleted = 'auth/user-deleted';
  
  // Token and session errors
  static const String tokenRefreshFailed = 'auth/token-refresh-failed';
  static const String tokenExpired = 'auth/token-expired';
  static const String sessionExpired = 'auth/session-expired';
  static const String requiresRecentLogin = 'auth/requires-recent-login';
  static const String sessionTimeout = 'auth/session-timeout';
  static const String credentialValidationFailed = 'auth/credential-validation-failed';
  
  // Google Sign-in specific 
  static const String googleSignInFailed = 'auth/google-sign-in-failed';
  static const String googleSignInCancelled = 'auth/google-sign-in-cancelled';
  static const String googleSignInNetworkError = 'auth/google-sign-in-network-error';
  static const String googleSignInPopupClosed = 'auth/google-sign-in-popup-closed';
  
  // Apple Sign-in specific
  static const String appleSignInFailed = 'auth/apple-sign-in-failed';
  static const String appleSignInCancelled = 'auth/apple-sign-in-cancelled';
  static const String appleSignInNetworkError = 'auth/apple-sign-in-network-error';
  static const String appleSignInNotAvailable = 'auth/apple-sign-in-not-available';
  
  // Phone auth specific
  static const String phoneAuthFailed = 'auth/phone-auth-failed';
  static const String invalidPhoneNumber = 'auth/invalid-phone-number';
  static const String invalidVerificationCode = 'auth/invalid-verification-code';
  static const String invalidVerificationId = 'auth/invalid-verification-id';
  static const String smsCodeExpired = 'auth/code-expired';
  // Session expired is defined above
  static const String smsQuotaExceeded = 'auth/quota-exceeded';
  static const String smsCodeAutoRetrievalTimeout = 'auth/code-retrieval-timeout';
  
  // Generic social auth
  static const String socialAuthCancelled = 'auth/social-auth-cancelled';
}

/// Helper to get user-friendly messages from error codes
class AuthErrorMessages {
  static String getMessageFromCode(String code, {AuthMethod? method}) {
    switch (code) {
      // General errors
      case AuthErrorCodes.networkError:
        return 'Network error occurred. Please check your internet connection.';
      case AuthErrorCodes.operationNotAllowed:
        return 'This operation is not allowed.';
      case AuthErrorCodes.tooManyRequests:
        return 'Too many login attempts. Please try again later.';
      case AuthErrorCodes.databaseError:
        return 'Unable to access user data. Please try again.';
        
      // User account errors
      case AuthErrorCodes.invalidCredential:
        return 'Invalid login credentials. Please try again.';
      case AuthErrorCodes.userDisabled:
        return 'This account has been disabled.';
      case AuthErrorCodes.userNotFound:
        return 'No user found with these credentials.';
      case AuthErrorCodes.wrongPassword:
        return 'Incorrect password. Please try again.';
      case AuthErrorCodes.accountExistsWithDifferentCredential:
        return 'An account already exists with the same email address but different sign-in credentials.';
      case AuthErrorCodes.notLoggedIn:
        return 'No user currently logged in.';
      case AuthErrorCodes.userDeleted:
        return 'Account has been deleted.';
      
      // Google Sign-in specific errors
      case AuthErrorCodes.googleSignInFailed:
        return 'Google sign-in failed. Please try again.';
      case AuthErrorCodes.googleSignInCancelled:
        return 'Google sign-in was cancelled.';
      case AuthErrorCodes.googleSignInNetworkError:
        return 'Network error during Google sign-in. Please check your internet connection.';
      case AuthErrorCodes.googleSignInPopupClosed:
        return 'Google sign-in window was closed before completion.';
      
      // Apple Sign-in specific errors
      case AuthErrorCodes.appleSignInFailed:
        return 'Apple sign-in failed. Please try again.';
      case AuthErrorCodes.appleSignInCancelled:
        return 'Apple sign-in was cancelled.';
      case AuthErrorCodes.appleSignInNetworkError:
        return 'Network error during Apple sign-in. Please check your internet connection.';
      case AuthErrorCodes.appleSignInNotAvailable:
        return 'Apple Sign-In is not available on this device.';
      
      // Phone auth specific errors
      case AuthErrorCodes.phoneAuthFailed:
        return 'Phone authentication failed. Please try again.';
      case AuthErrorCodes.invalidPhoneNumber:
        return 'Invalid phone number format. Please check and try again.';
      case AuthErrorCodes.invalidVerificationCode:
        return 'Invalid verification code. Please try again.';
      case AuthErrorCodes.invalidVerificationId:
        return 'Invalid verification session. Please restart the verification process.';
      case AuthErrorCodes.smsCodeExpired:
        return 'Verification code has expired. Please request a new code.';
      case AuthErrorCodes.sessionExpired:
        return 'Verification session has expired. Please restart the process.';
      case AuthErrorCodes.smsQuotaExceeded:
        return 'SMS quota exceeded. Please try again later.';
      case AuthErrorCodes.smsCodeAutoRetrievalTimeout:
        return 'Automatic SMS code retrieval timed out. Please enter the code manually.';
        
      // Generic social auth
      case AuthErrorCodes.socialAuthCancelled:
        return 'Sign-in was cancelled.';
      
      // Default fallback
      default:
        if (method == AuthMethod.google) {
          return 'Google sign-in error. Please try again.';
        } else if (method == AuthMethod.apple) {
          return 'Apple sign-in error. Please try again.';
        } else if (method == AuthMethod.phone) {
          return 'Phone authentication error. Please try again.';
        } else {
          return 'An unexpected authentication error occurred. Please try again.';
        }
    }
  }
  
  /// Get a user-friendly message specific to the authentication method
  static String getMethodSpecificMessage(AuthException exception) {
    if (exception.authMethod != null) {
      return getMessageFromCode(exception.code, method: exception.authMethod);
    }
    return getMessageFromCode(exception.code);
  }
  
  /// Get an error message with authentication context
  static String getContextualizedMessage(AuthException exception) {
    String baseMessage = getMessageFromCode(exception.code, method: exception.authMethod);
    
    switch (exception.authMethod) {
      case AuthMethod.google:
        return 'Google Sign-In: $baseMessage';
      case AuthMethod.apple:
        return 'Apple Sign-In: $baseMessage';
      case AuthMethod.phone:
        return 'Phone Authentication: $baseMessage';
      default:
        return baseMessage;
    }
  }
}
