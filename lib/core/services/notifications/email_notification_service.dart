import '../api/api_service.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';

/// Service for handling all email notifications throughout the app
///
/// This service centralizes all email notification functionality to
/// better separate concerns and make the authentication code cleaner.
class EmailNotificationService {
  final ApiService _apiService;
  final LoggerService _logger;
  
  static const String _tag = 'EMAIL_NOTIFICATION';

  /// Creates a new EmailNotificationService
  EmailNotificationService({
    ApiService? apiService,
    LoggerService? logger,
  }) : _apiService = apiService ?? serviceLocator<ApiService>(),
       _logger = logger ?? LoggerService();
  
  /// Send welcome email to a new user after profile completion
  /// This should only be called once the user has completed their profile
  Future<bool> sendWelcomeEmail({
    required String email,
    required String username,
    required Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.i(_tag, 'Sending welcome email to $email');
      
      // Skip sending emails for users who didn't sign in with supported methods
      if (!_isSupportedAuthMethod(metadata)) {
        _logger.i(_tag, 'Skipping welcome email for unsupported auth method');
        return true;
      }
      
      return await _apiService.sendWelcomeEmail(
        email: email,
        username: username,
        metadata: metadata,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to send welcome email: $e');
      return false;
    }
  }
  
  /// Send login notification email to returning users
  /// This should only be called for existing users, not new signups
  Future<bool> sendLoginNotificationEmail({
    required String email,
    required String username,
    required String loginTime,
    required Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.i(_tag, 'Sending login notification to $email');
      
      // Skip sending emails for users who didn't sign in with supported methods
      if (!_isSupportedAuthMethod(metadata)) {
        _logger.i(_tag, 'Skipping login notification for unsupported auth method');
        return true;
      }
      
      return await _apiService.sendLoginNotificationEmail(
        email: email,
        username: username,
        loginTime: loginTime,
        metadata: metadata,
      );
    } catch (e) {
      _logger.e(_tag, 'Failed to send login notification: $e');
      return false;
    }
  }
  
  /// Check if the user authenticated with a supported method for email notifications
  bool _isSupportedAuthMethod(Map<String, dynamic>? metadata) {
    if (metadata == null || !metadata.containsKey('authMethod')) {
      return false;
    }
    
    final authMethod = metadata['authMethod'] as String?;
    return authMethod == 'google' || authMethod == 'apple';
  }
}
