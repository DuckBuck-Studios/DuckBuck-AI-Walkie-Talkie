package com.duckbuck.app.core
import com.duckbuck.app.core.AppLogger

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handles all Agora-related method channel calls from Flutter
 * Provides a clean separation between Flutter communication and Agora service logic
 */
class AgoraMethodChannelHandler {
    
    companion object {
        private const val TAG = "AgoraMethodChannelHandler"
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
            "leaveChannel" -> {
                handleLeaveChannel(result)
            }
            "turnMicrophoneOn" -> {
                handleTurnMicrophoneOn(result)
            }
            "turnMicrophoneOff" -> {
                handleTurnMicrophoneOff(result)
            }
            "turnVideoOn" -> {
                handleTurnVideoOn(result)
            }
            "turnVideoOff" -> {
                handleTurnVideoOff(result)
            }
            "isEngineActive" -> {
                handleIsEngineActive(result)
            }
            "getRemoteUserCount" -> {
                handleGetRemoteUserCount(result)
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
            result.error("MIC_ON_ERROR", e.message, null)
        }
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

    private fun handleTurnVideoOn(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: turnVideoOn")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.turnVideoOn() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error turning video on", e)
            result.error("VIDEO_ON_ERROR", e.message, null)
        }
    }
    
    private fun handleTurnVideoOff(result: MethodChannel.Result) {
        try {
            AppLogger.d(TAG, "Flutter requested: turnVideoOff")
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val success = agoraService?.turnVideoOff() ?: false
            result.success(success)
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error turning video off", e)
            result.error("VIDEO_OFF_ERROR", e.message, null)
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
}