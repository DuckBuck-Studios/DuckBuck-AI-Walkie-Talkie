import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/repositories/ai_agent_repository.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/sensors/sensor_service.dart';
import '../../../core/exceptions/ai_agent_exceptions.dart';
import '../models/ai_agent_models.dart';

/// Provider for managing AI agent state and operations
class AiAgentProvider extends ChangeNotifier {
  final AiAgentRepository _repository;
  final LoggerService _logger;
  final SensorService _sensorService;
  
  static const String _tag = 'AI_AGENT_PROVIDER';
  
  // Current state
  AiAgentState _state = AiAgentState.idle;
  AiAgentSession? _currentSession;
  String? _errorMessage;
  
  // Timer for tracking agent usage
  Timer? _usageTimer;
  Timer? _autoStopTimer;
  Timer? _firebaseSyncTimer;
  
  // Sync interval
  static const Duration _firebaseSyncInterval = Duration(seconds: 5);
  
  // Stream subscriptions
  StreamSubscription<int>? _timeStreamSubscription;
  
  // User data
  String? _currentUid;
  int _remainingTimeSeconds = 0;
  bool _isAiSpeaking = false;
  bool _isMicrophoneMuted = false;
  bool _isSpeakerEnabled = true;
  
  /// Creates a new AiAgentProvider
  AiAgentProvider({
    AiAgentRepository? repository,
    LoggerService? logger,
    SensorService? sensorService,
  }) : _repository = repository ?? serviceLocator<AiAgentRepository>(),
       _logger = logger ?? serviceLocator<LoggerService>(),
       _sensorService = sensorService ?? serviceLocator<SensorService>();

  // Getters
  AiAgentState get state => _state;
  AiAgentSession? get currentSession => _currentSession;
  String? get errorMessage => _errorMessage;
  int get remainingTimeSeconds => _remainingTimeSeconds;
  bool get isAgentRunning => _state == AiAgentState.running;
  bool get canStartAgent => _state == AiAgentState.idle && _remainingTimeSeconds > 0;
  bool get isAiSpeaking => _isAiSpeaking && isAgentRunning;
  bool get isMicrophoneMuted => _isMicrophoneMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  
  /// Get formatted remaining time
  String get formattedRemainingTime {
    return _formatTime(_remainingTimeSeconds);
  }
  
  /// Get formatted elapsed time for current session
  String get formattedElapsedTime {
    if (_currentSession == null) return '0:00';
    return _formatTime(_currentSession!.elapsedSeconds);
  }

  /// Initialize provider with user ID
  Future<void> initialize(String uid) async {
    try {
      _logger.i(_tag, 'Initializing AI agent provider for user: $uid');
      
      _currentUid = uid;
      
      // Get initial remaining time
      _remainingTimeSeconds = await _repository.getUserRemainingTime(uid);
      
      // Listen to real-time time updates
      _timeStreamSubscription?.cancel();
      _timeStreamSubscription = _repository.getUserRemainingTimeStream(uid).listen(
        (remainingTime) {
          _logger.d(_tag, 'Time update received: ${_formatTime(remainingTime)}');
          _remainingTimeSeconds = remainingTime;
          
          // Auto-stop agent if time runs out
          if (remainingTime <= 0 && isAgentRunning) {
            _logger.w(_tag, 'Time exhausted, auto-stopping agent');
            stopAgent();
          }
          
          notifyListeners();
        },
        onError: (error) {
          _logger.e(_tag, 'Error in time stream: $error');
          _setError('Failed to get real-time time updates');
        },
      );
      
      _logger.i(_tag, 'AI agent provider initialized successfully');
      notifyListeners();
    } catch (e) {
      _logger.e(_tag, 'Error initializing AI agent provider: $e');
      _setError('Failed to initialize AI agent service');
    }
  }

  /// Start AI agent with immediate UI update after channel join
  Future<bool> startAgent() async {
    if (_currentUid == null) {
      _setError('User not initialized');
      return false;
    }
    
    if (_state != AiAgentState.idle) {
      _logger.w(_tag, 'Cannot start agent, current state: $_state');
      return false;
    }
    
    if (_remainingTimeSeconds <= 0) {
      _setError('No remaining AI agent time');
      return false;
    }

    try {
      _logger.i(_tag, 'Starting AI agent with immediate UI update');
      _setState(AiAgentState.starting);
      
      // Join Agora channel first and update UI immediately
      final agoraJoined = await _repository.joinAgoraChannelOnly(uid: _currentUid!);
      
      if (agoraJoined) {
        // Create temporary session immediately after Agora join
        _currentSession = AiAgentSession(
          agentData: AiAgentData(
            agentId: 'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
            agentName: 'AI Assistant',
            channelName: 'ai_$_currentUid',
            status: 'connecting',
            createTs: DateTime.now().millisecondsSinceEpoch,
          ),
          startTime: DateTime.now(),
          uid: _currentUid!,
        );
        
        // Stay in starting state until backend connects
        // _setState(AiAgentState.running); // Remove this line
        
        // Initialize audio states (this will work even in starting state)
        await _initializeAudioStates();
        
        _startUsageTracking();
        _setAutoStopTimer();
        
        _logger.i(_tag, 'Agora channel joined, connecting to backend AI agent...');
        
        // Start backend AI agent connection in background
        _connectAiAgentInBackground();
        
        return true;
      } else {
        _setError('Failed to join Agora channel');
        _setState(AiAgentState.idle);
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error starting AI agent: $e');
      if (e is AiAgentException) {
        _setError(e.message);
      } else {
        _setError('Failed to start AI agent');
      }
      _setState(AiAgentState.idle);
      return false;
    }
  }

  /// Connect AI agent in background after UI is already updated
  Future<void> _connectAiAgentInBackground() async {
    try {
      _logger.i(_tag, 'Connecting AI agent in background');
      
      // Get the actual backend response
      final responseData = await _repository.joinAiAgentOnly(
        uid: _currentUid!,
        channelName: 'ai_$_currentUid',
        remainingTimeSeconds: _remainingTimeSeconds,
      );
      
      if (responseData != null && _currentSession != null) {
        // Parse the real response from backend
        final response = AiAgentResponse.fromJson(responseData);
        
        if (response.success && response.data != null) {
          // Update session with real agent data from backend
          _currentSession = AiAgentSession(
            agentData: response.data!,
            startTime: _currentSession!.startTime, // Keep original start time
            uid: _currentUid!,
          );
          
          // NOW set the state to running since backend is connected
          _setState(AiAgentState.running);
          
          _logger.i(_tag, 'AI agent connected successfully with real agent ID: ${response.data!.agentId}');
          notifyListeners(); // Update UI with real agent data
        } else {
          _logger.w(_tag, 'Backend AI agent connection failed: ${response.message}');
          // Set error state but don't stop the session since Agora is still connected
          _setState(AiAgentState.error);
          _setError('AI Agent connection failed, but you can still use audio features');
        }
      } else {
        _logger.w(_tag, 'Backend AI agent connection returned null response');
        // Set error state but don't stop the session
        _setState(AiAgentState.error);
        _setError('AI Agent connection failed, but you can still use audio features');
      }
    } catch (e) {
      _logger.e(_tag, 'Error connecting AI agent in background: $e');
      // Set error state but don't stop the session on background error
      _setState(AiAgentState.error);
      _setError('AI Agent connection failed, but you can still use audio features');
    }
  }

  /// Stop AI agent with full cleanup
  Future<bool> stopAgent() async {
    if (_currentSession == null) {
      _logger.w(_tag, 'No active agent session to stop');
      return false;
    }
    
    if (_state == AiAgentState.stopping) {
      _logger.w(_tag, 'Agent already stopping');
      return false;
    }

    try {
      _logger.i(_tag, 'Stopping AI agent');
      _setState(AiAgentState.stopping);
      
      // Stop the agent and leave Agora channel through repository
      final success = await _repository.stopAgentWithFullCleanup(
        agentId: _currentSession!.agentData.agentId,
        uid: _currentSession!.uid,
        timeUsedSeconds: _currentSession!.elapsedSeconds,
      );
      
      // Clean up regardless of success to prevent stuck state
      _stopUsageTracking();
      await _stopProximitySensor();
      _currentSession = null;
      _setState(AiAgentState.idle);
      
      if (success) {
        _logger.i(_tag, 'AI agent stopped successfully');
        return true;
      } else {
        _setError('Failed to stop AI agent completely');
        return false;
      }
    } catch (e) {
      _logger.e(_tag, 'Error stopping AI agent: $e');
      
      // Clean up on error to prevent stuck state
      _stopUsageTracking();
      await _stopProximitySensor();
      _currentSession = null;
      _setState(AiAgentState.idle);
      
      if (e is AiAgentException) {
        _setError(e.message);
      } else {
        _setError('Failed to stop AI agent');
      }
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Toggle microphone mute/unmute
  Future<bool> toggleMicrophone() async {
    // Allow toggling during starting, running, or error states (when we have a session)
    if (_currentSession == null) return false;
    
    try {
      final success = await _repository.toggleMicrophone();
      if (success) {
        // Get the actual current state from the repository after toggle using async method
        _isMicrophoneMuted = await _repository.isMicrophoneMutedAsync();
        _logger.i(_tag, 'Microphone toggled successfully. New state: muted=$_isMicrophoneMuted');
        notifyListeners();
      } else {
        _logger.w(_tag, 'Failed to toggle microphone');
      }
      return success;
    } catch (e) {
      _logger.e(_tag, 'Error toggling microphone: $e');
      return false;
    }
  }

  /// Toggle speaker on/off
  Future<bool> toggleSpeaker() async {
    // Allow toggling during starting, running, or error states (when we have a session)
    if (_currentSession == null) return false;
    
    try {
      _logger.i(_tag, 'Toggle speaker called. Current state: $_isSpeakerEnabled');
      
      // Get the current state before toggle
      final currentStateBefore = await _repository.isSpeakerEnabledAsync();
      _logger.i(_tag, 'Speaker state before toggle: $currentStateBefore');
      
      final success = await _repository.toggleSpeaker();
      _logger.i(_tag, 'Toggle speaker result: $success');
      
      if (success) {
        // Get the actual current state from the repository after toggle using async method
        _isSpeakerEnabled = await _repository.isSpeakerEnabledAsync();
        _logger.i(_tag, 'Speaker toggled successfully. New state: $_isSpeakerEnabled');
        
        // Update proximity sensor state based on new speaker mode
        await _updateProximitySensorState();
        
        notifyListeners();
      } else {
        _logger.w(_tag, 'Failed to toggle speaker');
      }
      return success;
    } catch (e) {
      _logger.e(_tag, 'Error toggling speaker: $e');
      return false;
    }
  }

  /// Refresh remaining time from server
  Future<void> refreshRemainingTime() async {
    if (_currentUid == null) return;
    
    try {
      final remainingTime = await _repository.getUserRemainingTime(_currentUid!);
      _remainingTimeSeconds = remainingTime;
      notifyListeners();
    } catch (e) {
      _logger.e(_tag, 'Error refreshing remaining time: $e');
    }
  }

  /// Start tracking agent usage time with Firebase sync
  void _startUsageTracking() {
    _usageTimer?.cancel();
    _firebaseSyncTimer?.cancel();
    
    int lastSyncedTime = _remainingTimeSeconds;
    
    // Timer for local UI updates every second
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Update remaining time locally for real-time UI updates
      if (_remainingTimeSeconds > 0) {
        _remainingTimeSeconds--;
        
        // Simulate AI speaking patterns (random intervals for demo)
        if (isAgentRunning) {
          // Random speaking pattern: speak for 2-4 seconds, then pause for 1-3 seconds
          final random = DateTime.now().millisecondsSinceEpoch % 100;
          if (random < 30) { // ~30% chance to start speaking
            _setAiSpeaking(true);
          } else if (random > 80) { // ~20% chance to stop speaking
            _setAiSpeaking(false);
          }
        }
        
        notifyListeners();
        
        // Auto-stop when time reaches 0
        if (_remainingTimeSeconds <= 0) {
          _logger.w(_tag, 'Time exhausted during usage tracking, auto-stopping agent');
          // Auto-stop with Agora cleanup
          stopAgent();
        }
      }
    });
    
    // Timer for Firebase sync every 5 seconds
    _firebaseSyncTimer = Timer.periodic(_firebaseSyncInterval, (timer) async {
      if (_currentSession != null && _currentUid != null) {
        try {
          final timeUsedSinceLastSync = lastSyncedTime - _remainingTimeSeconds;
          
          if (timeUsedSinceLastSync > 0) {
            _logger.d(_tag, 'Syncing ${timeUsedSinceLastSync}s usage to Firebase');
            
            // Update Firebase with current remaining time
            await _repository.updateUserRemainingTime(
              uid: _currentUid!,
              timeUsedSeconds: timeUsedSinceLastSync,
            );
            
            lastSyncedTime = _remainingTimeSeconds;
            _logger.d(_tag, 'Firebase sync completed. Remaining: ${_formatTime(_remainingTimeSeconds)}');
          }
        } catch (e) {
          _logger.e(_tag, 'Error syncing time to Firebase: $e');
          // Don't stop the agent on sync errors, just log them
        }
      }
    });
  }

  /// Stop usage tracking timer
  void _stopUsageTracking() {
    _usageTimer?.cancel();
    _usageTimer = null;
    _firebaseSyncTimer?.cancel();
    _firebaseSyncTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _isAiSpeaking = false; // Stop speaking animation when stopping
  }

  /// Set auto-stop timer based on remaining time
  void _setAutoStopTimer() {
    _autoStopTimer?.cancel();
    
    if (_remainingTimeSeconds > 0) {
      _autoStopTimer = Timer(Duration(seconds: _remainingTimeSeconds), () {
        _logger.w(_tag, 'Auto-stop timer triggered - time expired');
        if (isAgentRunning) {
          // Auto-stop with full cleanup when timer expires
          stopAgent();
        }
      });
    }
  }

  /// Update proximity sensor based on speaker state
  /// Only activate proximity detection when in earpiece mode for screen dimming
  Future<void> _updateProximitySensorState() async {
    _logger.i(_tag, '🔧 DEBUG: _updateProximitySensorState called. Session: ${_currentSession != null}, Speaker enabled: $_isSpeakerEnabled, Sensor listening: ${_sensorService.isListening}');
    
    if (_currentSession == null) {
      _logger.i(_tag, '🔧 DEBUG: No session exists, stopping proximity sensor');  
      await _stopProximitySensor();
      return;
    }

    if (!_isSpeakerEnabled) {
      // In earpiece mode - start proximity detection for screen dimming
      if (!_sensorService.isListening) {
        _logger.i(_tag, 'Earpiece mode - starting proximity sensor for screen control');
        await _startProximitySensorForScreenControl();
      } else {
        _logger.i(_tag, '🔧 DEBUG: Earpiece mode but sensor already listening');
      }
    } else {
      // In speaker mode - stop proximity detection
      if (_sensorService.isListening) {
        _logger.i(_tag, 'Speaker mode - stopping proximity sensor');
        await _stopProximitySensor();
      } else {
        _logger.i(_tag, '🔧 DEBUG: Speaker mode and sensor already stopped');
      }
    }
  }

  /// Start proximity sensor for screen control in earpiece mode
  Future<void> _startProximitySensorForScreenControl() async {
    try {
      _logger.i(_tag, 'Starting proximity sensor for screen control in earpiece mode');
      
      await _sensorService.startListening(
        onProximityChanged: (isNear) {
          _logger.i(_tag, 'Proximity changed: ${isNear ? "near ear" : "away from ear"}');
        },
        onNear: () {
          _logger.i(_tag, 'Phone near ear - screen turns off automatically (earpiece mode)');
        },
        onAway: () {
          _logger.i(_tag, 'Phone away from ear - screen turns on automatically');
        },
      );
      
      _logger.i(_tag, '🔧 DEBUG: Proximity sensor started successfully. Listening: ${_sensorService.isListening}');
      
    } catch (e) {
      _logger.e(_tag, 'Error starting proximity sensor for screen control: $e');
    }
  }

  /// Stop proximity sensor detection
  Future<void> _stopProximitySensor() async {
    try {
      _logger.i(_tag, 'Stopping proximity sensor detection');
      await _sensorService.stopListening();
    } catch (e) {
      _logger.e(_tag, 'Error stopping proximity sensor: $e');
    }
  }

  /// Set provider state
  void _setState(AiAgentState newState) {
    if (_state != newState) {
      _logger.d(_tag, 'State changed: $_state -> $newState');
      _state = newState;
      _errorMessage = null; // Clear error when state changes
      notifyListeners();
    }
  }

  /// Set error message
  void _setError(String message) {
    _logger.e(_tag, 'Error: $message');
    _errorMessage = message;
    notifyListeners();
  }
  
  /// Set AI speaking state
  void _setAiSpeaking(bool speaking) {
    if (_isAiSpeaking != speaking) {
      _isAiSpeaking = speaking;
      // Don't call notifyListeners here to avoid extra rebuilds
      // The timer already calls notifyListeners
    }
  }

  /// Initialize audio states when starting agent
  Future<void> _initializeAudioStates() async {
    try {
      _logger.d(_tag, 'Initializing audio states');
      // Sync with actual Agora states using async methods
      _isMicrophoneMuted = await _repository.isMicrophoneMutedAsync();
      _isSpeakerEnabled = await _repository.isSpeakerEnabledAsync();
      _logger.i(_tag, 'Audio states initialized - mic muted: $_isMicrophoneMuted, speaker enabled: $_isSpeakerEnabled');
      
      // Debug: Print the actual states
      // Initial audio states logged via proper logger
      _logger.d(_tag, 'Initial mic state: $_isMicrophoneMuted');
      _logger.d(_tag, 'Initial speaker state: $_isSpeakerEnabled');
      
      // Update proximity sensor based on initial speaker state
      _logger.i(_tag, '🔧 DEBUG: About to update proximity sensor state. Speaker enabled: $_isSpeakerEnabled, Session exists: ${_currentSession != null}');
      await _updateProximitySensorState();
      _logger.i(_tag, '🔧 DEBUG: Proximity sensor state updated. Sensor listening: ${_sensorService.isListening}');
      
      notifyListeners();
    } catch (e) {
      _logger.e(_tag, 'Error initializing audio states: $e');
      // Use default states on error
      _isMicrophoneMuted = false;
      _isSpeakerEnabled = true;
      // Using default states due to error - logged via proper logger
      _logger.w(_tag, 'Using default audio states due to error');
    }
  }

  /// Format time in MM:SS or HH:MM:SS format
  String _formatTime(int seconds) {
    if (seconds <= 0) return '0:00';
    
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _logger.d(_tag, 'Disposing AI agent provider');
    
    // Cancel all timers
    _stopUsageTracking();
    
    // Stop proximity sensor
    _stopProximitySensor();
    
    // Cancel stream subscription
    _timeStreamSubscription?.cancel();
    
    // Dispose repository resources
    _repository.dispose();
    
    super.dispose();
  }
}
