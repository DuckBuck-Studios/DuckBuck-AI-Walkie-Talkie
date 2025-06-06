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
            "joinChannelAndWaitForUsers" -> {
                handleJoinChannelAndWaitForUsers(call, result)
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

    private fun handleJoinChannelAndWaitForUsers(call: MethodCall, result: MethodChannel.Result) {
        try {
            val channelName = call.argument<String>("channelName")
            val token = call.argument<String?>("token")
            val uid = call.argument<Int>("uid") ?: 0
            val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 15
            
            AppLogger.d(TAG, "Flutter requested: joinChannelAndWaitForUsers - $channelName, timeout: ${timeoutSeconds}s")
            
            if (channelName != null) {
                // Run in background thread to avoid blocking Flutter UI
                Thread {
                    try {
                        val agoraService = AgoraServiceManager.getValidatedAgoraService()
                        val success = agoraService?.joinChannelAndWaitForUsers(channelName, token, uid, timeoutSeconds) ?: false
                        
                        // Return result on main thread
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.success(success)
                        }
                    } catch (e: Exception) {
                        AppLogger.e(TAG, "Error in joinChannelAndWaitForUsers background thread", e)
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("JOIN_AND_WAIT_ERROR", e.message, null)
                        }
                    }
                }.start()
            } else {
                result.error("INVALID_ARGUMENT", "Channel name is required", null)
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error setting up joinChannelAndWaitForUsers", e)
            result.error("JOIN_AND_WAIT_SETUP_ERROR", e.message, null)
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
}