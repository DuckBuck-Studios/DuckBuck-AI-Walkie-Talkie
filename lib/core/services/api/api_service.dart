import 'package:dio/dio.dart';
import '../auth/auth_service_interface.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';

/// Exception thrown when API operations fail
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic originalError;

  const ApiException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.originalError,
  });

  @override
  String toString() => 'ApiException: $message';
}

/// Service for handling API requests to the backend with production-ready features
class ApiService {
  final AuthServiceInterface _authService;
  final LoggerService _logger;
  static const String _tag = 'API_SERVICE';
  
  // Base URL for API requests
  final String _baseUrl;
  
  // API key for authentication - moved to environment variable for security
  final String _apiKey;
  
  // Dio HTTP client
  final Dio _dio;
  
  // Circuit breaker state
  bool _circuitBreakerOpen = false;
  DateTime? _circuitBreakerOpenTime;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 1);
  static const int _circuitBreakerFailureThreshold = 5;
  int _consecutiveFailures = 0;
  
  // Rate limiting
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 100);
  
  // Token cache to avoid unnecessary refreshes
  String? _cachedToken;
  DateTime? _tokenCacheTime;
  static const Duration _tokenCacheExpiry = Duration(minutes: 50); // Firebase tokens are valid for 1 hour
  
  /// Creates a new ApiService instance
  ApiService({
    String? baseUrl,
    String? apiKey,
    AuthServiceInterface? authService,
    LoggerService? logger,
    Dio? dio,
  }) : 
    _baseUrl = baseUrl ?? 'https://api.duckbuck.app',
    _apiKey = apiKey ?? const String.fromEnvironment('DUCKBUCK_API_KEY', 
        defaultValue: 'b5735G58099503d10ab75a2d795bd19e03e07fa6059641ffac6546fe798b89Oc'),
    _authService = authService ?? serviceLocator<AuthServiceInterface>(),
    _logger = logger ?? serviceLocator<LoggerService>(),
    _dio = dio ?? Dio() {
      _setupDioConfiguration();
    }
  
  /// Configure Dio with interceptors and proper settings
  void _setupDioConfiguration() {
    // Log the API endpoint being used
    _logger.i(_tag, 'API Service initialized with endpoint: $_baseUrl');
    
    // Base configuration
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.sendTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'DuckBuck-App/1.0',
    };
    
    // Add request interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        await _handleRateLimit();
        _logger.d(_tag, 'Request: ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d(_tag, 'Response: ${response.statusCode} ${response.requestOptions.path}');
        _onRequestSuccess();
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.e(_tag, 'Request failed: ${error.message}');
        _onRequestFailure();
        handler.next(error);
      },
    ));
    
    // Add retry interceptor for failed requests
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (_shouldRetry(error)) {
            try {
              final retryResponse = await _retryRequest(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (e) {
              _logger.e(_tag, 'Retry failed: $e');
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  
  /// Circuit breaker and resilience methods
  void _onRequestSuccess() {
    _consecutiveFailures = 0;
    if (_circuitBreakerOpen) {
      _logger.i(_tag, 'Circuit breaker closed after successful request');
      _circuitBreakerOpen = false;
      _circuitBreakerOpenTime = null;
    }
  }
  
  void _onRequestFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _circuitBreakerFailureThreshold) {
      _logger.w(_tag, 'Circuit breaker opened due to consecutive failures');
      _circuitBreakerOpen = true;
      _circuitBreakerOpenTime = DateTime.now();
    }
  }
  
  bool get _isCircuitBreakerOpen {
    if (!_circuitBreakerOpen) return false;
    
    if (_circuitBreakerOpenTime != null &&
        DateTime.now().difference(_circuitBreakerOpenTime!) > _circuitBreakerTimeout) {
      _logger.i(_tag, 'Circuit breaker timeout expired, allowing test request');
      return false;
    }
    
    return true;
  }
  
  /// Rate limiting
  Future<void> _handleRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final delay = _minRequestInterval - timeSinceLastRequest;
        _logger.d(_tag, 'Rate limiting: waiting ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }
    _lastRequestTime = DateTime.now();
  }
  
  /// Retry logic
  bool _shouldRetry(DioException error) {
    // Don't retry if circuit breaker is open
    if (_isCircuitBreakerOpen) return false;
    
    // Retry on network errors and server errors (5xx)
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    
    // Retry on server errors
    if (error.response?.statusCode != null && 
        error.response!.statusCode! >= 500) {
      return true;
    }
    
    return false;
  }
  
  Future<Response> _retryRequest(RequestOptions options) async {
    _logger.i(_tag, 'Retrying request: ${options.method} ${options.path}');
    
    // Wait before retry with exponential backoff
    final delay = Duration(milliseconds: 1000 * _consecutiveFailures);
    await Future.delayed(delay);
    
    return await _dio.request(
      options.path,
      data: options.data,
      queryParameters: options.queryParameters,
      options: Options(
        method: options.method,
        headers: options.headers,
        responseType: options.responseType,
        contentType: options.contentType,
      ),
    );
  }
  
  /// Enhanced token management with caching
  Future<String?> _getValidToken({bool forceRefresh = false}) async {
    // Check circuit breaker
    if (_isCircuitBreakerOpen) {
      throw ApiException('Service temporarily unavailable due to circuit breaker');
    }
    
    // Return cached token if valid and not forcing refresh
    if (!forceRefresh && _cachedToken != null && _tokenCacheTime != null &&
        DateTime.now().difference(_tokenCacheTime!) < _tokenCacheExpiry) {
      return _cachedToken;
    }
    
    try {
      final token = await _authService.refreshIdToken(forceRefresh: forceRefresh);
      if (token != null) {
        _cachedToken = token;
        _tokenCacheTime = DateTime.now();
      }
      return token;
    } catch (e) {
      _logger.e(_tag, 'Failed to get authentication token: $e');
      return null;
    }
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
  /// Fire-and-forget method - doesn't throw exceptions, just logs results
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
      final idToken = await _getValidToken();
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for welcome email');
        return false;
      }
      
      final response = await _dio.post(
        '/api/users/send-welcome-email',
        options: Options(
          headers: {
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
        _logger.w(_tag, 'Failed to send welcome email. Status: ${response.statusCode}');
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
  /// Fire-and-forget method - doesn't throw exceptions, just logs results
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
      final idToken = await _getValidToken();
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for login notification email');
        return false;
      }
      
      final response = await _dio.post(
        '/api/users/send-login-notification',
        options: Options(
          headers: {
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
        _logger.w(_tag, 'Failed to send login notification email. Status: ${response.statusCode}');
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
  /// BLOCKING method - throws exceptions on failure to ensure proper error handling
  Future<bool> deleteUser({
    required String uid,
    required String idToken,
  }) async {
    try {
      _logger.i(_tag, 'Sending user deletion request to backend for user: $uid');
      
      final response = await _dio.delete(
        '/api/users/delete',
        options: Options(
          headers: {
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
        _logger.e(_tag, 'Failed to delete user on backend. Status: ${response.statusCode}');
        throw ApiException(
          'Failed to delete user account from backend',
          statusCode: response.statusCode,
          errorCode: 'DELETE_FAILED',
        );
      }
    } on DioException catch (e) {
      _logger.e(_tag, 'Dio error deleting user from backend: ${e.message}');
      throw ApiException(
        'Failed to delete user account: ${e.message}',
        statusCode: e.response?.statusCode,
        errorCode: 'DELETE_DIO_ERROR',
        originalError: e,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      _logger.e(_tag, 'Error deleting user from backend: $e');
      throw ApiException(
        'Failed to delete user account: $e',
        errorCode: 'DELETE_ERROR',
        originalError: e,
      );
    }
  }
}
