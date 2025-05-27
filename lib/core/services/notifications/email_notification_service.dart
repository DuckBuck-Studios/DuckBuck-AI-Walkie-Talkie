import '../api/api_service.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';

/// Service for handling all email notifications throughout the app
///
/// This service provides fire-and-forget email operations that don't block the UI.
/// All email operations are performed asynchronously in the background with no error propagation.
class EmailNotificationService {
  final ApiService _apiService;
  final LoggerService _logger;
  
  static const String _tag = 'EMAIL_NOTIFICATION';

  /// Creates a new EmailNotificationService
  EmailNotificationService({
    ApiService? apiService,
    LoggerService? logger,
  }) : _apiService = apiService ?? serviceLocator<ApiService>(),
       _logger = logger ?? serviceLocator<LoggerService>();
  
  /// Send welcome email to a new user after profile completion
  /// This is a fire-and-forget operation that won't block the UI
  /// No exceptions are thrown and no return value is provided
  void sendWelcomeEmail({
    required String email,
    required String username,
    required Map<String, dynamic>? metadata,
  }) {
    // Fire and forget - schedule async operation without awaiting
    _apiService.sendWelcomeEmail(
      email: email,
      username: username,
      metadata: metadata,
    ).then((success) {
      if (success) {
        _logger.i(_tag, 'Welcome email sent successfully to $email');
      } else {
        _logger.w(_tag, 'Welcome email failed to send to $email');
      }
    }).catchError((error) {
      _logger.e(_tag, 'Error sending welcome email to $email: $error');
    });
  }
  
  /// Send login notification email to returning users
  /// This is a fire-and-forget operation that won't block the UI
  /// No exceptions are thrown and no return value is provided
  void sendLoginNotificationEmail({
    required String email,
    required String username,
    required String loginTime,
    required Map<String, dynamic>? metadata,
  }) {
    // Fire and forget - schedule async operation without awaiting
    _apiService.sendLoginNotificationEmail(
      email: email,
      username: username,
      loginTime: loginTime,
      metadata: metadata,
    ).then((success) {
      if (success) {
        _logger.i(_tag, 'Login notification sent successfully to $email');
      } else {
        _logger.w(_tag, 'Login notification failed to send to $email');
      }
    }).catchError((error) {
      _logger.e(_tag, 'Error sending login notification to $email: $error');
    });
  }
}
