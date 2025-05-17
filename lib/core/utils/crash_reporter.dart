import 'dart:async';

import 'package:flutter/foundation.dart';
import '../services/service_locator.dart';
import '../services/firebase/firebase_crashlytics_service.dart';

/// Utility class for handling errors and reporting them to Crashlytics
class CrashReporter {
  /// Wrap any function with crash reporting
  /// 
  /// Usage:
  /// ```dart
  /// final result = await CrashReporter.wrap(
  ///   () => someRiskyFunction(),
  ///   feature: 'Payment Processing',
  /// );
  /// ```
  static Future<T?> wrap<T>(
    Future<T> Function() fn, {
    required String feature,
    String? operation,
    Map<String, dynamic>? additionalInfo,
    bool fatal = false,
    T? fallbackValue,
    Function(Object error, StackTrace stack)? onError,
  }) async {
    try {
      final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
      
      // Set the current feature for better error attribution
      await crashlytics.setCurrentFeature(feature);
      
      if (operation != null) {
        await crashlytics.log('Starting operation: $operation in $feature');
      }
      
      // Set any additional context information
      if (additionalInfo != null) {
        for (final entry in additionalInfo.entries) {
          await crashlytics.setCustomKey(entry.key, entry.value.toString());
        }
      }
      
      // Execute the function
      final result = await fn();
      
      // Log successful completion
      if (operation != null) {
        await crashlytics.log('Completed operation: $operation in $feature');
      }
      
      return result;
    } catch (e, stack) {
      // Report the error to Crashlytics
      final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
      
      await crashlytics.recordError(
        e,
        stack,
        reason: 'Error in $feature${operation != null ? " during $operation" : ""}',
        fatal: fatal,
        information: {
          'feature': feature,
          'operation': operation ?? 'unknown',
          ...?additionalInfo,
        },
      );
      
      // Execute custom error handler if provided
      if (onError != null) {
        onError(e, stack);
      } else if (kDebugMode) {
        debugPrint('Error in $feature: $e\n$stack');
      }
      
      // Return fallback value if provided
      return fallbackValue;
    }
  }
  
  /// Wrap a synchronous function with crash reporting
  static T? wrapSync<T>(
    T Function() fn, {
    required String feature,
    String? operation,
    Map<String, dynamic>? additionalInfo,
    bool fatal = false,
    T? fallbackValue,
    Function(Object error, StackTrace stack)? onError,
  }) {
    try {
      final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
      crashlytics.setCurrentFeature(feature);
      
      if (operation != null) {
        crashlytics.log('Executing: $operation in $feature');
      }
      
      // Execute the function
      final result = fn();
      
      return result;
    } catch (e, stack) {
      // Report the error to Crashlytics
      final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
      
      crashlytics.recordError(
        e,
        stack,
        reason: 'Error in $feature${operation != null ? " during $operation" : ""}',
        fatal: fatal,
        information: {
          'feature': feature,
          'operation': operation ?? 'unknown',
          ...?additionalInfo,
        },
      );
      
      // Execute custom error handler if provided
      if (onError != null) {
        onError(e, stack);
      } else if (kDebugMode) {
        debugPrint('Error in $feature: $e\n$stack');
      }
      
      // Return fallback value if provided
      return fallbackValue;
    }
  }
  
  /// Log a non-fatal error to Crashlytics
  static Future<void> logError(
    Object error, 
    StackTrace stack, {
    required String feature,
    String? operation,
    Map<String, dynamic>? additionalInfo,
    bool fatal = false,
  }) async {
    final crashlytics = serviceLocator<FirebaseCrashlyticsService>();
    
    await crashlytics.recordError(
      error,
      stack,
      reason: 'Error in $feature${operation != null ? " during $operation" : ""}',
      fatal: fatal,
      information: {
        'feature': feature,
        'operation': operation ?? 'unknown',
        ...?additionalInfo,
      },
    );
  }
}
