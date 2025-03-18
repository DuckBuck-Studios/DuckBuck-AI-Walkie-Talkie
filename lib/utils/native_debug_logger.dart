import 'dart:io';
import 'package:flutter/services.dart';

class NativeDebugLogger {
  static const MethodChannel _channel = MethodChannel('com.example.duckbuck/native_debug');
  
  /// Get the path to the native debug log file
  static Future<String> getDebugLogPath() async {
    try {
      final String path = await _channel.invokeMethod('getDebugLogPath');
      return path;
    } on PlatformException catch (e) {
      print('Failed to get debug log path: ${e.message}');
      return '';
    }
  }
  
  /// Start a new log session with a reason
  static Future<void> startNewSession(String reason) async {
    try {
      await _channel.invokeMethod('startNewLogSession', {'reason': reason});
    } on PlatformException catch (e) {
      print('Failed to start new log session: ${e.message}');
    }
  }
  
  /// Log an event from Flutter to the native log
  static Future<void> logEvent(String tag, String message, [Map<String, dynamic>? data]) async {
    try {
      await _channel.invokeMethod('logEvent', {
        'tag': tag,
        'message': message,
        'data': data,
      });
    } on PlatformException catch (e) {
      print('Failed to log event: ${e.message}');
    }
  }
  
  /// Read the debug log file content
  static Future<String> readDebugLog() async {
    try {
      final path = await getDebugLogPath();
      if (path.isEmpty) return 'Log path not available';
      
      final file = File(path);
      if (!await file.exists()) return 'Log file does not exist';
      
      return await file.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }
  
  /// Clear all logs by resetting the log file
  static Future<bool> clearLogs() async {
    try {
      // Try to use the method channel first
      try {
        final result = await _channel.invokeMethod('clearLogs');
        return result == true;
      } on PlatformException {
        // If the native method isn't implemented, do it in Dart
        final path = await getDebugLogPath();
        if (path.isEmpty) return false;
        
        final file = File(path);
        if (!await file.exists()) return false;
        
        // Create a new empty log file with just the initial structure
        final initialJson = {
          'app_sessions': [],
          'created_at': DateTime.now().toIso8601String(),
          'cleared_at': DateTime.now().toIso8601String()
        };
        
        await file.writeAsString(initialJson.toString());
        return true;
      }
    } catch (e) {
      print('Failed to clear logs: $e');
      return false;
    }
  }
} 