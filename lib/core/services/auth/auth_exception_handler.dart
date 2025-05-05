import 'package:firebase_auth/firebase_auth.dart';

/// Common auth error codes
enum AuthResultStatus {
  successful,
  emailAlreadyExists,
  wrongPassword,
  invalidEmail,
  userNotFound,
  userDisabled,
  operationNotAllowed,
  tooManyRequests,
  undefined,
  networkError,
  weakPassword,
  invalidVerificationCode,
  invalidVerificationId,
  accountExistsWithDifferentCredential,
  expiredActionCode,
  invalidActionCode,
  quotaExceeded,
  emailNotVerified,
}

/// Handler for Firebase Authentication exceptions
class AuthExceptionHandler {
  /// Maps Firebase Auth exceptions to more user-friendly error messages
  static FirebaseAuthException handleException(FirebaseAuthException e) {
    String message;

    switch (e.code) {
      case 'invalid-email':
        message = 'The email address is not valid.';
        break;
      case 'wrong-password':
        message = 'Your password is incorrect.';
        break;
      case 'user-not-found':
        message = 'No user found with this email address.';
        break;
      case 'user-disabled':
        message = 'This user account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many requests. Try again later.';
        break;
      case 'operation-not-allowed':
        message = 'This sign in method is not allowed.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email address.';
        break;
      case 'weak-password':
        message = 'Please enter a stronger password.';
        break;
      case 'invalid-verification-code':
        message = 'The verification code is invalid.';
        break;
      case 'invalid-verification-id':
        message = 'The verification ID is invalid.';
        break;
      case 'account-exists-with-different-credential':
        message =
            'An account already exists with the same email but different sign-in credentials.';
        break;
      case 'expired-action-code':
        message = 'The code has expired. Please request a new one.';
        break;
      case 'invalid-action-code':
        message = 'The code is invalid. Please request a new one.';
        break;
      case 'quota-exceeded':
        message = 'Quota exceeded. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection and try again.';
        break;
      case 'email-not-verified':
        message =
            'Please verify your email address. A verification link has been sent.';
        break;
      default:
        message = 'An undefined error occurred: ${e.message}';
        break;
    }

    // Return a new exception with a more descriptive message
    return FirebaseAuthException(code: e.code, message: message);
  }
}
