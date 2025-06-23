import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

/// Service class to handle proximity sensor functionality
/// Provides screen-off behavior when device is near user's ear
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<dynamic>? _streamSubscription;
  bool _isListening = false;
  bool _isNear = false;

  // Callbacks for proximity events
  Function(bool isNear)? _onProximityChanged;
  VoidCallback? _onNearCallback;
  VoidCallback? _onAwayCallback;

  /// Get current proximity state
  bool get isNear => _isNear;

  /// Check if sensor is currently listening
  bool get isListening => _isListening;

  /// Start listening to proximity sensor events
  /// [onProximityChanged] - Callback when proximity state changes
  /// [onNear] - Callback when device is near
  /// [onAway] - Callback when device is away
  Future<void> startListening({
    Function(bool isNear)? onProximityChanged,
    VoidCallback? onNear,
    VoidCallback? onAway,
  }) async {
    if (_isListening) {
      if (foundation.kDebugMode) {
        debugPrint('SensorService: Already listening to proximity sensor');
      }
      return;
    }

    _onProximityChanged = onProximityChanged;
    _onNearCallback = onNear;
    _onAwayCallback = onAway;

    try {
      // Error handling setup
      FlutterError.onError = (FlutterErrorDetails details) {
        if (foundation.kDebugMode) {
          FlutterError.dumpErrorToConsole(details);
        }
      };

      // Enable proximity screen off functionality (Android only)
      // Requires WAKE_LOCK permission in AndroidManifest.xml
      await ProximitySensor.setProximityScreenOff(true).onError((error, stackTrace) {
        if (foundation.kDebugMode) {
          debugPrint('SensorService: Could not enable screen off functionality - $error');
        }
        return null;
      });

      // Start listening to proximity sensor events
      _streamSubscription = ProximitySensor.events.listen((int event) {
        final bool wasNear = _isNear;
        _isNear = event > 0;

        if (foundation.kDebugMode) {
          debugPrint('SensorService: Proximity sensor event = $event, isNear = $_isNear');
        }

        // Only trigger callbacks if state actually changed
        if (wasNear != _isNear) {
          _onProximityChanged?.call(_isNear);

          if (_isNear) {
            _onNearCallback?.call();
          } else {
            _onAwayCallback?.call();
          }
        }
      });

      _isListening = true;

      if (foundation.kDebugMode) {
        debugPrint('SensorService: Started listening to proximity sensor');
      }
    } catch (e) {
      if (foundation.kDebugMode) {
        debugPrint('SensorService: Error starting proximity sensor - $e');
      }
      rethrow;
    }
  }

  /// Stop listening to proximity sensor events
  Future<void> stopListening() async {
    if (!_isListening) {
      if (foundation.kDebugMode) {
        debugPrint('SensorService: Not currently listening to proximity sensor');
      }
      return;
    }

    try {
      // Cancel the stream subscription
      await _streamSubscription?.cancel();
      _streamSubscription = null;

      // Disable proximity screen off functionality (Android only)
      await ProximitySensor.setProximityScreenOff(false).onError((error, stackTrace) {
        if (foundation.kDebugMode) {
          debugPrint('SensorService: Could not disable screen off functionality - $error');
        }
        return null;
      });

      _isListening = false;
      _isNear = false;
      _onProximityChanged = null;
      _onNearCallback = null;
      _onAwayCallback = null;

      if (foundation.kDebugMode) {
        debugPrint('SensorService: Stopped listening to proximity sensor');
      }
    } catch (e) {
      if (foundation.kDebugMode) {
        debugPrint('SensorService: Error stopping proximity sensor - $e');
      }
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    stopListening();
  }
}
