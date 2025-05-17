/// Constants for authentication services
class AuthConstants {
  /// The client ID for Apple Sign In
  /// This needs to be set up in your Apple Developer Account as a Services ID
  /// with Sign In with Apple enabled and the correct redirect URL
  static const String appleServicesId = 'com.duckbuck.service.id';
  
  /// The redirect URL for Apple Sign In
  /// This must match the URL you configured in your Apple Developer Account
  static const String appleRedirectUrl = 'com.duckbuck.app://callback';
}
