package com.duckbuck.app.services.agora

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.IRtcEngineEventHandler.RtcStats
import io.agora.rtc2.IRtcEngineEventHandler.AudioVolumeInfo
import com.duckbuck.app.services.walkietalkie.utils.WalkieTalkiePrefsUtil

/**
 * AgoraService - Core service for managing Agora RTC Engine connections
 * Handles channel joining, connection states, and audio communication
 */
class AgoraService private constructor(private val context: Context) {
    
    /**
     * Interface for channel participant events
     */
    interface ChannelParticipantListener {
        fun onUserJoined(uid: Int)
        fun onUserLeft(uid: Int)
    }
    
    /**
     * Interface for channel lifecycle events
     */
    interface ChannelLifecycleListener {
        fun onChannelLeft(reason: String)
    }
    
    companion object {
        private const val TAG = "AgoraService"
        private const val APP_ID = "YOUR_AGORA_APP_ID" // Replace with your actual App ID
        
        @Volatile
        private var INSTANCE: AgoraService? = null
        
        fun getInstance(context: Context): AgoraService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AgoraService(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    // Agora RTC Engine instance
    private var rtcEngine: RtcEngine? = null
    
    // Connection state tracking
    private var isConnected = false
    private var currentChannelName: String? = null
    private var currentUid: Int = 0
    
    // Channel participant listener
    private var participantListener: ChannelParticipantListener? = null
    
    // Channel lifecycle listener
    private var lifecycleListener: ChannelLifecycleListener? = null
    
    // Track channel participants for auto-leave functionality
    private val channelParticipants = mutableSetOf<Int>()
    
    // Event handler for Agora callbacks
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        
        // ================================
        // CHANNEL CONNECTION EVENTS
        // ================================
        
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            super.onJoinChannelSuccess(channel, uid, elapsed)
            Log.d(TAG, "✅ Join channel success: channel=$channel, uid=$uid, elapsed=${elapsed}ms")
            isConnected = true
            currentChannelName = channel
            currentUid = uid
            
            // Reset participants list for new channel
            channelParticipants.clear()
            Log.d(TAG, "📋 Channel participants list reset for new channel")
            
            onChannelJoinSuccess(channel, uid)
        }
        
        override fun onRejoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            super.onRejoinChannelSuccess(channel, uid, elapsed)
            Log.d(TAG, "🔄 Rejoin channel success: channel=$channel, uid=$uid, elapsed=${elapsed}ms")
            isConnected = true
            currentChannelName = channel
            currentUid = uid
            
            onChannelRejoinSuccess(channel, uid)
        }
        
        override fun onLeaveChannel(stats: RtcStats?) {
            super.onLeaveChannel(stats)
            Log.d(TAG, "👋 Left channel: ${currentChannelName}")
            Log.d(TAG, "📊 Channel stats - Duration: ${stats?.totalDuration}s, TX: ${stats?.txBytes}, RX: ${stats?.rxBytes}")
            
            isConnected = false
            currentChannelName = null
            currentUid = 0
            
            // Cleanup participants list when leaving channel
            channelParticipants.clear()
            Log.d(TAG, "🧹 Channel participants list cleared on leave")
            
            onChannelLeft(stats)
        }
        
        override fun onConnectionStateChanged(state: Int, reason: Int) {
            super.onConnectionStateChanged(state, reason)
            Log.d(TAG, "🔌 Connection state changed: state=$state, reason=$reason")
            
            when (state) {
                Constants.CONNECTION_STATE_CONNECTING -> {
                    Log.i(TAG, "🔄 Connecting to Agora...")
                    onConnectionStateChanged("connecting", reason)
                }
                Constants.CONNECTION_STATE_CONNECTED -> {
                    Log.i(TAG, "✅ Connection established successfully")
                    onConnectionStateChanged("connected", reason)
                }
                Constants.CONNECTION_STATE_DISCONNECTED -> {
                    Log.w(TAG, "❌ Connection disconnected")
                    isConnected = false
                    onConnectionStateChanged("disconnected", reason)
                }
                Constants.CONNECTION_STATE_FAILED -> {
                    Log.e(TAG, "💥 Connection failed")
                    isConnected = false
                    onConnectionFailed(reason)
                }
                Constants.CONNECTION_STATE_RECONNECTING -> {
                    Log.i(TAG, "🔄 Reconnecting...")
                    onConnectionStateChanged("reconnecting", reason)
                }
            }
        }
        
        override fun onConnectionLost() {
            super.onConnectionLost()
            Log.w(TAG, "📡 Connection lost - attempting to reconnect...")
            isConnected = false
            onConnectionLost()
        }
        
        // ================================
        // USER PRESENCE EVENTS
        // ================================
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            super.onUserJoined(uid, elapsed)
            Log.d(TAG, "👤 User joined: uid=$uid, elapsed=${elapsed}ms")
            
            // Add to participants list
            channelParticipants.add(uid)
            Log.d(TAG, "📋 Added user $uid to participants. Total: ${channelParticipants.size}")
            
            onUserJoinedChannel(uid)
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            super.onUserOffline(uid, reason)
            val reasonText = when (reason) {
                Constants.USER_OFFLINE_QUIT -> "quit"
                Constants.USER_OFFLINE_DROPPED -> "dropped"
                Constants.USER_OFFLINE_BECOME_AUDIENCE -> "became audience"
                else -> "unknown($reason)"
            }
            Log.d(TAG, "👤 User offline: uid=$uid, reason=$reasonText")
            
            // Remove from participants list
            channelParticipants.remove(uid)
            Log.d(TAG, "📋 Removed user $uid from participants. Remaining: ${channelParticipants.size}")
            
            // WhatsApp-like behavior: if all other users left, leave the channel
            if (channelParticipants.isEmpty() && isConnected) {
                Log.w(TAG, "👥 All users left the channel - auto-leaving")
                // Leave channel automatically after a short delay to allow for reconnections
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    if (channelParticipants.isEmpty() && isConnected) {
                        Log.i(TAG, "🚪 Auto-leaving empty channel")
                        
                        // Clear SharedPreferences - call ended because everyone left
                        WalkieTalkiePrefsUtil.clearCallEnded(context, "everyone_left")
                        
                        // Notify lifecycle listener before leaving
                        lifecycleListener?.onChannelLeft("everyone_left")
                        
                        leaveChannel()
                    }
                }, 2000) // 2-second delay to handle quick reconnections
            }
            
            onUserLeftChannel(uid, reason)
        }
        
        // ================================
        // AUDIO EVENTS & VOICE DETECTION
        // ================================
        
        override fun onAudioVolumeIndication(speakers: Array<out AudioVolumeInfo>?, totalVolume: Int) {
            super.onAudioVolumeIndication(speakers, totalVolume)
            
            speakers?.forEach { speaker ->
                // Voice activity detection - consider speaking if volume > 5
                val isSpeaking = speaker.volume > 5
                
                if (speaker.uid == 0) {
                    // Local user (uid = 0)
                    Log.v(TAG, "🎤 Local voice: volume=${speaker.volume}, speaking=$isSpeaking")
                    onLocalVoiceDetection(speaker.volume, isSpeaking)
                } else {
                    // Remote user
                    Log.v(TAG, "🔊 Remote voice: uid=${speaker.uid}, volume=${speaker.volume}, speaking=$isSpeaking")
                    onRemoteVoiceDetection(speaker.uid, speaker.volume, isSpeaking)
                }
            }
            
            // Overall voice activity
            onVolumeIndication(totalVolume)
        }
        
        override fun onActiveSpeaker(uid: Int) {
            super.onActiveSpeaker(uid)
            Log.d(TAG, "🗣️ Active speaker: uid=$uid")
            onActiveSpeakerChanged(uid)
        }
        
        override fun onAudioRouteChanged(routing: Int) {
            super.onAudioRouteChanged(routing)
            val routeText = when (routing) {
                Constants.AUDIO_ROUTE_DEFAULT -> "default"
                Constants.AUDIO_ROUTE_HEADSET -> "headset"
                Constants.AUDIO_ROUTE_EARPIECE -> "earpiece"
                Constants.AUDIO_ROUTE_HEADSETNOMIC -> "headset (no mic)"
                Constants.AUDIO_ROUTE_SPEAKERPHONE -> "speakerphone"
                Constants.AUDIO_ROUTE_LOUDSPEAKER -> "loudspeaker"
                6 -> "bluetooth headset" // AUDIO_ROUTE_BLUETOOTH
                else -> "unknown($routing)"
            }
            Log.d(TAG, "🎧 Audio route changed: $routeText")
            onAudioRouteChanged(routing, routeText)
        }
        
        override fun onLocalAudioStateChanged(state: Int, error: Int) {
            super.onLocalAudioStateChanged(state, error)
            val stateText = when (state) {
                Constants.LOCAL_AUDIO_STREAM_STATE_STOPPED -> "stopped"
                Constants.LOCAL_AUDIO_STREAM_STATE_RECORDING -> "recording"
                Constants.LOCAL_AUDIO_STREAM_STATE_ENCODING -> "encoding"
                Constants.LOCAL_AUDIO_STREAM_STATE_FAILED -> "failed"
                else -> "unknown($state)"
            }
            Log.d(TAG, "🎤 Local audio state: $stateText, error=$error")
            onLocalAudioStateChanged(state, error, stateText)
        }
        
        override fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
            super.onRemoteAudioStateChanged(uid, state, reason, elapsed)
            val stateText = when (state) {
                Constants.REMOTE_AUDIO_STATE_STOPPED -> "stopped"
                Constants.REMOTE_AUDIO_STATE_STARTING -> "starting"
                Constants.REMOTE_AUDIO_STATE_DECODING -> "decoding"
                Constants.REMOTE_AUDIO_STATE_FROZEN -> "frozen"
                Constants.REMOTE_AUDIO_STATE_FAILED -> "failed"
                else -> "unknown($state)"
            }
            Log.d(TAG, "🔊 Remote audio state: uid=$uid, state=$stateText, reason=$reason")
            onRemoteAudioStateChanged(uid, state, reason, stateText)
        }
        
        override fun onAudioMixingStateChanged(state: Int, reason: Int) {
            super.onAudioMixingStateChanged(state, reason)
            Log.d(TAG, "🎵 Audio mixing state changed: state=$state, reason=$reason")
            onAudioMixingStateChanged(state, reason)
        }
        
        // ================================
        // QUALITY & NETWORK EVENTS
        // ================================
        
        override fun onNetworkQuality(uid: Int, txQuality: Int, rxQuality: Int) {
            super.onNetworkQuality(uid, txQuality, rxQuality)
            
            val getQualityText = { quality: Int ->
                when (quality) {
                    Constants.QUALITY_EXCELLENT -> "excellent"
                    Constants.QUALITY_GOOD -> "good"
                    Constants.QUALITY_POOR -> "poor"
                    Constants.QUALITY_BAD -> "bad"
                    Constants.QUALITY_VBAD -> "very bad"
                    Constants.QUALITY_DOWN -> "down"
                    else -> "unknown"
                }
            }
            
            if (uid == currentUid) {
                Log.v(TAG, "📶 Local network quality: TX=${getQualityText(txQuality)}, RX=${getQualityText(rxQuality)}")
            } else {
                Log.v(TAG, "📶 Remote network quality: uid=$uid, TX=${getQualityText(txQuality)}, RX=${getQualityText(rxQuality)}")
            }
            
            onNetworkQuality(uid, txQuality, rxQuality)
        }
        
        override fun onRtcStats(stats: RtcStats?) {
            super.onRtcStats(stats)
            stats?.let {
                Log.v(TAG, "📊 RTC Stats: Users=${it.users}, CPU=${it.cpuAppUsage}%, Memory=${it.memoryAppUsageRatio}%")
                onRtcStats(it)
            }
        }
        
        override fun onLastmileQuality(quality: Int) {
            super.onLastmileQuality(quality)
            val qualityText = when (quality) {
                Constants.QUALITY_EXCELLENT -> "excellent"
                Constants.QUALITY_GOOD -> "good"
                Constants.QUALITY_POOR -> "poor"
                Constants.QUALITY_BAD -> "bad"
                Constants.QUALITY_VBAD -> "very bad"
                Constants.QUALITY_DOWN -> "down"
                else -> "unknown"
            }
            Log.d(TAG, "🌐 Last mile quality: $qualityText")
            onLastMileQuality(quality, qualityText)
        }
        
        // ================================
        // ERROR HANDLING
        // ================================
        
        override fun onError(err: Int) {
            super.onError(err)
            val errorText = when (err) {
                Constants.ERR_INVALID_CHANNEL_NAME -> "Invalid channel name"
                Constants.ERR_INVALID_TOKEN -> "Invalid token"
                Constants.ERR_TOKEN_EXPIRED -> "Token expired"
                3 -> "Not authorized" // ERR_NOT_AUTHORIZED
                // Constants.ERR_AUDIO_DEVICE_MODULE_FAILURE -> "Audio device failure" // Not available in 4.5.2
                Constants.ERR_INVALID_APP_ID -> "Invalid App ID"
                Constants.ERR_ALREADY_IN_USE -> "Already in use"
                else -> "Unknown error ($err)"
            }
            Log.e(TAG, "💥 Agora error: $errorText")
            onAgoraError(err, errorText)
        }
        
        // Note: onWarning is not available in Agora SDK 4.5.2
        
        // ================================
        // AUDIO DEVICE EVENTS
        // ================================
        
        // Note: onAudioDeviceStateChanged is not available in Agora SDK 4.5.2
    }
    
    // ================================
    // MEDIA ENGINE EVENTS
    // ================================
    
    // Note: onAudioQuality, onFirstRemoteAudioFrame, onFirstLocalAudioFrame are not available in Agora SDK 4.5.2
    
    /**
     * Set listener for channel participant events
     */
    fun setChannelParticipantListener(listener: ChannelParticipantListener?) {
        this.participantListener = listener
        Log.d(TAG, "📋 Channel participant listener set: ${listener != null}")
    }
    
    /**
     * Clear the participant listener (useful when switching contexts or cleaning up)
     */
    fun clearChannelParticipantListener() {
        this.participantListener = null
        Log.d(TAG, "🧹 Channel participant listener cleared")
    }
    
    /**
     * Set listener for channel lifecycle events
     */
    fun setChannelLifecycleListener(listener: ChannelLifecycleListener?) {
        this.lifecycleListener = listener
        Log.d(TAG, "📋 Channel lifecycle listener set: ${listener != null}")
    }
    
    /**
     * Clear the lifecycle listener
     */
    fun clearChannelLifecycleListener() {
        this.lifecycleListener = null
        Log.d(TAG, "🧹 Channel lifecycle listener cleared")
    }
    
    /**
     * Initialize the Agora RTC Engine
     * Should be called once when the service is created
     */
    fun initializeEngine(): Boolean {
        return try {
            val config = RtcEngineConfig().apply {
                mContext = context
                mAppId = APP_ID
                mEventHandler = rtcEventHandler
            }
            
            rtcEngine = RtcEngine.create(config)
            
            // Enable audio module (for walkie-talkie functionality)
            rtcEngine?.enableAudio()
            
            // Initialize AI audio enhancements
            initializeAiAudioEnhancements()
            
            // Enable voice activity detection (volume indication) - configured in AI setup
            // rtcEngine?.enableAudioVolumeIndication() is called in setAudioConfigParameters()
            
            // Note: enableLastmileTest not available in Agora SDK 4.5.2
            // rtcEngine?.enableLastmileTest()
            
            Log.i(TAG, "🤖 Agora RTC Engine initialized successfully with AI enhancements")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Agora RTC Engine", e)
            false
        }
    }
    
    /**
     * Join a channel with the specified parameters
     * @param token - Authentication token (can be null for testing)
     * @param channelName - Name of the channel to join
     * @param uid - User ID (0 for auto-assigned)
     * @param joinMuted - Whether to join the channel with microphone muted (default: false)
     * @return Boolean indicating if the join attempt was initiated successfully
     */
    fun joinChannel(token: String?, channelName: String, uid: Int = 0, joinMuted: Boolean = false): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized. Call initializeEngine() first")
                return false
            }
            
            if (isConnected) {
                Log.w(TAG, "Already connected to channel: $currentChannelName")
                return false
            }
            
            Log.i(TAG, "Attempting to join channel: $channelName with uid: $uid${if (joinMuted) " (muted)" else ""}")
            
            // Configure channel media options for audio-only walkie-talkie
            val options = ChannelMediaOptions().apply {
                channelProfile = Constants.CHANNEL_PROFILE_COMMUNICATION
                clientRoleType = Constants.CLIENT_ROLE_BROADCASTER // Always broadcaster for walkie-talkie
                
                // Audio settings for walkie-talkie - always subscribe to others
                autoSubscribeAudio = true
                publishMicrophoneTrack = !joinMuted // Publish based on mute preference
                
                // Disable video for walkie-talkie functionality
                autoSubscribeVideo = false
                publishCameraTrack = false
            }
            
            // Join the channel
            val result = rtcEngine?.joinChannel(token, channelName, uid, options)
            
            if (result == 0) {
                Log.i(TAG, "Join channel request sent successfully")
                
                // If joining muted, also mute the local audio stream
                if (joinMuted) {
                    muteLocalAudio(true)
                    Log.i(TAG, "🔇 Joined channel muted")
                } else {
                    Log.i(TAG, "🎤 Joined channel unmuted")
                }
                
                return true
            } else {
                Log.e(TAG, "Failed to join channel. Error code: $result")
                return false
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Exception while joining channel", e)
            false
        }
    }
    
    /**
     * Leave the current channel
     */
    fun leaveChannel(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.w(TAG, "RTC Engine not initialized")
                return false
            }
            
            if (!isConnected) {
                Log.w(TAG, "Not connected to any channel")
                return false
            }
            
            Log.i(TAG, "Leaving channel: $currentChannelName")
            
            // Clear participant listener to avoid callbacks for old channels
            clearChannelParticipantListener()
            
            val result = rtcEngine?.leaveChannel()
            
            result == 0
        } catch (e: Exception) {
            Log.e(TAG, "Exception while leaving channel", e)
            false
        }
    }
    
    /**
     * Destroy the RTC Engine and cleanup resources
     */
    fun destroy() {
        try {
            if (isConnected) {
                leaveChannel()
            }
            
            rtcEngine?.let {
                RtcEngine.destroy()
                rtcEngine = null
            }
            
            Log.i(TAG, "Agora RTC Engine destroyed")
        } catch (e: Exception) {
            Log.e(TAG, "Exception while destroying RTC Engine", e)
        }
    }
    
    // Getter methods for current state
    fun isChannelConnected(): Boolean = isConnected
    fun getCurrentChannelName(): String? = currentChannelName
    fun getCurrentUid(): Int = currentUid
    
    // Callback methods - These will be implemented later to communicate with Flutter
    
    // ================================
    // CHANNEL CONNECTION CALLBACKS
    // ================================
    
    private fun onChannelJoinSuccess(channelName: String?, uid: Int) {
        Log.d(TAG, "✅ Channel join success callback: $channelName, $uid")
        // TODO: Send success notification to Flutter via MethodChannel
    }
    
    private fun onChannelRejoinSuccess(channelName: String?, uid: Int) {
        Log.d(TAG, "🔄 Channel rejoin success callback: $channelName, $uid")
        // TODO: Send rejoin notification to Flutter
    }
    
    private fun onChannelLeft(stats: RtcStats?) {
        Log.d(TAG, "👋 Channel left callback with stats")
        // TODO: Send channel left notification to Flutter with stats
    }
    
    private fun onConnectionStateChanged(state: String, reason: Int) {
        Log.d(TAG, "🔌 Connection state callback: $state, reason=$reason")
        // TODO: Send connection state to Flutter
    }
    
    private fun onConnectionFailed(reason: Int) {
        Log.d(TAG, "💥 Connection failed callback: reason=$reason")
        // TODO: Send connection failure notification to Flutter
    }
    
    private fun onConnectionLost() {
        Log.d(TAG, "📡 Connection lost callback")
        // TODO: Send connection lost notification to Flutter
    }
    
    // ================================
    // USER PRESENCE CALLBACKS
    // ================================
    
    private fun onUserJoinedChannel(uid: Int) {
        Log.d(TAG, "👤 User joined callback: $uid")
        participantListener?.onUserJoined(uid)
    }
    
    private fun onUserLeftChannel(uid: Int, reason: Int) {
        Log.d(TAG, "👤 User left callback: uid=$uid, reason=$reason")
        participantListener?.onUserLeft(uid)
    }
    
    // ================================
    // VOICE DETECTION CALLBACKS
    // ================================
    
    private fun onLocalVoiceDetection(volume: Int, isSpeaking: Boolean) {
        // Only log if speaking state changes to avoid spam
        if (isSpeaking) {
            Log.v(TAG, "🎤 Local voice detected: volume=$volume")
        }
        // TODO: Send local voice activity to Flutter
    }
    
    private fun onRemoteVoiceDetection(uid: Int, volume: Int, isSpeaking: Boolean) {
        // Only log if speaking state changes to avoid spam
        if (isSpeaking) {
            Log.v(TAG, "🔊 Remote voice detected: uid=$uid, volume=$volume")
        }
        // TODO: Send remote voice activity to Flutter
    }
    
    private fun onVolumeIndication(totalVolume: Int) {
        // Only log significant volume changes to avoid spam
        if (totalVolume > 10) {
            Log.v(TAG, "📢 Total volume: $totalVolume")
        }
        // TODO: Send volume indication to Flutter
    }
    
    private fun onActiveSpeakerChanged(uid: Int) {
        Log.d(TAG, "🗣️ Active speaker callback: $uid")
        // TODO: Send active speaker change to Flutter
    }
    
    // ================================
    // AUDIO DEVICE CALLBACKS
    // ================================
    
    private fun onAudioRouteChanged(routing: Int, routeText: String) {
        Log.d(TAG, "🎧 Audio route callback: $routeText")
        // TODO: Send audio route change to Flutter
    }
    
    private fun onLocalAudioStateChanged(state: Int, error: Int, stateText: String) {
        Log.d(TAG, "🎤 Local audio state callback: $stateText, error=$error")
        // TODO: Send local audio state to Flutter
    }
    
    private fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, stateText: String) {
        Log.d(TAG, "🔊 Remote audio state callback: uid=$uid, state=$stateText")
        // TODO: Send remote audio state to Flutter
    }
    
    private fun onAudioMixingStateChanged(state: Int, reason: Int) {
        Log.d(TAG, "🎵 Audio mixing callback: state=$state, reason=$reason")
        // TODO: Send audio mixing state to Flutter
    }
    
    private fun onAudioDeviceStateChanged(deviceId: String?, deviceType: Int, deviceState: Int) {
        Log.d(TAG, "🎧 Audio device callback: device=$deviceId, type=$deviceType, state=$deviceState")
        // TODO: Send audio device state to Flutter
    }
    
    // ================================
    // QUALITY & NETWORK CALLBACKS
    // ================================
    
    private fun onNetworkQuality(uid: Int, txQuality: Int, rxQuality: Int) {
        // Only log poor quality to avoid spam
        if (txQuality >= Constants.QUALITY_POOR || rxQuality >= Constants.QUALITY_POOR) {
            Log.v(TAG, "📶 Network quality callback: uid=$uid, TX=$txQuality, RX=$rxQuality")
        }
        // TODO: Send network quality to Flutter
    }
    
    private fun onRtcStats(stats: RtcStats) {
        Log.v(TAG, "📊 RTC stats callback")
        // TODO: Send RTC stats to Flutter
    }
    
    private fun onLastMileQuality(quality: Int, qualityText: String) {
        Log.d(TAG, "🌐 Last mile quality callback: $qualityText")
        // TODO: Send last mile quality to Flutter
    }
    
    private fun onAudioQuality(uid: Int, quality: Int, delay: Int, lost: Int) {
        // Only log if quality is poor or packet loss is significant
        if (quality >= Constants.QUALITY_POOR || lost > 5) {
            Log.v(TAG, "🎵 Audio quality callback: uid=$uid, quality=$quality, delay=${delay}ms, lost=$lost")
        }
        // TODO: Send audio quality to Flutter
    }
    
    // ================================
    // AUDIO FRAME CALLBACKS
    // ================================
    
    private fun onFirstLocalAudioFrame(elapsed: Int) {
        Log.d(TAG, "🎤 First local audio frame callback: ${elapsed}ms")
        // TODO: Send first local audio frame to Flutter
    }
    
    private fun onFirstRemoteAudioFrame(uid: Int, elapsed: Int) {
        Log.d(TAG, "🎵 First remote audio frame callback: uid=$uid, ${elapsed}ms")
        // TODO: Send first remote audio frame to Flutter
    }
    
    // ================================
    // ERROR HANDLING CALLBACKS
    // ================================
    
    private fun onAgoraError(errorCode: Int, errorText: String) {
        Log.e(TAG, "💥 Agora error callback: $errorText")
        // TODO: Send error notification to Flutter
    }
    
    private fun onAgoraWarning(warningCode: Int) {
        Log.w(TAG, "⚠️ Agora warning callback: $warningCode")
        // TODO: Send warning notification to Flutter
    }
    
    // ================================
    // AUDIO OUTPUT ROUTING METHODS
    // ================================
    
    /**
     * Set the default audio output route to speakerphone or earpiece
     * This should be called before joining a channel
     * @param useSpeakerphone - true for speakerphone, false for earpiece
     */
    fun setDefaultAudioRoute(useSpeakerphone: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.setDefaultAudioRoutetoSpeakerphone(useSpeakerphone)
            
            if (result == 0) {
                Log.i(TAG, "🎧 Default audio route set to: ${if (useSpeakerphone) "speakerphone" else "earpiece"}")
                true
            } else {
                Log.e(TAG, "Failed to set default audio route. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting default audio route", e)
            false
        }
    }
    
    /**
     * Enable or disable speakerphone
     * This can be called during an active call to switch audio output
     * @param enabled - true to enable speakerphone, false to disable
     */
    fun setSpeakerphoneEnabled(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.setEnableSpeakerphone(enabled)
            
            if (result == 0) {
                Log.i(TAG, "🔊 Speakerphone ${if (enabled) "enabled" else "disabled"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (enabled) "enable" else "disable"} speakerphone. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting speakerphone", e)
            false
        }
    }
    
    /**
     * Check if speakerphone is currently enabled
     * @return Boolean indicating if speakerphone is enabled
     */
    fun isSpeakerphoneEnabled(): Boolean {
        return try {
            rtcEngine?.isSpeakerphoneEnabled() ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Exception while checking speakerphone status", e)
            false
        }
    }
    
    /**
     * Mute or unmute the local microphone
     * @param muted - true to mute, false to unmute
     */
    fun muteLocalAudio(muted: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.muteLocalAudioStream(muted)
            
            if (result == 0) {
                Log.i(TAG, "🎤 Local audio ${if (muted) "muted" else "unmuted"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (muted) "mute" else "unmute"} local audio. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while muting/unmuting local audio", e)
            false
        }
    }
    
    /**
     * Mute or unmute a remote user's audio
     * @param uid - The user ID to mute/unmute
     * @param muted - true to mute, false to unmute
     */
    fun muteRemoteAudio(uid: Int, muted: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.muteRemoteAudioStream(uid, muted)
            
            if (result == 0) {
                Log.i(TAG, "🔇 Remote user $uid audio ${if (muted) "muted" else "unmuted"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (muted) "mute" else "unmute"} remote user $uid. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while muting/unmuting remote audio", e)
            false
        }
    }
    
    /**
     * Mute or unmute all remote users' audio
     * @param muted - true to mute all, false to unmute all
     */
    fun muteAllRemoteAudio(muted: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.muteAllRemoteAudioStreams(muted)
            
            if (result == 0) {
                Log.i(TAG, "🔇 All remote audio ${if (muted) "muted" else "unmuted"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (muted) "mute" else "unmute"} all remote audio. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while muting/unmuting all remote audio", e)
            false
        }
    }
    
    /**
     * Adjust the recording signal volume (microphone gain)
     * @param volume - Volume level (0-400, where 100 is original volume)
     */
    fun adjustRecordingVolume(volume: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.adjustRecordingSignalVolume(volume)
            
            if (result == 0) {
                Log.i(TAG, "🎚️ Recording volume adjusted to: $volume")
                true
            } else {
                Log.e(TAG, "Failed to adjust recording volume. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while adjusting recording volume", e)
            false
        }
    }
    
    /**
     * Adjust the playback signal volume (speaker volume)
     * @param volume - Volume level (0-400, where 100 is original volume)
     */
    fun adjustPlaybackVolume(volume: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.adjustPlaybackSignalVolume(volume)
            
            if (result == 0) {
                Log.i(TAG, "🔊 Playback volume adjusted to: $volume")
                true
            } else {
                Log.e(TAG, "Failed to adjust playback volume. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while adjusting playback volume", e)
            false
        }
    }
    
    /**
     * Adjust the playback volume for a specific remote user
     * @param uid - The user ID
     * @param volume - Volume level (0-400, where 100 is original volume)
     */
    fun adjustUserPlaybackVolume(uid: Int, volume: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.adjustUserPlaybackSignalVolume(uid, volume)
            
            if (result == 0) {
                Log.i(TAG, "🔊 User $uid playback volume adjusted to: $volume")
                true
            } else {
                Log.e(TAG, "Failed to adjust user $uid playback volume. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while adjusting user playback volume", e)
            false
        }
    }
    
    /**
     * Enable or disable the local audio (microphone)
     * @param enabled - true to enable, false to disable
     */
    fun enableLocalAudio(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }
            
            val result = rtcEngine?.enableLocalAudio(enabled)
            
            if (result == 0) {
                Log.i(TAG, "🎤 Local audio ${if (enabled) "enabled" else "disabled"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (enabled) "enable" else "disable"} local audio. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling/disabling local audio", e)
            false
        }
    }
    
    /**
     * Set audio scenario for optimal walkie-talkie experience
     * @param scenario - The audio scenario (default: CHATROOM_GAMING for walkie-talkie)
     */
    fun setAudioScenario(scenario: Int = 7): Boolean { // AUDIO_SCENARIO_CHATROOM_ENTERTAINMENT
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine?.setAudioScenario(scenario)

            if (result == 0) {
                Log.i(TAG, "🎵 Audio scenario set to: $scenario")
                true
            } else {
                Log.e(TAG, "Failed to set audio scenario. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting audio scenario", e)
            false
        }
    }

    // ================================
    // AI AUDIO ENHANCEMENT METHODS
    // ================================

    /**
     * Load Agora AI denoising plugin (dynamic library)
     * Should be called after engine initialization for AI audio enhancements
     */
    fun loadAiDenoisePlugin(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Load the AI denoising dynamic library
            val result = rtcEngine?.loadExtensionProvider("libagora_ai_denoise_extension")

            if (result == 0) {
                Log.i(TAG, "🤖 AI denoising plugin loaded successfully")
                true
            } else {
                Log.e(TAG, "Failed to load AI denoising plugin. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while loading AI denoising plugin", e)
            false
        }
    }

    /**
     * Load Agora AI echo cancellation plugin (dynamic library)
     * Should be called after engine initialization for AI audio enhancements
     */
    fun loadAiEchoCancellationPlugin(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Load the AI echo cancellation dynamic library
            val result = rtcEngine?.loadExtensionProvider("libagora_ai_echo_cancellation_extension")

            if (result == 0) {
                Log.i(TAG, "🤖 AI echo cancellation plugin loaded successfully")
                true
            } else {
                Log.e(TAG, "Failed to load AI echo cancellation plugin. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while loading AI echo cancellation plugin", e)
            false
        }
    }

    /**
     * Enable AI denoising extension
     * Call after loading the AI denoising plugin
     */
    fun enableAiDenoising(enabled: Boolean = true): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine?.enableExtension(
                "agora_ai_denoise_extension",
                "ai_denoise",
                enabled
            )

            if (result == 0) {
                Log.i(TAG, "🤖 AI denoising ${if (enabled) "enabled" else "disabled"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (enabled) "enable" else "disable"} AI denoising. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling/disabling AI denoising", e)
            false
        }
    }

    /**
     * Enable AI echo cancellation extension
     * Call after loading the AI echo cancellation plugin
     */
    fun enableAiEchoCancellation(enabled: Boolean = true): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine?.enableExtension(
                "agora_ai_echo_cancellation_extension",
                "ai_echo_cancellation",
                enabled
            )

            if (result == 0) {
                Log.i(TAG, "🤖 AI echo cancellation ${if (enabled) "enabled" else "disabled"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (enabled) "enable" else "disable"} AI echo cancellation. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling/disabling AI echo cancellation", e)
            false
        }
    }

    /**
     * Set audio scenario to AI client for optimal AI conversational experience
     * Recommended for AI-enhanced walkie-talkie communication
     */
    fun setAiAudioScenario(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Set audio scenario to AI client scenario for conversational AI
            val result = rtcEngine?.setAudioScenario(1000) // AUDIO_SCENARIO_AI_CLIENT

            if (result == 0) {
                Log.i(TAG, "🤖 AI audio scenario set for conversational AI")
                true
            } else {
                Log.e(TAG, "Failed to set AI audio scenario. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting AI audio scenario", e)
            false
        }
    }

    /**
     * Configure recommended audio parameters for AI conversational experience
     * Should be called before joining channel and on audio route changes
     */
    fun setAudioConfigParameters(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            Log.i(TAG, "🤖 Configuring AI audio parameters...")

            // Set audio profile optimized for speech with AI enhancements
            val profileResult = rtcEngine?.setAudioProfile(
                Constants.AUDIO_PROFILE_SPEECH_STANDARD,
                1000 // AUDIO_SCENARIO_AI_CLIENT
            )

            // Configure advanced audio parameters for AI conversational quality
            val parametersJson = """
                {
                    "che.audio.specify.codec": "OPUS",
                    "che.audio.codec.opus.complexity": 9,
                    "che.audio.codec.opus.dtx": true,
                    "che.audio.codec.opus.fec": true,
                    "che.audio.codec.opus.application": "voip",
                    "che.audio.aec.enable": true,
                    "che.audio.agc.enable": true,
                    "che.audio.ns.enable": true,
                    "che.audio.ai.enhance": true,
                    "che.audio.ai.denoise.level": "aggressive",
                    "che.audio.ai.agc.target_level": -18,
                    "che.audio.ai.ns.level": "high"
                }
            """.trimIndent()

            val paramResult = rtcEngine?.setParameters(parametersJson)

            if (profileResult == 0 && paramResult == 0) {
                Log.i(TAG, "🤖 AI audio configuration applied successfully")
                
                // Enable additional audio quality settings
                rtcEngine?.enableAudioVolumeIndication(
                    200,  // Report every 200ms for more responsive AI
                    3,    // Smooth factor
                    true  // Include local user
                )

                true
            } else {
                Log.e(TAG, "Failed to configure AI audio parameters. Profile: $profileResult, Params: $paramResult")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while configuring AI audio parameters", e)
            false
        }
    }

    /**
     * Initialize complete AI audio enhancement stack
     * Loads plugins, enables features, and configures optimal parameters
     */
    fun initializeAiAudioEnhancements(): Boolean {
        return try {
            Log.i(TAG, "🤖 Initializing complete AI audio enhancement stack...")

            var success = true

            // Step 1: Load AI plugins
            if (!loadAiDenoisePlugin()) {
                Log.w(TAG, "⚠️ AI denoising plugin not loaded - continuing without it")
            }

            if (!loadAiEchoCancellationPlugin()) {
                Log.w(TAG, "⚠️ AI echo cancellation plugin not loaded - continuing without it")
            }

            // Step 2: Enable AI features (non-blocking if plugins not available)
            enableAiDenoising(true)
            enableAiEchoCancellation(true)

            // Step 3: Set AI audio scenario
            if (!setAiAudioScenario()) {
                Log.w(TAG, "⚠️ Failed to set AI audio scenario - using default")
                success = false
            }

            // Step 4: Configure AI audio parameters
            if (!setAudioConfigParameters()) {
                Log.w(TAG, "⚠️ Failed to configure AI audio parameters")
                success = false
            }

            if (success) {
                Log.i(TAG, "✅ AI audio enhancement stack initialized successfully")
            } else {
                Log.w(TAG, "⚠️ AI audio enhancement stack initialized with some warnings")
            }

            success
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception while initializing AI audio enhancements", e)
            false
        }
    }

    /**
     * Reconfigure AI audio parameters (call on audio route changes)
     * Optimizes settings when switching between speaker/earpiece/headphones
     */
    fun reconfigureAiAudioForRoute(): Boolean {
        return try {
            Log.i(TAG, "🤖 Reconfiguring AI audio for route change...")
            setAudioConfigParameters()
        } catch (e: Exception) {
            Log.e(TAG, "Exception while reconfiguring AI audio for route", e)
            false
        }
    }
}
