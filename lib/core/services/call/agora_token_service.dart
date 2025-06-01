import '../api/api_service.dart';
import '../auth/auth_service_interface.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';

/// Exception thrown when token generation fails
class TokenGenerationException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  const TokenGenerationException(
    this.message, {
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() => 'TokenGenerationException: $message';
}

/// Response model for Agora token generation
class AgoraTokenResponse {
  final String token;
  final String channelId;
  final int uid;
  final int expireTime;

  const AgoraTokenResponse({
    required this.token,
    required this.channelId,
    required this.uid,
    required this.expireTime,
  });

  factory AgoraTokenResponse.fromJson(Map<String, dynamic> json) {
    return AgoraTokenResponse(
      token: json['token'] as String,
      channelId: json['channelId'] as String,
      uid: json['uid'] as int,
      expireTime: json['expireTime'] as int,
    );
  }
}

/// Service responsible for fetching Agora tokens from the backend
class AgoraTokenService {
  final ApiService _apiService;
  final AuthServiceInterface _authService;
  final LoggerService _logger;
  static const String _tag = 'AGORA_TOKEN_SERVICE';

  /// Creates a new AgoraTokenService instance
  AgoraTokenService({
    ApiService? apiService,
    AuthServiceInterface? authService,
    LoggerService? logger,
  }) : 
    _apiService = apiService ?? serviceLocator<ApiService>(),
    _authService = authService ?? serviceLocator<AuthServiceInterface>(),
    _logger = logger ?? serviceLocator<LoggerService>();

  /// Generate Agora token for a channel
  /// 
  /// Parameters:
  /// - [uid]: User ID for the call
  /// - [channelId]: Channel ID to join
  /// - [callerPhoto]: URL of the caller's photo
  /// - [callName]: Name/title of the call
  /// 
  /// Returns [AgoraTokenResponse] with token and metadata
  /// Throws [TokenGenerationException] on failure
  Future<AgoraTokenResponse> generateToken({
    required int uid,
    required String channelId,
    required String callerPhoto,
    required String callName,
  }) async {
    try {
      _logger.i(_tag, 'Generating Agora token for channel: $channelId, uid: $uid');

      // Get Firebase ID token for authentication
      final firebaseToken = await _authService.refreshIdToken(forceRefresh: false);
      if (firebaseToken == null) {
        throw const TokenGenerationException(
          'Failed to get Firebase authentication token',
          errorCode: 'AUTH_TOKEN_MISSING',
        );
      }

      // Prepare request data
      final requestData = {
        'uid': uid,
        'channelId': channelId,
        'callerPhoto': callerPhoto,
        'callName': callName,
      };

      _logger.d(_tag, 'Sending token generation request: $requestData');

      // Make API request to generate token
      final response = await _apiService.generateAgoraToken(
        uid: uid,
        channelId: channelId,
        callerPhoto: callerPhoto,
        callName: callName,
        firebaseToken: firebaseToken,
      );

      _logger.i(_tag, 'Successfully generated Agora token for channel: $channelId');
      return response;

    } catch (e) {
      _logger.e(_tag, 'Failed to generate Agora token: $e');
      
      if (e is TokenGenerationException) {
        rethrow;
      }
      
      throw TokenGenerationException(
        'Unexpected error during token generation: ${e.toString()}',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// Generate token with retry logic for better reliability
  /// 
  /// Parameters:
  /// - [uid]: User ID for the call
  /// - [channelId]: Channel ID to join
  /// - [callerPhoto]: URL of the caller's photo
  /// - [callName]: Name/title of the call
  /// - [maxRetries]: Maximum number of retry attempts (default: 3)
  /// 
  /// Returns [AgoraTokenResponse] with token and metadata
  /// Throws [TokenGenerationException] on failure after all retries
  Future<AgoraTokenResponse> generateTokenWithRetry({
    required int uid,
    required String channelId,
    required String callerPhoto,
    required String callName,
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        attempts++;
        _logger.d(_tag, 'Token generation attempt $attempts/$maxRetries');
        
        return await generateToken(
          uid: uid,
          channelId: channelId,
          callerPhoto: callerPhoto,
          callName: callName,
        );
        
      } catch (e) {
        _logger.w(_tag, 'Token generation attempt $attempts failed: $e');
        
        // Don't retry on authentication errors
        if (e is TokenGenerationException && e.errorCode == 'AUTH_TOKEN_MISSING') {
          rethrow;
        }
        
        // If this was the last attempt, rethrow the error
        if (attempts >= maxRetries) {
          _logger.e(_tag, 'All token generation attempts failed');
          rethrow;
        }
        
        // Wait before retrying with exponential backoff
        final delay = Duration(milliseconds: 1000 * attempts);
        _logger.d(_tag, 'Waiting ${delay.inMilliseconds}ms before retry');
        await Future.delayed(delay);
      }
    }
    
    // This should never be reached, but added for completeness
    throw const TokenGenerationException(
      'Token generation failed after all retry attempts',
      errorCode: 'MAX_RETRIES_EXCEEDED',
    );
  }
}
