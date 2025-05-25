import 'package:dio/dio.dart';
import '../auth/auth_service_interface.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';

/// Service for handling API requests to the backend
class ApiService {
  final AuthServiceInterface _authService;
  final LoggerService _logger;
  static const String _tag = 'API_SERVICE';
  
  // Base URL for API requests
  final String _baseUrl;
  
  // API key for authentication
  static const String _apiKey = 'b5735G58099503d10ab75a2d795bd19e03e07fa6059641ffac6546fe798b89Oc';
  
  // Dio HTTP client
  final Dio _dio;
  
  /// Creates a new ApiService instance
  ApiService({
    String? baseUrl,
    AuthServiceInterface? authService,
    LoggerService? logger,
    Dio? dio,
  }) : 
    _baseUrl = baseUrl ?? 'https://api.duckbuck.app',
    _authService = authService ?? serviceLocator<AuthServiceInterface>(),
    _logger = logger ?? serviceLocator<LoggerService>(),
    _dio = dio ?? Dio() {
      // Log the API endpoint being used
      _logger.i(_tag, 'API Service initialized with endpoint: $_baseUrl');
      
      // Configure Dio with increased timeout settings for better reliability
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(seconds: 30);
      _dio.options.sendTimeout = const Duration(seconds: 30);
    }

  /// Checks if the user authenticated with Google or Apple
  /// Returns true if the user signed in with Google or Apple
  bool _isGoogleOrAppleUser(Map<String, dynamic>? metadata) {
    if (metadata == null || !metadata.containsKey('authMethod')) {
      return false;
    }
    
    final authMethod = metadata['authMethod'] as String?;
    return authMethod == 'google' || authMethod == 'apple';
  }

  /// Send welcome email to a new user (only for Google or Apple sign-ins)
  Future<bool> sendWelcomeEmail({
    required String email,
    required String username,
    required Map<String, dynamic>? metadata,
  }) async {
    // Skip sending emails for users who didn't sign in with Google or Apple
    if (!_isGoogleOrAppleUser(metadata)) {
      _logger.i(_tag, 'Skipping welcome email for non-Google/Apple user: $email');
      return true;
    }
    
    try {
      // Get the Firebase ID token for authentication
      final idToken = await _authService.refreshIdToken(forceRefresh: true);
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for welcome email');
        return false;
      }
      
      final response = await _dio.post(
        '$_baseUrl/api/users/send-welcome-email',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
        data: {
          'email': email,
          'username': username,
        },
      );
      
      if (response.statusCode == 200) {
        _logger.i(_tag, 'Welcome email sent successfully to $email');
        return true;
      } else {
        _logger.e(_tag, 'Failed to send welcome email. Status: ${response.statusCode}, Body: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      _logger.e(_tag, 'Dio error sending welcome email: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_tag, 'Error sending welcome email: $e');
      return false;
    }
  }
  
  /// Send login notification email to a user (only for Google or Apple sign-ins)
  Future<bool> sendLoginNotificationEmail({
    required String email,
    required String username,
    required String loginTime,
    required Map<String, dynamic>? metadata,
  }) async {
    // Skip sending emails for users who didn't sign in with Google or Apple
    if (!_isGoogleOrAppleUser(metadata)) {
      _logger.i(_tag, 'Skipping login notification for non-Google/Apple user: $email');
      return true;
    }
    
    try {
      // Get the Firebase ID token for authentication
      final idToken = await _authService.refreshIdToken(forceRefresh: true);
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for login notification email');
        return false;
      }
      
      final response = await _dio.post(
        '$_baseUrl/api/users/send-login-notification',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
        data: {
          'email': email,
          'username': username,
          'loginTime': loginTime,
        },
      );
      
      if (response.statusCode == 200) {
        _logger.i(_tag, 'Login notification email sent successfully to $email');
        return true;
      } else {
        _logger.e(_tag, 'Failed to send login notification email. Status: ${response.statusCode}, Body: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      _logger.e(_tag, 'Dio error sending login notification email: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_tag, 'Error sending login notification email: $e');
      return false;
    }
  }
  
  /// Delete user account from backend systems
  /// Returns true if deletion was successful, false otherwise
  Future<bool> deleteUser({
    required String uid,
    required String idToken,
  }) async {
    try {
      _logger.i(_tag, 'Sending user deletion request to backend for user: $uid');
      
      final response = await _dio.delete(
        '$_baseUrl/api/users/delete',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
        data: {
          'uid': uid
        },
      );
      
      if (response.statusCode == 200) {
        _logger.i(_tag, 'User deletion completed successfully on backend for user: $uid');
        return true;
      } else {
        _logger.e(_tag, 'Failed to delete user on backend. Status: ${response.statusCode}, Body: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      _logger.e(_tag, 'Dio error deleting user from backend: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_tag, 'Error deleting user from backend: $e');
      return false;
    }
  }
}
