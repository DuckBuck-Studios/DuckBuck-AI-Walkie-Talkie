import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// A service for unified logging throughout the application
/// 
/// Provides different log levels and consistent formatting while
/// respecting the build configuration (debug vs release)
class LoggerService {
  // Singleton implementation
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  // Logger instance configuration
  final Logger _logger = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    output: ConsoleOutput(),
  );

  /// Log debug information
  /// In release builds, debug and verbose logs are disabled
  void d(String tag, String message) {
    _logger.d('[$tag] $message');
  }

  /// Log information messages
  void i(String tag, String message) {
    _logger.i('[$tag] $message');
  }

  /// Log warning messages
  void w(String tag, String message) {
    _logger.w('[$tag] $message');
  }

  /// Log error messages
  void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e('[$tag] $message', error: error, stackTrace: stackTrace);
  }
}

/// Custom filter to control log output based on build configuration
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In release mode, only show warnings and above
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    // In debug mode, show all logs
    return true;
  }
}
