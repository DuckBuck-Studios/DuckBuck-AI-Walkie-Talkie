import 'package:dio/dio.dart';
import '../auth/auth_service_interface.dart';
import '../service_locator.dart';
import '../logger/logger_service.dart';
import '../agora/agora_token_service.dart';

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
    String? apiKey,
    AuthServiceInterface? authService,
    LoggerService? logger,
    Dio? dio,
  }) : 
    _baseUrl = 'https://api.duckbuck.app',
    _apiKey = apiKey ?? const String.fromEnvironment('DUCKBUCK_API_KEY'),
    _authService = authService ?? serviceLocator<AuthServiceInterface>(),
    _logger = logger ?? serviceLocator<LoggerService>(),
    _dio = dio ?? Dio() {
      // Validate API key is provided
      if (_apiKey.isEmpty) {
        throw ArgumentError(
          'API key is required. Set DUCKBUCK_API_KEY environment variable or pass apiKey parameter.'
        );
      }
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


  
  /// Send push notification to a user
  /// Fire-and-forget method - doesn't throw exceptions, just logs results
  Future<bool> sendNotification({
    required String recipientUid,
    String? title,  
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get the Firebase ID token for authentication
      final idToken = await _getValidToken();
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for sending notification');
        return false;
      }
      
      // Build request data without title if it's not provided
      final Map<String, dynamic> requestData = {
        'recipientUid': recipientUid,
        'body': body,
        if (title != null) 'title': title,  // Only include title if provided
        if (data != null) 'data': data,
      };
      
      final response = await _dio.post(
        '/api/notifications/send',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
        data: requestData,
      );
      
      if (response.statusCode == 200) {
        _logger.i(_tag, 'Notification sent successfully to user: $recipientUid');
        return true;
      } else {
        _logger.w(_tag, 'Failed to send notification. Status: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      _logger.e(_tag, 'Dio error sending notification: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_tag, 'Error sending notification: $e');
      return false;
    }
  }

  /// Send data-only push notification to a user (for call invitations)
  /// Fire-and-forget method - doesn't throw exceptions, just logs results
  Future<bool> sendDataOnlyNotification({
    required String uid,
    required String type,
    required String agoraChannelId,
    required String callName,
    required String callerPhoto,
  }) async {
    try {
      // Get the Firebase ID token for authentication
      final idToken = await _getValidToken();
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for sending data-only notification');
        return false;
      }
      
      final response = await _dio.post(
        '/api/notifications/send-data-only',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
        data: {
          'uid': uid,
          'data': {
            'type': type,
            'agora_channelid': agoraChannelId,
            'call_name': callName,
            'caller_photo': callerPhoto,
          },
        },
      );
      
      if (response.statusCode == 200) {
        _logger.i(_tag, 'Data-only notification sent successfully to user: $uid');
        return true;
      } else {
        _logger.w(_tag, 'Failed to send data-only notification. Status: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      _logger.e(_tag, 'Dio error sending data-only notification: ${e.message}');
      return false;
    } catch (e) {
      _logger.e(_tag, 'Error sending data-only notification: $e');
      return false;
    }
  }

  /// Join AI agent to a channel
  /// BLOCKING method - throws exceptions on failure to ensure proper error handling
  /// Returns AiAgentResponse with agent details if successful
  Future<Map<String, dynamic>?> joinAiAgent({
    required String uid,
    required String channelName,
  }) async {
    try {
      // Check circuit breaker first
      if (_isCircuitBreakerOpen) {
        _logger.e(_tag, 'Circuit breaker is open - rejecting AI agent join request');
        throw const ApiException(
          'Service temporarily unavailable due to circuit breaker',
          statusCode: 503,
          errorCode: 'CIRCUIT_BREAKER_OPEN',
        );
      }

      // Handle rate limiting
      await _handleRateLimit();

      _logger.i(_tag, 'Joining AI agent to channel: $channelName for user: $uid');

      // Get the Firebase ID token for authentication
      final idToken = await _getValidToken();
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for AI agent join');
        throw const ApiException(
          'Authentication failed - unable to get Firebase token',
          statusCode: 401,
          errorCode: 'AUTH_TOKEN_FAILED',
        );
      }

      final response = await _dio.post(
        '/api/ai-agent/join',
        data: {
          'uid': uid,
          'channelName': channelName,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
      );

      _onRequestSuccess();

      if (response.statusCode == 200 && response.data != null) {
        _logger.i(_tag, 'AI agent successfully joined channel: $channelName');
        return response.data as Map<String, dynamic>;
      } else {
        _logger.e(_tag, 'Failed to join AI agent to channel. Status: ${response.statusCode}');
        throw ApiException(
          'Failed to join AI agent to channel',
          statusCode: response.statusCode,
          errorCode: 'AI_AGENT_JOIN_FAILED',
        );
      }
    } on DioException catch (e) {
      _onRequestFailure();
      _logger.e(_tag, 'DioException joining AI agent: ${e.message}');
      
      if (e.response?.statusCode == 401) {
        throw const ApiException(
          'Authentication failed - invalid Firebase token',
          statusCode: 401,
          errorCode: 'AUTH_FAILED',
        );
      } else if (e.response?.statusCode == 403) {
        throw const ApiException(
          'Access forbidden - invalid API key',
          statusCode: 403,
          errorCode: 'ACCESS_FORBIDDEN',
        );
      } else if (e.response?.statusCode == 400) {
        throw ApiException(
          'Bad request - invalid parameters: ${e.response?.data?['message'] ?? 'Unknown error'}',
          statusCode: 400,
          errorCode: 'BAD_REQUEST',
        );
      } else {
        throw ApiException(
          'Failed to join AI agent: ${e.message}',
          statusCode: e.response?.statusCode,
          errorCode: 'NETWORK_ERROR',
          originalError: e,
        );
      }
    } catch (e) {
      _onRequestFailure();
      if (e is ApiException) rethrow;
      _logger.e(_tag, 'Unexpected error joining AI agent: $e');
      throw ApiException(
        'Unexpected error during AI agent join: ${e.toString()}',
        errorCode: 'UNEXPECTED_ERROR',
        originalError: e,
      );
    }
  }

  /// Stop AI agent
  /// BLOCKING method - throws exceptions on failure to ensure proper error handling
  Future<bool> stopAiAgent({
    required String agentId,
  }) async {
    try {
      // Check circuit breaker first
      if (_isCircuitBreakerOpen) {
        _logger.e(_tag, 'Circuit breaker is open - rejecting AI agent stop request');
        throw const ApiException(
          'Service temporarily unavailable due to circuit breaker',
          statusCode: 503,
          errorCode: 'CIRCUIT_BREAKER_OPEN',
        );
      }

      // Handle rate limiting
      await _handleRateLimit();

      _logger.i(_tag, 'Stopping AI agent: $agentId');

      // Get the Firebase ID token for authentication
      final idToken = await _getValidToken();
      
      if (idToken == null) {
        _logger.e(_tag, 'Failed to get Firebase ID token for AI agent stop');
        throw const ApiException(
          'Authentication failed - unable to get Firebase token',
          statusCode: 401,
          errorCode: 'AUTH_TOKEN_FAILED',
        );
      }

      // Log the exact data being sent to backend
      final requestData = {
        'agentId': agentId,
      };
      
      _logger.i(_tag, 'Sending stop request to backend with data: $requestData');

      final response = await _dio.post(
        '/api/ai-agent/stop',
        data: requestData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'x-api-key': _apiKey,
          },
        ),
      );

      _onRequestSuccess();

      if (response.statusCode == 200) {
        _logger.i(_tag, 'AI agent successfully stopped: $agentId');
        return true;
      } else {
        _logger.e(_tag, 'Failed to stop AI agent. Status: ${response.statusCode}');
        throw ApiException(
          'Failed to stop AI agent',
          statusCode: response.statusCode,
          errorCode: 'AI_AGENT_STOP_FAILED',
        );
      }
    } on DioException catch (e) {
      _onRequestFailure();
      _logger.e(_tag, 'DioException stopping AI agent: ${e.message}');
      
      if (e.response?.statusCode == 401) {
        throw const ApiException(
          'Authentication failed - invalid Firebase token',
          statusCode: 401,
          errorCode: 'AUTH_FAILED',
        );
      } else if (e.response?.statusCode == 403) {
        throw const ApiException(
          'Access forbidden - invalid API key',
          statusCode: 403,
          errorCode: 'ACCESS_FORBIDDEN',
        );
      } else if (e.response?.statusCode == 400) {
        throw ApiException(
          'Bad request - invalid agent ID: ${e.response?.data?['message'] ?? 'Unknown error'}',
          statusCode: 400,
          errorCode: 'BAD_REQUEST',
        );
      } else if (e.response?.statusCode == 404) {
        throw const ApiException(
          'AI agent not found or already stopped',
          statusCode: 404,
          errorCode: 'AGENT_NOT_FOUND',
        );
      } else {
        throw ApiException(
          'Failed to stop AI agent: ${e.message}',
          statusCode: e.response?.statusCode,
          errorCode: 'NETWORK_ERROR',
          originalError: e,
        );
      }
    } catch (e) {
      _onRequestFailure();
      if (e is ApiException) rethrow;
      _logger.e(_tag, 'Unexpected error stopping AI agent: $e');
      throw ApiException(
        'Unexpected error during AI agent stop: ${e.toString()}',
        errorCode: 'UNEXPECTED_ERROR',
        originalError: e,
      );
    }
  }

  /// Generate Agora token from backend
  /// BLOCKING method - throws exceptions on failure to ensure proper error handling
  Future<AgoraTokenResponse> generateAgoraToken({
    required int uid,
    required String channelId, 
    required String firebaseToken,
  }) async {
    try {
      // Check circuit breaker first
      if (_isCircuitBreakerOpen) {
        _logger.e(_tag, 'Circuit breaker is open - rejecting Agora token request');
        throw const ApiException(
          'Service temporarily unavailable due to circuit breaker',
          statusCode: 503,
          errorCode: 'CIRCUIT_BREAKER_OPEN',
        );
      }

      // Handle rate limiting
      await _handleRateLimit();

      _logger.i(_tag, 'Generating Agora token for channel: $channelId, uid: $uid');

      final response = await _dio.post(
        '/api/agora/generate-token',
        data: {
          'uid': uid.toString(),  // Send uid as string to match backend expectations
          'channelId': channelId, 
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $firebaseToken',
            'x-api-key': _apiKey,  // Use lowercase header as expected by backend
          },
        ),
      );

      _onRequestSuccess();

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // Check if the response indicates success
        if (responseData['success'] == true && responseData.containsKey('data')) {
          _logger.i(_tag, 'Successfully generated Agora token for channel: $channelId');
          return AgoraTokenResponse.fromJson(responseData);
        } else {
          // Handle API-level errors (success: false)
          final errorMessage = responseData['message'] ?? 'Unknown error from token service';
          _logger.e(_tag, 'Token generation failed: $errorMessage');
          throw ApiException(
            'Token generation failed: $errorMessage',
            statusCode: response.statusCode,
            errorCode: 'API_ERROR',
          );
        }
      } else {
        _logger.e(_tag, 'Invalid response from Agora token endpoint: ${response.statusCode}');
        throw ApiException(
          'Invalid response from token generation service',
          statusCode: response.statusCode,
          errorCode: 'INVALID_RESPONSE',
        );
      }
    } on DioException catch (e) {
      _onRequestFailure();
      _logger.e(_tag, 'DioException generating Agora token: ${e.message}');
      
      if (e.response?.statusCode == 401) {
        throw const ApiException(
          'Authentication failed - invalid Firebase token',
          statusCode: 401,
          errorCode: 'AUTH_FAILED',
        );
      } else if (e.response?.statusCode == 403) {
        throw const ApiException(
          'Access forbidden - invalid API key',
          statusCode: 403,
          errorCode: 'ACCESS_FORBIDDEN',
        );
      } else if (e.response?.statusCode == 400) {
        throw ApiException(
          'Bad request - invalid parameters: ${e.response?.data?['message'] ?? 'Unknown error'}',
          statusCode: 400,
          errorCode: 'BAD_REQUEST',
        );
      } else {
        throw ApiException(
          'Failed to generate Agora token: ${e.message}',
          statusCode: e.response?.statusCode,
          errorCode: 'NETWORK_ERROR',
          originalError: e,
        );
      }
    } catch (e) {
      _onRequestFailure();
      _logger.e(_tag, 'Unexpected error generating Agora token: $e');
      throw ApiException(
        'Unexpected error during token generation: ${e.toString()}',
        errorCode: 'UNEXPECTED_ERROR',
        originalError: e,
      );
    }
  }
}
