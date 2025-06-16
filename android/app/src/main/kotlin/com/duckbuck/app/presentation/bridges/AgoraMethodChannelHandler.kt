package com.duckbuck.app.presentation.bridges

import com.duckbuck.app.infrastructure.monitoring.AppLogger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.duckbuck.app.data.agora.AgoraServiceManager
import com.duckbuck.app.data.agora.AgoraService
import android.os.Handler
import android.os.Looper

/**
 * Handles all Agora-related method channel calls from Flutter
 * Provides a clean separation between Flutter communication and Agora service logic
 */
class AgoraMethodChannelHandler(private val context: android.content.Context) {
    
    companion object {
        private const val TAG = "AgoraMethodChannelHandler"
    }
    
    // Method channel for sending events to Flutter
    private var methodChannel: MethodChannel? = null
    
    /**
     * Set the method channel for sending events to Flutter
     */
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        // Try to set up Agora event listener, but it might not be available yet
        // We'll ensure it's set up when the service is actually initialized
        val listenerSetUp = setupAgoraEventListener()
        AppLogger.d(TAG, "Initial event listener setup result: $listenerSetUp")
    }
    
    /**
     * Handle method calls from Flutter
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeAgoraEngine" -> {
                handleInitializeEngine(result)
            }
            "joinChannel" -> {
                handleJoinChannel(call, result)
            }
            // Removed joinChannelAndWaitForUsers - timing now handled in Dart
            "leaveChannel" -> {
                handleLeaveChannel(result)
            }
            "turnMicrophoneOn" -> {
                handleTurnMicrophoneOn(result)
            }
            "turnMicrophoneOff" -> {
                handleTurnMicrophoneOff(result)
            }
            "turnSpeakerOn" -> {
                handleTurnSpeakerOn(result)
            }
            "turnSpeakerOff" -> {
                handleTurnSpeakerOff(result)
            }
            "isEngineActive" -> {
                handleIsEngineActive(result)
            }
            "getRemoteUserCount" -> {
                handleGetRemoteUserCount(result)
            }
            "isMicrophoneMuted" -> {
                handleIsMicrophoneMuted(result)
            }
            "isSpeakerEnabled" -> {
                handleIsSpeakerEnabled(result)
            }
            "isInChannel" -> {
                handleIsInChannel(result)
            }
            "getCurrentChannelName" -> {
                handleGetCurrentChannelName(result)
            }
            "getMyUid" -> {
                handleGetMyUid(result)
            }
            "destroyEngine" -> {
                handleDestroyEngine(result)
            }
            "forceLeaveChannel" -> {
                handleForceLeaveChannel(result)
            }
            "getConnectionState" -> {
                handleGetConnectionState(result)
            }
            else -> {
                AppLogger.w(TAG, "Method not implemented: ${call.method}")
                result.notImplemented()
            }
        }
    }
    
    private fun handleInitializeEngine(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: initializeAgoraEngine")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.initializeEngine() ?: false
            
            // After initializing the engine, ensure event listener is set up
            if (success) {
                AppLogger.d(TAG, "Engine initialized successfully, setting up event listener")
                val listenerSetUp = setupAgoraEventListener()
                AppLogger.d(TAG, "Event listener setup result after engine init: $listenerSetUp")
            }
            
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error initializing engine", e)
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }
    
    private fun handleJoinChannel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val channelName = call.argument<String>("channelName")
            val token = call.argument<String?>("token")
            val uid = call.argument<Int>("uid") ?: 0
            
            AppLogger.d(TAG, "Flutter requested: joinChannel - $channelName")
            
            if (channelName != null) {
                val agoraService = AgoraServiceManager.getValidatedAgoraService()
                val success = agoraService?.joinChannel(channelName, token, uid) ?: false
                result.success(success)
            } else {
                result.error("INVALID_ARGUMENT", "Channel name is required", null)
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error joining channel", e)
            result.error("JOIN_CHANNEL_ERROR", e.message, null)
        }
    }

    private fun handleLeaveChannel(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: leaveChannel")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.leaveChannel() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error leaving channel", e)
            result.error("LEAVE_CHANNEL_ERROR", e.message, null)
        }
    }

    private fun handleTurnMicrophoneOn(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: turnMicrophoneOn")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.turnMicrophoneOn() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error turning microphone on", e)
            result.error("MIC_ON_ERROR", e.message, null)        }
    }
    
    private fun handleTurnMicrophoneOff(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: turnMicrophoneOff")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.turnMicrophoneOff() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error turning microphone off", e)
            result.error("MIC_OFF_ERROR", e.message, null)
        }
    }

    private fun handleTurnSpeakerOn(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: turnSpeakerOn")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.turnSpeakerOn() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error turning speaker on", e)
            result.error("SPEAKER_ON_ERROR", e.message, null)
        }
    }
    
    private fun handleTurnSpeakerOff(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: turnSpeakerOff")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.turnSpeakerOff() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error turning speaker off", e)
            result.error("SPEAKER_OFF_ERROR", e.message, null)
        }
    }
    
    private fun handleIsEngineActive(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: isEngineActive")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val isActive = agoraService?.isEngineInitialized() ?: false
            result.success(isActive)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error checking engine status", e)
            result.error("ENGINE_STATUS_ERROR", e.message, null)
        }
    }

    private fun handleGetRemoteUserCount(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: getRemoteUserCount")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val count = agoraService?.getRemoteUserCount() ?: 0
            result.success(count)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error getting remote user count", e)
            result.error("GET_REMOTE_COUNT_ERROR", e.message, null)
        }
    }

    private fun handleIsMicrophoneMuted(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: isMicrophoneMuted")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val isMuted = agoraService?.isMicrophoneMuted() ?: true
            result.success(isMuted)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error checking microphone mute status", e)
            result.error("MIC_STATUS_ERROR", e.message, null)
        }
    }

    private fun handleIsSpeakerEnabled(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: isSpeakerEnabled")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val isEnabled = agoraService?.isSpeakerEnabled() ?: false
            result.success(isEnabled)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error checking speaker status", e)
            result.error("SPEAKER_STATUS_ERROR", e.message, null)
        }
    }

    private fun handleIsInChannel(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: isInChannel")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val isInChannel = agoraService?.isChannelJoined() ?: false
            result.success(isInChannel)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error checking channel status", e)
            result.error("CHANNEL_STATUS_ERROR", e.message, null)
        }
    }

    private fun handleGetCurrentChannelName(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: getCurrentChannelName")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val channelName = agoraService?.getCurrentChannelName()
            result.success(channelName)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error getting current channel name", e)
            result.error("GET_CHANNEL_NAME_ERROR", e.message, null)
        }
    }

    private fun handleGetMyUid(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: getMyUid")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val uid = agoraService?.getMyUid() ?: 0
            result.success(uid)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error getting my UID", e)
            result.error("GET_UID_ERROR", e.message, null)
        }
    }

    private fun handleDestroyEngine(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: destroyEngine")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            agoraService?.destroy()
            result.success(true)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error destroying engine", e)
            result.error("DESTROY_ENGINE_ERROR", e.message, null)
        }
    }

    private fun handleForceLeaveChannel(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: forceLeaveChannel")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.forceLeaveChannel() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error force leaving channel", e)
            result.error("FORCE_LEAVE_ERROR", e.message, null)
        }
    }

    private fun handleGetConnectionState(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: getConnectionState")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            // Return connection state as integer (0 = disconnected, etc.)
            val state = if (agoraService?.isChannelJoined() == true) 1 else 0
            result.success(state)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error getting connection state", e)
            result.error("CONNECTION_STATE_ERROR", e.message, null)
        }
    }

    /**
     * Set up event listener to forward Agora events to Flutter
     * Returns true if event listener was set successfully, false otherwise
     */
    private fun setupAgoraEventListener(): Boolean {
        val agoraService = AgoraServiceManager.getValidatedAgoraService()
        if (agoraService == null) {
            AppLogger.w(TAG, "Cannot set up event listener: AgoraService not available or not initialized")
            return false
        }
        
        AppLogger.d(TAG, "Setting up event listener for Agora service")
        agoraService.setEventListener(object : AgoraService.AgoraEventListener {
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                sendEventToFlutter("onJoinChannelSuccess", mapOf(
                    "channel" to channel,
                    "uid" to uid,
                    "elapsed" to elapsed
                ))
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                AppLogger.d(TAG, "🎯 Method channel handler received onUserJoined: uid=$uid")
                AppLogger.d(TAG, "Forwarding onUserJoined event to Flutter: uid=$uid")
                sendEventToFlutter("onUserJoined", mapOf(
                    "uid" to uid,
                    "elapsed" to elapsed
                ))
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                sendEventToFlutter("onUserOffline", mapOf(
                    "uid" to uid,
                    "reason" to reason
                ))
            }
            
            override fun onLeaveChannel() {
                sendEventToFlutter("onLeaveChannel", null)
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                sendEventToFlutter("onError", mapOf(
                    "errorCode" to errorCode,
                    "message" to errorMessage
                ))
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                sendEventToFlutter("onMicrophoneToggled", mapOf(
                    "isMuted" to isMuted
                ))
            }
            
            override fun onSpeakerToggled(isEnabled: Boolean) {
                sendEventToFlutter("onSpeakerToggled", mapOf(
                    "isEnabled" to isEnabled
                ))
            }
            
            override fun onUserSpeaking(uid: Int, volume: Int, isSpeaking: Boolean) {
                sendEventToFlutter("onUserSpeaking", mapOf(
                    "uid" to uid,
                    "volume" to volume,
                    "isSpeaking" to isSpeaking
                ))
            }
            
            override fun onAllUsersLeft() {
                sendEventToFlutter("onAllUsersLeft", null)
            }
            
            override fun onChannelEmpty() {
                sendEventToFlutter("onChannelEmpty", null)
            }
        })
        
        AppLogger.d(TAG, "Event listener set up successfully")
        return true
    }
    
    /**
     * Send event to Flutter via method channel
     */
    private fun sendEventToFlutter(method: String, arguments: Map<String, Any>?) {
        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                methodChannel?.invokeMethod(method, arguments)
                AppLogger.d(TAG, "Sent event to Flutter: $method")
            } catch (e: Exception) {
                AppLogger.w(TAG, "Failed to send event to Flutter: $method", e)
            }
        }
    }
}