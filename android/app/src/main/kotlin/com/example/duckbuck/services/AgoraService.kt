package com.example.duckbuck.services

import android.content.Context
import android.util.Log
import android.view.SurfaceView
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.video.VideoCanvas
import io.agora.rtc2.video.VideoEncoderConfiguration
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.concurrent.ConcurrentHashMap

class AgoraService(private val context: Context) {
    private val TAG = "AgoraService"
    
    // Agora SDK instance
    private var agoraEngine: RtcEngine? = null
    
    // Track remote users with a thread-safe map
    private val remoteUsers = ConcurrentHashMap<Int, Boolean>()
    
    // Flutter method channel for sending events back to Dart
    private var methodChannel: MethodChannel? = null
    
    // Track local video state
    private var isLocalVideoEnabled = false
    
    // Track local audio state
    private var isLocalAudioEnabled = true
    
    // Setup method channel for communication with Flutter
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }

    // Initialize the Agora engine with full capability
    fun initialize(appId: String, enableVideo: Boolean = false): Boolean {
        try {
            // Create an instance of the Agora engine using the app ID
            agoraEngine = RtcEngine.create(context, appId, rtcEventHandler)
            
            // Configure audio settings
            agoraEngine?.setAudioProfile(
                Constants.AUDIO_PROFILE_MUSIC_HIGH_QUALITY,
                Constants.AUDIO_SCENARIO_GAME_STREAMING
            )
            
            // Enable dual-stream mode for flexible resolution adaptation
            agoraEngine?.enableDualStreamMode(true)
            
            // Set up video if requested
            if (enableVideo) {
                setupVideo()
            }
            
            Log.d(TAG, "Agora Engine initialized successfully with video=$enableVideo")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Agora Engine: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to initialize Agora: ${e.message}"))
            return false
        }
    }
    
    // Configure video settings
    private fun setupVideo() {
        try {
            // Enable video module
            agoraEngine?.enableVideo()
            
            // Configure video encoder
            val videoEncoderConfig = VideoEncoderConfiguration()
            videoEncoderConfig.dimensions = VideoEncoderConfiguration.VD_640x360
            videoEncoderConfig.frameRate = 15 // Use integer instead of constant
            videoEncoderConfig.bitrate = VideoEncoderConfiguration.STANDARD_BITRATE
            videoEncoderConfig.orientationMode = VideoEncoderConfiguration.ORIENTATION_MODE.ORIENTATION_MODE_ADAPTIVE
            
            agoraEngine?.setVideoEncoderConfiguration(videoEncoderConfig)
            
            isLocalVideoEnabled = true
            Log.d(TAG, "Video setup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up video: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to setup video: ${e.message}"))
        }
    }

    // Create and setup local video view
    fun setupLocalVideo(viewId: Int): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Agora Engine not initialized"))
            return false
        }

        try {
            val surfaceView = SurfaceView(context)
            surfaceView.setZOrderMediaOverlay(true)
            
            // Setup local video view
            agoraEngine?.setupLocalVideo(
                VideoCanvas(
                    surfaceView,
                    VideoCanvas.RENDER_MODE_HIDDEN,
                    0 // Local user ID is always 0
                )
            )
            
            // Send the surface view back to Flutter through platform view
            methodChannel?.invokeMethod("onLocalVideoViewCreated", mapOf(
                "viewId" to viewId,
                "success" to true
            ))
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up local video view: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to setup local video: ${e.message}"))
            return false
        }
    }
    
    // Create and setup remote video view
    fun setupRemoteVideo(uid: Int, viewId: Int): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Agora Engine not initialized"))
            return false
        }

        try {
            val surfaceView = SurfaceView(context)
            
            // Setup remote video view
            agoraEngine?.setupRemoteVideo(
                VideoCanvas(
                    surfaceView,
                    VideoCanvas.RENDER_MODE_HIDDEN,
                    uid
                )
            )
            
            // Send the surface view back to Flutter through platform view
            methodChannel?.invokeMethod("onRemoteVideoViewCreated", mapOf(
                "uid" to uid,
                "viewId" to viewId,
                "success" to true
            ))
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up remote video view: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to setup remote video: ${e.message}"))
            return false
        }
    }

    // Join an Agora channel with enhanced options
    fun joinChannel(token: String, channelName: String, uid: Int, enableAudio: Boolean = true, enableVideo: Boolean = false): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Agora Engine not initialized"))
            return false
        }

        try {
            // Configure comprehensive media options for channel
            val options = ChannelMediaOptions()
            
            // Set user role as broadcaster (can transmit audio/video)
            options.clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
            
            // Audio settings
            options.autoSubscribeAudio = true
            options.publishMicrophoneTrack = enableAudio
            isLocalAudioEnabled = enableAudio
            
            // Video settings
            options.autoSubscribeVideo = true
            options.publishCameraTrack = enableVideo
            isLocalVideoEnabled = enableVideo
            
            // Join the channel with a token, channel name, optionally with uid
            agoraEngine?.joinChannel(token, channelName, uid, options)
            
            Log.d(TAG, "Join channel request sent: $channelName with uid=$uid, audio=$enableAudio, video=$enableVideo")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error joining channel: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to join channel: ${e.message}"))
            return false
        }
    }

    // Leave the current channel
    fun leaveChannel(): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.leaveChannel()
            
            // Clear the remote users map when leaving the channel
            remoteUsers.clear()
            
            Log.d(TAG, "Left channel successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error leaving channel: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to leave channel: ${e.message}"))
            return false
        }
    }

    // Enable/disable local audio (microphone)
    fun enableLocalAudio(enabled: Boolean): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.enableLocalAudio(enabled)
            isLocalAudioEnabled = enabled
            Log.d(TAG, "Local audio ${if (enabled) "enabled" else "disabled"}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling local audio: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to toggle audio: ${e.message}"))
            return false
        }
    }

    // Mute/unmute local audio
    fun muteLocalAudio(muted: Boolean): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.muteLocalAudioStream(muted)
            Log.d(TAG, "Local audio ${if (muted) "muted" else "unmuted"}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error muting local audio: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to mute audio: ${e.message}"))
            return false
        }
    }
    
    // Enable/disable local video (camera)
    fun enableLocalVideo(enabled: Boolean): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            if (enabled && !isLocalVideoEnabled) {
                // If we're enabling video for the first time, make sure video module is enabled
                agoraEngine?.enableVideo()
            }
            
            agoraEngine?.enableLocalVideo(enabled)
            isLocalVideoEnabled = enabled
            
            Log.d(TAG, "Local video ${if (enabled) "enabled" else "disabled"}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling local video: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to toggle video: ${e.message}"))
            return false
        }
    }
    
    // Mute/unmute local video
    fun muteLocalVideo(muted: Boolean): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.muteLocalVideoStream(muted)
            Log.d(TAG, "Local video ${if (muted) "muted" else "unmuted"}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error muting local video: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to mute video: ${e.message}"))
            return false
        }
    }
    
    // Switch camera between front and back
    fun switchCamera(): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.switchCamera()
            Log.d(TAG, "Camera switched")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error switching camera: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to switch camera: ${e.message}"))
            return false
        }
    }

    // Set audio volume
    fun setVolume(volume: Int): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            val safeVolume = when {
                volume < 0 -> 0
                else -> volume
            }
            
            agoraEngine?.adjustRecordingSignalVolume(safeVolume)
            Log.d(TAG, "Audio volume set to $safeVolume")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting volume: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to set volume: ${e.message}"))
            return false
        }
    }
    
    // Mute specific remote user
    fun muteRemoteUser(uid: Int, muted: Boolean): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.muteRemoteAudioStream(uid, muted)
            Log.d(TAG, "Remote user $uid audio ${if (muted) "muted" else "unmuted"}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error muting remote user: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to mute remote user: ${e.message}"))
            return false
        }
    }
    
    // Get a list of users in the channel
    fun getRemoteUsers(): List<Int> {
        return remoteUsers.keys().toList()
    }
    
    // Enable speaker (speakerphone)
    fun setEnableSpeakerphone(enabled: Boolean): Boolean {
        if (agoraEngine == null) {
            Log.e(TAG, "Agora Engine not initialized")
            return false
        }

        try {
            agoraEngine?.setEnableSpeakerphone(enabled)
            Log.d(TAG, "Speakerphone ${if (enabled) "enabled" else "disabled"}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling speakerphone: ${e.message}")
            methodChannel?.invokeMethod("onError", mapOf("errorMessage" to "Failed to toggle speakerphone: ${e.message}"))
            return false
        }
    }

    // Destroy the Agora engine instance
    fun destroy() {
        try {
            remoteUsers.clear()
            RtcEngine.destroy()
            agoraEngine = null
            Log.d(TAG, "Agora Engine destroyed")
        } catch (e: Exception) {
            Log.e(TAG, "Error destroying Agora Engine: ${e.message}")
        }
    }

    // Enhanced IRtcEngineEventHandler for handling Agora RTC events
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        // User joined callback
        override fun onUserJoined(uid: Int, elapsed: Int) {
            Log.d(TAG, "Remote user joined: $uid")
            
            // Add the user to our map
            remoteUsers[uid] = true
            
            // Notify Flutter about the user joining
            methodChannel?.invokeMethod("onUserJoined", mapOf(
                "uid" to uid,
                "elapsed" to elapsed
            ))
        }

        // User offline callback
        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "Remote user offline: $uid, reason: $reason")
            
            // Remove the user from our map
            remoteUsers.remove(uid)
            
            // Notify Flutter about the user leaving
            methodChannel?.invokeMethod("onUserOffline", mapOf(
                "uid" to uid,
                "reason" to reason,
                "reasonMsg" to getOfflineReasonString(reason)
            ))
        }

        // Join channel success callback
        override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
            Log.d(TAG, "Successfully joined channel: $channel with uid: $uid")
            
            // Notify Flutter that we've successfully joined the channel
            methodChannel?.invokeMethod("onJoinChannelSuccess", mapOf(
                "channel" to channel,
                "uid" to uid,
                "elapsed" to elapsed
            ))
        }

        // Connection state changed callback
        override fun onConnectionStateChanged(state: Int, reason: Int) {
            Log.d(TAG, "Connection state changed to: $state, reason: $reason")
            
            // Notify Flutter about connection state changes
            methodChannel?.invokeMethod("onConnectionStateChanged", mapOf(
                "state" to state,
                "reason" to reason,
                "stateMsg" to getConnectionStateString(state),
                "reasonMsg" to getConnectionChangeReasonString(reason)
            ))
        }

        // Error callback
        override fun onError(err: Int) {
            Log.e(TAG, "Agora error: $err")
            
            // Notify Flutter about errors
            methodChannel?.invokeMethod("onError", mapOf(
                "errorCode" to err,
                "errorMsg" to getErrorDescription(err)
            ))
        }

        // Audio state changed callback
        override fun onLocalAudioStateChanged(state: Int, error: Int) {
            Log.d(TAG, "Local audio state changed to: $state, error: $error")
            
            // Notify Flutter about audio state changes
            methodChannel?.invokeMethod("onLocalAudioStateChanged", mapOf(
                "state" to state,
                "error" to error,
                "stateMsg" to getLocalAudioStateString(state),
                "errorMsg" to getLocalAudioErrorString(error)
            ))
        }
        
        // Remote video state callback
        override fun onRemoteVideoStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
            Log.d(TAG, "Remote video state changed for user: $uid, state: $state, reason: $reason")
            
            // Notify Flutter about remote video state changes
            methodChannel?.invokeMethod("onRemoteVideoStateChanged", mapOf(
                "uid" to uid,
                "state" to state,
                "reason" to reason,
                "elapsed" to elapsed,
                "stateMsg" to getRemoteVideoStateString(state),
                "reasonMsg" to getRemoteVideoStateReasonString(reason)
            ))
        }
        
        // Network quality callback
        override fun onNetworkQuality(uid: Int, txQuality: Int, rxQuality: Int) {
            // Only log significant changes to reduce noise
            if (txQuality >= 3 || rxQuality >= 3) { // 3 or greater indicates poor quality
                Log.d(TAG, "Network quality for uid $uid: TX=$txQuality, RX=$rxQuality")
                
                // Notify Flutter about network quality issues
                methodChannel?.invokeMethod("onNetworkQuality", mapOf(
                    "uid" to uid,
                    "txQuality" to txQuality,
                    "rxQuality" to rxQuality,
                    "txQualityMsg" to getNetworkQualityString(txQuality),
                    "rxQualityMsg" to getNetworkQualityString(rxQuality)
                ))
            }
        }
        
        // RTC stats callback - for detailed performance metrics
        override fun onRtcStats(stats: RtcStats) {
            // Throttle this to once every 5 seconds to reduce overhead
            methodChannel?.invokeMethod("onRtcStats", mapOf(
                "duration" to stats.totalDuration,
                "txBytes" to stats.txBytes,
                "rxBytes" to stats.rxBytes,
                "txAudioBytes" to stats.txAudioBytes,
                "txVideoBytes" to stats.txVideoBytes,
                "rxAudioBytes" to stats.rxAudioBytes,
                "rxVideoBytes" to stats.rxVideoBytes,
                "txKBitRate" to stats.txKBitRate,
                "rxKBitRate" to stats.rxKBitRate,
                "txAudioKBitRate" to stats.txAudioKBitRate,
                "rxAudioKBitRate" to stats.rxAudioKBitRate,
                "lastmileDelay" to stats.lastmileDelay,
                "cpuAppUsage" to stats.cpuAppUsage,
                "cpuTotalUsage" to stats.cpuTotalUsage
            ))
        }
    }
    
    // Helper methods to convert numeric constants to readable strings
    
    private fun getConnectionStateString(state: Int): String {
        return when (state) {
            Constants.CONNECTION_STATE_DISCONNECTED -> "DISCONNECTED"
            Constants.CONNECTION_STATE_CONNECTING -> "CONNECTING"
            Constants.CONNECTION_STATE_CONNECTED -> "CONNECTED"
            Constants.CONNECTION_STATE_RECONNECTING -> "RECONNECTING"
            Constants.CONNECTION_STATE_FAILED -> "FAILED"
            else -> "UNKNOWN"
        }
    }
    
    private fun getConnectionChangeReasonString(reason: Int): String {
        return when (reason) {
            Constants.CONNECTION_CHANGED_CONNECTING -> "CONNECTING"
            Constants.CONNECTION_CHANGED_JOIN_SUCCESS -> "JOIN_SUCCESS"
            Constants.CONNECTION_CHANGED_INTERRUPTED -> "INTERRUPTED"
            Constants.CONNECTION_CHANGED_BANNED_BY_SERVER -> "BANNED_BY_SERVER"
            Constants.CONNECTION_CHANGED_JOIN_FAILED -> "JOIN_FAILED"
            Constants.CONNECTION_CHANGED_LEAVE_CHANNEL -> "LEAVE_CHANNEL"
            Constants.CONNECTION_CHANGED_INVALID_APP_ID -> "INVALID_APP_ID"
            Constants.CONNECTION_CHANGED_INVALID_CHANNEL_NAME -> "INVALID_CHANNEL_NAME"
            Constants.CONNECTION_CHANGED_INVALID_TOKEN -> "INVALID_TOKEN"
            Constants.CONNECTION_CHANGED_TOKEN_EXPIRED -> "TOKEN_EXPIRED"
            Constants.CONNECTION_CHANGED_REJECTED_BY_SERVER -> "REJECTED_BY_SERVER"
            Constants.CONNECTION_CHANGED_SETTING_PROXY_SERVER -> "SETTING_PROXY_SERVER"
            Constants.CONNECTION_CHANGED_RENEW_TOKEN -> "RENEW_TOKEN"
            Constants.CONNECTION_CHANGED_CLIENT_IP_ADDRESS_CHANGED -> "IP_ADDRESS_CHANGED"
            Constants.CONNECTION_CHANGED_KEEP_ALIVE_TIMEOUT -> "KEEP_ALIVE_TIMEOUT"
            else -> "UNKNOWN"
        }
    }
    
    private fun getLocalAudioStateString(state: Int): String {
        return when (state) {
            0 -> "STOPPED" // Constants.LOCAL_AUDIO_STREAM_STATE_STOPPED
            1 -> "CAPTURING" // Constants.LOCAL_AUDIO_STREAM_STATE_CAPTURING
            2 -> "ENCODING" // Constants.LOCAL_AUDIO_STREAM_STATE_ENCODING
            3 -> "FAILED" // Constants.LOCAL_AUDIO_STREAM_STATE_FAILED
            else -> "UNKNOWN"
        }
    }
    
    private fun getLocalAudioErrorString(error: Int): String {
        return when (error) {
            0 -> "OK" // Constants.LOCAL_AUDIO_STREAM_ERROR_OK
            1 -> "FAILURE" // Constants.LOCAL_AUDIO_STREAM_ERROR_FAILURE
            2 -> "NO_PERMISSION" // Constants.LOCAL_AUDIO_STREAM_ERROR_DEVICE_NO_PERMISSION
            3 -> "DEVICE_BUSY" // Constants.LOCAL_AUDIO_STREAM_ERROR_DEVICE_BUSY
            4 -> "CAPTURE_FAILURE" // Constants.LOCAL_AUDIO_STREAM_ERROR_CAPTURE_FAILURE
            5 -> "ENCODE_FAILURE" // Constants.LOCAL_AUDIO_STREAM_ERROR_ENCODE_FAILURE
            else -> "UNKNOWN"
        }
    }
    
    private fun getLocalVideoStateString(state: Int): String {
        return when (state) {
            0 -> "STOPPED" // Constants.LOCAL_VIDEO_STREAM_STATE_STOPPED
            1 -> "CAPTURING" // Constants.LOCAL_VIDEO_STREAM_STATE_CAPTURING
            2 -> "ENCODING" // Constants.LOCAL_VIDEO_STREAM_STATE_ENCODING
            3 -> "FAILED" // Constants.LOCAL_VIDEO_STREAM_STATE_FAILED
            else -> "UNKNOWN"
        }
    }
    
    private fun getLocalVideoErrorString(error: Int): String {
        return when (error) {
            0 -> "OK" // Constants.LOCAL_VIDEO_STREAM_ERROR_OK
            1 -> "FAILURE" // Constants.LOCAL_VIDEO_STREAM_ERROR_FAILURE
            2 -> "NO_PERMISSION" // Constants.LOCAL_VIDEO_STREAM_ERROR_DEVICE_NO_PERMISSION
            3 -> "DEVICE_BUSY" // Constants.LOCAL_VIDEO_STREAM_ERROR_DEVICE_BUSY
            4 -> "CAPTURE_FAILURE" // Constants.LOCAL_VIDEO_STREAM_ERROR_CAPTURE_FAILURE
            5 -> "ENCODE_FAILURE" // Constants.LOCAL_VIDEO_STREAM_ERROR_ENCODE_FAILURE
            else -> "UNKNOWN"
        }
    }
    
    private fun getRemoteVideoStateString(state: Int): String {
        return when (state) {
            Constants.REMOTE_VIDEO_STATE_STOPPED -> "STOPPED"
            Constants.REMOTE_VIDEO_STATE_STARTING -> "STARTING"
            Constants.REMOTE_VIDEO_STATE_DECODING -> "DECODING"
            Constants.REMOTE_VIDEO_STATE_FROZEN -> "FROZEN"
            Constants.REMOTE_VIDEO_STATE_FAILED -> "FAILED"
            else -> "UNKNOWN"
        }
    }
    
    private fun getRemoteVideoStateReasonString(reason: Int): String {
        return when (reason) {
            Constants.REMOTE_VIDEO_STATE_REASON_INTERNAL -> "INTERNAL"
            Constants.REMOTE_VIDEO_STATE_REASON_NETWORK_CONGESTION -> "NETWORK_CONGESTION"
            Constants.REMOTE_VIDEO_STATE_REASON_NETWORK_RECOVERY -> "NETWORK_RECOVERY"
            Constants.REMOTE_VIDEO_STATE_REASON_LOCAL_MUTED -> "LOCAL_MUTED"
            Constants.REMOTE_VIDEO_STATE_REASON_LOCAL_UNMUTED -> "LOCAL_UNMUTED"
            Constants.REMOTE_VIDEO_STATE_REASON_REMOTE_MUTED -> "REMOTE_MUTED"
            Constants.REMOTE_VIDEO_STATE_REASON_REMOTE_UNMUTED -> "REMOTE_UNMUTED"
            Constants.REMOTE_VIDEO_STATE_REASON_REMOTE_OFFLINE -> "REMOTE_OFFLINE"
            Constants.REMOTE_VIDEO_STATE_REASON_AUDIO_FALLBACK -> "AUDIO_FALLBACK"
            Constants.REMOTE_VIDEO_STATE_REASON_AUDIO_FALLBACK_RECOVERY -> "AUDIO_FALLBACK_RECOVERY"
            else -> "UNKNOWN"
        }
    }
    
    private fun getOfflineReasonString(reason: Int): String {
        return when (reason) {
            Constants.USER_OFFLINE_QUIT -> "QUIT"
            Constants.USER_OFFLINE_DROPPED -> "DROPPED"
            Constants.USER_OFFLINE_BECOME_AUDIENCE -> "BECOME_AUDIENCE"
            else -> "UNKNOWN"
        }
    }
    
    private fun getNetworkQualityString(quality: Int): String {
        return when (quality) {
            Constants.QUALITY_UNKNOWN -> "UNKNOWN"
            Constants.QUALITY_EXCELLENT -> "EXCELLENT"
            Constants.QUALITY_GOOD -> "GOOD"
            Constants.QUALITY_POOR -> "POOR"
            Constants.QUALITY_BAD -> "BAD"
            Constants.QUALITY_VBAD -> "VERY_BAD"
            Constants.QUALITY_DOWN -> "DOWN"
            else -> "UNKNOWN"
        }
    }
    
    private fun getErrorDescription(code: Int): String {
        return when (code) {
            Constants.ERR_OK -> "No error"
            Constants.ERR_FAILED -> "General error"
            Constants.ERR_INVALID_ARGUMENT -> "Invalid argument"
            Constants.ERR_NOT_READY -> "The SDK is not ready"
            Constants.ERR_NOT_SUPPORTED -> "Not supported"
            Constants.ERR_REFUSED -> "Refused by server"
            Constants.ERR_BUFFER_TOO_SMALL -> "Buffer size too small"
            Constants.ERR_NOT_INITIALIZED -> "SDK not initialized"
            Constants.ERR_NO_PERMISSION -> "No permission"
            Constants.ERR_TIMEDOUT -> "Operation timed out"
            Constants.ERR_CANCELED -> "Operation canceled"
            Constants.ERR_TOO_OFTEN -> "Called too often"
            Constants.ERR_BIND_SOCKET -> "Socket binding error"
            Constants.ERR_NET_DOWN -> "Network is down"
            Constants.ERR_JOIN_CHANNEL_REJECTED -> "Join channel rejected"
            Constants.ERR_LEAVE_CHANNEL_REJECTED -> "Leave channel rejected"
            Constants.ERR_ALREADY_IN_USE -> "Resource already in use"
            Constants.ERR_INVALID_APP_ID -> "Invalid App ID"
            Constants.ERR_INVALID_CHANNEL_NAME -> "Invalid channel name"
            Constants.ERR_TOKEN_EXPIRED -> "Token expired"
            Constants.ERR_INVALID_TOKEN -> "Invalid token"
            Constants.ERR_CONNECTION_INTERRUPTED -> "Connection interrupted"
            Constants.ERR_CONNECTION_LOST -> "Connection lost"
            Constants.ERR_NOT_IN_CHANNEL -> "Not in channel"
            Constants.ERR_SIZE_TOO_LARGE -> "Size too large"
            Constants.ERR_BITRATE_LIMIT -> "Bitrate limit"
            Constants.ERR_TOO_MANY_DATA_STREAMS -> "Too many data streams"
            Constants.ERR_STREAM_MESSAGE_TIMEOUT -> "Stream message timeout"
            else -> "Error code: $code"
        }
    }
} 