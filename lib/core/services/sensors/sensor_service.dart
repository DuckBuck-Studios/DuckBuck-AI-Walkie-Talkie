import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../logger/logger_service.dart';
import '../service_locator.dart';

/// Service for managing device sensors during calls
/// Provides proximity simulation using accelerometer and gyroscope data
/// Handles automatic earpiece switching and screen dimming
class SensorService {
  static const String _tag = 'SENSOR_SERVICE';
  
  final LoggerService _logger;
  
  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSubscription;
  
  // State management
  bool _isListening = false;
  bool _isNearUser = false;
  Timer? _stabilityTimer;
  Timer? _autoEarpieceTimer;
  
  // Sensor data for analysis
  AccelerometerEvent? _lastAccelerometerEvent;
  GyroscopeEvent? _lastGyroscopeEvent;
  UserAccelerometerEvent? _lastUserAccelerometerEvent;
  
  // Callbacks for proximity events
  VoidCallback? _onNearUser;
  VoidCallback? _onAwayFromUser;
  
  // Detection thresholds
  static const double _stabilityThreshold = 0.5; // Movement threshold for stability
  static const Duration _stabilityDuration = Duration(milliseconds: 2000);
  static const Duration _sensorSamplingPeriod = SensorInterval.uiInterval;
  
  SensorService({
    LoggerService? logger,
  }) : _logger = logger ?? serviceLocator<LoggerService>();

  /// Whether the sensor service is currently active
  bool get isListening => _isListening;
  
  /// Whether the device is currently in earpiece mode (near user)
  bool get isNearUser => _isNearUser;

  /// Start listening to device sensors for proximity detection
  /// [onNearUser] - Called when device should switch to earpiece mode
  /// [onAwayFromUser] - Called when device should switch to speaker mode
  /// [autoEarpieceDelay] - Automatic switch to earpiece after delay
  Future<void> startListening({
    VoidCallback? onNearUser,
    VoidCallback? onAwayFromUser,
    Duration autoEarpieceDelay = const Duration(seconds: 4),
  }) async {
    if (_isListening) {
      _logger.w(_tag, 'Sensor service already listening');
      return;
    }

    try {
      _logger.i(_tag, 'Starting sensor-based proximity detection');
      
      _onNearUser = onNearUser;
      _onAwayFromUser = onAwayFromUser;
      _isListening = true;
      
      // Start listening to accelerometer events
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: _sensorSamplingPeriod,
      ).listen(
        _handleAccelerometerEvent,
        onError: (error) {
          _logger.w(_tag, 'Accelerometer error: $error');
        },
        cancelOnError: false,
      );
      
      // Start listening to gyroscope events
      _gyroscopeSubscription = gyroscopeEventStream(
        samplingPeriod: _sensorSamplingPeriod,
      ).listen(
        _handleGyroscopeEvent,
        onError: (error) {
          _logger.w(_tag, 'Gyroscope error: $error');
        },
        cancelOnError: false,
      );
      
      // Start listening to user accelerometer events (gravity removed)
      _userAccelerometerSubscription = userAccelerometerEventStream(
        samplingPeriod: _sensorSamplingPeriod,
      ).listen(
        _handleUserAccelerometerEvent,
        onError: (error) {
          _logger.w(_tag, 'User accelerometer error: $error');
        },
        cancelOnError: false,
      );
      
      // Auto-switch to earpiece mode after delay (fallback)
      _autoEarpieceTimer = Timer(autoEarpieceDelay, () {
        _logger.i(_tag, '📱➡️👂 Auto-switching to earpiece mode (timeout)');
        _triggerNearUser();
      });
      
      _logger.i(_tag, '✅ Sensor proximity detection started');
      
    } catch (e) {
      _logger.e(_tag, 'Failed to start sensor service: $e');
      rethrow;
    }
  }

  /// Stop sensor-based proximity detection
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      _logger.i(_tag, 'Stopping sensor proximity detection');
      
      // Cancel all subscriptions
      await _accelerometerSubscription?.cancel();
      await _gyroscopeSubscription?.cancel();
      await _userAccelerometerSubscription?.cancel();
      
      // Cancel timers
      _stabilityTimer?.cancel();
      _autoEarpieceTimer?.cancel();
      
      // Reset state
      _accelerometerSubscription = null;
      _gyroscopeSubscription = null;
      _userAccelerometerSubscription = null;
      _stabilityTimer = null;
      _autoEarpieceTimer = null;
      
      _isListening = false;
      _isNearUser = false;
      _onNearUser = null;
      _onAwayFromUser = null;
      
      _lastAccelerometerEvent = null;
      _lastGyroscopeEvent = null;
      _lastUserAccelerometerEvent = null;
      
      // Restore screen brightness when stopping
      await _brightenScreen();
      
      _logger.i(_tag, '🛑 Sensor proximity detection stopped');
      
    } catch (e) {
      _logger.e(_tag, 'Error stopping sensor service: $e');
    }
  }

  /// Handle accelerometer events (includes gravity)
  void _handleAccelerometerEvent(AccelerometerEvent event) {
    _lastAccelerometerEvent = event;
    _analyzeProximity();
  }

  /// Handle gyroscope events (rotation)
  void _handleGyroscopeEvent(GyroscopeEvent event) {
    _lastGyroscopeEvent = event;
    _analyzeProximity();
  }

  /// Handle user accelerometer events (gravity removed)
  void _handleUserAccelerometerEvent(UserAccelerometerEvent event) {
    _lastUserAccelerometerEvent = event;
    _analyzeProximity();
  }

  /// Analyze sensor data to detect proximity to ear
  void _analyzeProximity() {
    if (!_isListening || 
        _lastAccelerometerEvent == null || 
        _lastGyroscopeEvent == null || 
        _lastUserAccelerometerEvent == null) {
      return;
    }

    // Calculate total acceleration magnitude
    final accel = _lastAccelerometerEvent!;
    final totalAccel = (accel.x * accel.x + accel.y * accel.y + accel.z * accel.z).abs();
    
    // Calculate gyroscope magnitude (how much rotation)
    final gyro = _lastGyroscopeEvent!;
    final totalGyro = (gyro.x * gyro.x + gyro.y * gyro.y + gyro.z * gyro.z).abs();
    
    // Calculate user acceleration magnitude (movement without gravity)
    final userAccel = _lastUserAccelerometerEvent!;
    final totalUserAccel = (userAccel.x * userAccel.x + userAccel.y * userAccel.y + userAccel.z * userAccel.z).abs();
    
    _logger.d(_tag, 'Sensor data - Accel: ${totalAccel.toStringAsFixed(2)}, '
                   'Gyro: ${totalGyro.toStringAsFixed(2)}, '
                   'UserAccel: ${totalUserAccel.toStringAsFixed(2)}');
    
    // Detect if phone is stable and in ear-like position
    final isStable = totalGyro < _stabilityThreshold && totalUserAccel < _stabilityThreshold;
    final isPotentialEarPosition = totalAccel > 8.0 && totalAccel < 12.0; // Around gravity level
    
    if (isStable && isPotentialEarPosition && !_isNearUser) {
      // Start stability timer to confirm position
      _stabilityTimer?.cancel();
      _stabilityTimer = Timer(_stabilityDuration, () {
        _logger.i(_tag, '📱➡️👂 Stable ear position detected - switching to earpiece');
        _triggerNearUser();
      });
    } else if ((!isStable || !isPotentialEarPosition) && _isNearUser) {
      // Phone moved away from ear
      _stabilityTimer?.cancel();
      _logger.i(_tag, '👂➡️📱 Movement detected - switching to speaker');
      _triggerAwayFromUser();
    }
  }

  /// Manually trigger earpiece mode (near user)
  void triggerNearUser() {
    if (_isListening) {
      _triggerNearUser();
    }
  }

  /// Manually trigger speaker mode (away from user)  
  void triggerAwayFromUser() {
    if (_isListening) {
      _triggerAwayFromUser();
    }
  }

  /// Internal method to trigger near user state
  void _triggerNearUser() {
    if (!_isNearUser) {
      _isNearUser = true;
      _logger.i(_tag, '📱➡️👂 Device brought to ear - switching to earpiece mode');
      _dimScreen();
      _onNearUser?.call();
    }
  }

  /// Internal method to trigger away from user state
  void _triggerAwayFromUser() {
    if (_isNearUser) {
      _isNearUser = false;
      _logger.i(_tag, '👂➡️📱 Device moved away from ear - switching to speaker mode');
      _brightenScreen();
      _onAwayFromUser?.call();
    }
  }

  /// Dim the screen when phone is near ear
  Future<void> _dimScreen() async {
    try {
      await ScreenBrightness().setScreenBrightness(0.0);
      _logger.d(_tag, '🔅 Screen dimmed for earpiece mode');
    } catch (e) {
      _logger.w(_tag, 'Failed to dim screen: $e');
    }
  }

  /// Restore screen brightness when phone is away from ear
  Future<void> _brightenScreen() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
      _logger.d(_tag, '🔆 Screen brightness restored');
    } catch (e) {
      _logger.w(_tag, 'Failed to restore screen brightness: $e');
    }
  }

  /// Toggle between earpiece and speaker mode
  void toggleProximityMode() {
    if (_isListening) {
      if (_isNearUser) {
        _triggerAwayFromUser();
      } else {
        _triggerNearUser();
      }
    }
  }

  /// Get current sensor readings for debugging
  Map<String, dynamic> getCurrentSensorData() {
    return {
      'isListening': _isListening,
      'isNearUser': _isNearUser,
      'accelerometer': _lastAccelerometerEvent != null ? {
        'x': _lastAccelerometerEvent!.x,
        'y': _lastAccelerometerEvent!.y,
        'z': _lastAccelerometerEvent!.z,
      } : null,
      'gyroscope': _lastGyroscopeEvent != null ? {
        'x': _lastGyroscopeEvent!.x,
        'y': _lastGyroscopeEvent!.y,
        'z': _lastGyroscopeEvent!.z,
      } : null,
      'userAccelerometer': _lastUserAccelerometerEvent != null ? {
        'x': _lastUserAccelerometerEvent!.x,
        'y': _lastUserAccelerometerEvent!.y,
        'z': _lastUserAccelerometerEvent!.z,
      } : null,
    };
  }

  /// Dispose the service
  void dispose() {
    stopListening();
  }
}
