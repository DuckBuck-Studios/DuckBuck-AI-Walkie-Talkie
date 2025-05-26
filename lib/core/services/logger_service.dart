import 'package:flutter/foundation.dart';

/// A centralized logging service for the application
/// 
/// Provides different log levels and consistent formatting across the app
class LoggerService {
  // Singleton instance
  static final LoggerService _instance = LoggerService._internal();
  
  // Factory constructor to return singleton instance
  factory LoggerService() => _instance;
  
  // Private constructor
  LoggerService._internal();

  /// Log an informational message
  void info(String tag, String message) {
    _log('✅ INFO', tag, message);
  }
  
  /// Log a warning message
  void warning(String tag, String message) {
    _log('⚠️ WARNING', tag, message);
  }
  
  /// Log an error message
  void error(String tag, String message) {
    _log('❌ ERROR', tag, message);
  }
  
  /// Log a debug message
  void debug(String tag, String message) {
    if (kDebugMode) {
      _log('🔍 DEBUG', tag, message);
    }
  }
  
  /// Internal logging method with consistent format
  void _log(String level, String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$level] [$tag] $message');
    }
    
    // In production, you could send logs to a service like Firebase Analytics,
    // Crashlytics, or a dedicated logging service
  }
}
