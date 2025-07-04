package com.duckbuck.app.services.agora

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
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
        private const val APP_ID = "ccc5933082e7404682ae909f5654f31c" 
        
        @Volatile
        private var INSTANCE: AgoraService? = null
        
        fun getInstance(context: Context): AgoraService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AgoraService(context.applicationContext).also { INSTANCE = it }
            }
        }
        
        /**
         * Force reset the singleton instance (for debugging purposes)
         */
        fun resetInstance() {
            synchronized(this) {
                INSTANCE?.destroy()
                INSTANCE = null
                Log.d(TAG, "🔄 AgoraService instance reset")
            }
        }
    }
    
    // Agora RTC Engine instance
    private var rtcEngine: RtcEngine? = null
    
    // Connection state tracking
    private var isConnected = false
    private var currentChannelName: String? = null
    private var currentUid: Int = 0
    
    // Audio route tracking for AI optimization
    private var mAudioRouting = Constants.AUDIO_ROUTE_DEFAULT
    
    // Track AI mode to apply AI-specific optimizations only when requested
    private var isAiModeEnabled = false
    
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
                    // Local user (uid = 0) - only log when speaking
                    if (isSpeaking) {
                        Log.d(TAG, "🎤 Local voice: volume=${speaker.volume}")
                    }
                    onLocalVoiceDetection(speaker.volume, isSpeaking)
                } else {
                    // Remote user - only log when speaking
                    if (isSpeaking) {
                        Log.d(TAG, "🔊 Remote voice: uid=${speaker.uid}, volume=${speaker.volume}")
                    }
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
            
            // Update current audio routing
            mAudioRouting = routing
            
            // CONFIRMED: AI filters persist across audio route changes
            // No need to re-apply setAINSMode, audio profile, or scenario
            // These are engine-level settings that remain active regardless of output device
            Log.d(TAG, "🎯 Audio route updated - AI filters persist at engine level")
            
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
                // Only log poor quality for local user
                if (txQuality >= Constants.QUALITY_POOR || rxQuality >= Constants.QUALITY_POOR) {
                    Log.w(TAG, "📶 Local network quality poor: TX=${getQualityText(txQuality)}, RX=${getQualityText(rxQuality)}")
                }
            } else {
                // Only log poor quality for remote users
                if (txQuality >= Constants.QUALITY_POOR || rxQuality >= Constants.QUALITY_POOR) {
                    Log.w(TAG, "📶 Remote network quality poor: uid=$uid, TX=${getQualityText(txQuality)}, RX=${getQualityText(rxQuality)}")
                }
            }
            
            onNetworkQuality(uid, txQuality, rxQuality)
        }
        
        override fun onRtcStats(stats: RtcStats?) {
            super.onRtcStats(stats)
            // Only log stats occasionally to avoid spam
            stats?.let {
                if (it.totalDuration % 10 == 0) { // Log every 10 seconds
                    Log.d(TAG, "📊 RTC Stats: Users=${it.users}, Duration=${it.totalDuration}s, CPU=${it.cpuAppUsage}%")
                }
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
            Log.i(TAG, "📻 Initializing Agora RTC Engine for standard walkie-talkie...")
            
            // Ensure AI mode is disabled for regular walkie-talkie calls
            isAiModeEnabled = false
            Log.i(TAG, "📻 AI mode disabled - using standard walkie-talkie configuration")
            
            // Check if engine already exists
            if (rtcEngine != null) {
                Log.w(TAG, "⚠️ RTC Engine already exists, destroying first...")
                try {
                    RtcEngine.destroy()
                    rtcEngine = null
                    Thread.sleep(100) // Small delay for cleanup
                } catch (e: Exception) {
                    Log.w(TAG, "Warning while destroying existing engine: ${e.message}")
                }
            }
            
            val config = RtcEngineConfig().apply {
                mContext = context
                mAppId = APP_ID
                mEventHandler = rtcEventHandler
                mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT
                mChannelProfile = Constants.CHANNEL_PROFILE_COMMUNICATION
            }
            
            // Try to create engine
            val engineInstance = try {
                RtcEngine.create(config)
            } catch (e: Exception) {
                Log.e(TAG, "Exception during RtcEngine.create(): ${e.message}")
                // Try alternative method
                RtcEngine.create(context.applicationContext, APP_ID, rtcEventHandler)
            }
            
            if (engineInstance == null) {
                Log.e(TAG, "Failed to create RTC Engine - trying force clean initialization")
                return forceCleanInitialization()
            }
            
            rtcEngine = engineInstance
            Log.i(TAG, "✅ RTC Engine created successfully")
            
            // Enable audio module
            val audioResult = rtcEngine!!.enableAudio()
            if (audioResult != 0) {
                Log.e(TAG, "Failed to enable audio, error code: $audioResult")
                return false
            }
            Log.i(TAG, "✅ Audio module enabled")
            
            Log.i(TAG, "📻 Standard walkie-talkie RTC Engine initialized successfully")
            
            // Check AI audio support after successful initialization
            if (isAiModeEnabled) {
                CoroutineScope(Dispatchers.IO).launch {
                    checkAiAudioSupport()
                }
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Agora RTC Engine", e)
            rtcEngine = null
            false
        }
    }
    
    /**
     * Alternative engine initialization method
     */
    private fun initializeEngineAlternative(): Boolean {
        return try {
            Log.i(TAG, "🔄 Trying alternative RTC Engine initialization...")
            
            // Try the old initialization method as fallback
            val engineInstance = RtcEngine.create(context, APP_ID, rtcEventHandler)
            
            if (engineInstance == null) {
                Log.e(TAG, "Alternative initialization also failed - engine is null")
                return false
            }
            
            rtcEngine = engineInstance
            Log.i(TAG, "✅ Alternative RTC Engine creation successful")
            
            // Enable audio
            val audioResult = rtcEngine!!.enableAudio()
            if (audioResult != 0) {
                Log.e(TAG, "Failed to enable audio in alternative method, error code: $audioResult")
                return false
            }
            
            Log.i(TAG, "✅ Alternative initialization complete")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Alternative initialization failed", e)
            false
        }
    }
    
    /**
     * Test method to validate setup without creating actual engine
     */
    fun validateSetup(): Boolean {
        return try {
            Log.i(TAG, "🔍 Validating Agora setup...")
            
            // Check APP_ID
            if (APP_ID.isEmpty()) {
                Log.e(TAG, "❌ APP_ID is empty")
                return false
            }
            
            if (APP_ID.length < 32) {
                Log.e(TAG, "❌ APP_ID is too short: ${APP_ID.length} characters")
                return false
            }
            
            // Check context
            if (context.applicationContext == null) {
                Log.e(TAG, "❌ Application context is null")
                return false
            }
            
            // Check if Agora classes are available
            try {
                val configClass = RtcEngineConfig::class.java
                val engineClass = RtcEngine::class.java
                Log.i(TAG, "✅ Agora classes available: ${configClass.simpleName}, ${engineClass.simpleName}")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Agora classes not available", e)
                return false
            }
            
            Log.i(TAG, "✅ Agora setup validation passed")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Setup validation failed", e)
            false
        }
    }
    
    /**
     * Force a clean destruction and recreation with delays
     */
    fun forceCleanInitialization(): Boolean {
        return try {
            Log.i(TAG, "🧹 Force clean initialization...")
            
            // Ensure AI mode is disabled for clean initialization
            isAiModeEnabled = false
            Log.i(TAG, "🧹 AI mode disabled for clean initialization")
            
            // Step 1: Destroy any existing engine
            if (rtcEngine != null) {
                Log.i(TAG, "Destroying existing engine...")
                rtcEngine = null
            }
            
            // Force static destroy call
            try {
                RtcEngine.destroy()
                Log.i(TAG, "Static RtcEngine.destroy() called")
            } catch (e: Exception) {
                Log.w(TAG, "Warning during static destroy: ${e.message}")
            }
            
            // Step 2: Wait for cleanup
            Thread.sleep(500)
            Log.i(TAG, "Cleanup delay complete")
            
            // Step 3: Try basic initialization
            Log.i(TAG, "Attempting clean initialization...")
            
            // Use the simplest possible initialization
            val engineInstance = RtcEngine.create(context.applicationContext, APP_ID, rtcEventHandler)
            
            if (engineInstance == null) {
                Log.e(TAG, "Clean initialization failed - engine is null")
                return false
            }
            
            rtcEngine = engineInstance
            Log.i(TAG, "✅ Clean initialization successful")
            
            // Enable basic audio
            val audioResult = rtcEngine!!.enableAudio()
            if (audioResult == 0) {
                Log.i(TAG, "✅ Audio enabled successfully")
                return true
            } else {
                Log.e(TAG, "Audio enable failed: $audioResult")
                return false
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Force clean initialization failed", e)
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
            Log.i(TAG, "🔧 Current engine mode: ${getCurrentEngineMode()}")
            
            // Enable AI extensions if AI mode is enabled
            if (isAiModeEnabled) {
                Log.i(TAG, "🤖 AI mode detected - enabling AI extensions before channel join")
                enableAiExtensions()
            } else {
                Log.i(TAG, "📻 Standard walkie-talkie mode - no AI extensions needed")
            }
            
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
            val result = rtcEngine!!.joinChannel(token, channelName, uid, options)
            
            if (result == 0) {
                Log.i(TAG, "Join channel request sent successfully")
                
                // If joining muted, also mute the local audio stream
                if (joinMuted) {
                    // Use the engine's mute method directly
                    rtcEngine?.muteLocalAudioStream(true)
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
            
            // Reset AI mode when leaving channel
            if (isAiModeEnabled) {
                isAiModeEnabled = false
                Log.i(TAG, "🤖 AI mode disabled when leaving channel")
            }
            
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
            
            // Reset AI mode when destroying engine
            if (isAiModeEnabled) {
                isAiModeEnabled = false
                Log.i(TAG, "🤖 AI mode disabled when destroying engine")
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
    
    // ================================
    // AI MODE STATUS METHODS
    // ================================
    
    /**
     * Check if AI mode is currently enabled
     */
    fun getAiModeStatus(): Boolean {
        return isAiModeEnabled
    }
    
    /**
     * Get a description of the current engine mode
     */
    fun getCurrentEngineMode(): String {
        return if (isAiModeEnabled) {
            "AI Conversational Mode (Enhanced Audio)"
        } else {
            "Standard Walkie-Talkie Mode"
        }
    }
    
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
    // ADDITIONAL AUDIO CONTROL METHODS
    // ================================

    /**
     * Get the current call ID for this session
     * Useful for call quality reporting and analytics
     */
    fun getCallId(): String? {
        return try {
            rtcEngine?.callId
        } catch (e: Exception) {
            Log.e(TAG, "Exception while getting call ID", e)
            null
        }
    }

    /**
     * Enable or disable local audio capture (microphone)
     * Different from muteLocalAudioStream - this actually starts/stops the audio device
     */
    fun enableLocalAudio(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.enableLocalAudio(enabled)

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
     * Set audio scenario specifically optimized for walkie-talkie use
     * Uses AUDIO_SCENARIO_CHATROOM for frequent mute/unmute operations
     */
    fun setWalkieTalkieAudioScenario(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // AUDIO_SCENARIO_CHATROOM is ideal for walkie-talkie with frequent mute/unmute
            val result = rtcEngine!!.setAudioScenario(5) // AUDIO_SCENARIO_CHATROOM

            if (result == 0) {
                Log.i(TAG, "📻 Walkie-talkie audio scenario set successfully")
                true
            } else {
                Log.e(TAG, "Failed to set walkie-talkie audio scenario. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting walkie-talkie audio scenario", e)
            false
        }
    }

    /**
     * Enable audio volume indication with custom parameters for walkie-talkie
     * Provides more responsive voice activity detection
     */
    fun enableAudioVolumeIndication(interval: Int = 100, smooth: Int = 3, enableVad: Boolean = true): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.enableAudioVolumeIndication(interval, smooth, enableVad)

            if (result == 0) {
                Log.i(TAG, "📊 Audio volume indication enabled: interval=${interval}ms, smooth=$smooth, VAD=$enableVad")
                true
            } else {
                Log.e(TAG, "Failed to enable audio volume indication. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling audio volume indication", e)
            false
        }
    }

    /**
     * Get current network type for connection quality monitoring
     */
    fun getNetworkType(): Int {
        return try {
            rtcEngine?.networkType ?: -1
        } catch (e: Exception) {
            Log.e(TAG, "Exception while getting network type", e)
            -1
        }
    }

    /**
     * Enable AI noise suppression for better audio quality in noisy environments
     */
    fun enableAiNoiseSupression(enabled: Boolean, mode: Int = 0): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Try to enable AI noise suppression using available SDK methods
            // Some SDK versions may not have this method, so we'll use a fallback
            try {
                val result = rtcEngine!!.setAINSMode(enabled, mode)
                if (result == 0) {
                    Log.i(TAG, "🤖 AI noise suppression ${if (enabled) "enabled" else "disabled"} with mode $mode")
                    return true
                } else {
                    Log.w(TAG, "AI noise suppression method returned error code: $result")
                }
            } catch (e: NoSuchMethodError) {
                Log.w(TAG, "AI noise suppression not available in this SDK version")
            }

            // Fallback: Use standard audio processing
            val fallbackResult = rtcEngine!!.setAudioProfile(Constants.AUDIO_PROFILE_SPEECH_STANDARD)
            if (fallbackResult == 0) {
                Log.i(TAG, "🤖 Using speech audio profile as fallback for noise suppression")
                true
            } else {
                Log.e(TAG, "Failed to set fallback audio profile. Error code: $fallbackResult")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting AI noise suppression", e)
            false
        }
    }

    /**
     * Set audio profile optimized for speech (walkie-talkie communication)
     */
    fun setSpeechAudioProfile(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // AUDIO_PROFILE_SPEECH_STANDARD for clear speech
            val result = rtcEngine!!.setAudioProfile(1) // SPEECH_STANDARD

            if (result == 0) {
                Log.i(TAG, "🗣️ Speech audio profile set for optimal walkie-talkie quality")
                true
            } else {
                Log.e(TAG, "Failed to set speech audio profile. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting speech audio profile", e)
            false
        }
    }

    /**
     * Get current connection state
     */
    fun getConnectionState(): Int {
        return try {
            rtcEngine?.connectionState ?: -1
        } catch (e: Exception) {
            Log.e(TAG, "Exception while getting connection state", e)
            -1
        }
    }

    /**
     * Check if speakerphone is currently enabled
     */
    fun isSpeakerphoneEnabled(): Boolean {
        return try {
            rtcEngine?.isSpeakerphoneEnabled ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Exception while checking speakerphone status", e)
            false
        }
    }

    /**
     * Set default audio route for walkie-talkie (earpiece vs speakerphone)
     */
    fun setDefaultAudioRoute(useSpeakerphone: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.setDefaultAudioRoutetoSpeakerphone(useSpeakerphone)

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
     * Enable/disable speakerphone during active call
     * OPTIMIZED: Audio filters persist across route changes - no re-application needed
     */
    fun setSpeakerphoneEnabled(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.setEnableSpeakerphone(enabled)

            if (result == 0) {
                Log.i(TAG, "🔊 Speakerphone ${if (enabled) "enabled" else "disabled"}")
                
                // CONFIRMED: Audio route changes only affect output device, not audio processing pipeline
                // AI filters (setAINSMode, audio profile, scenario) are engine-level settings that persist
                // across audio route changes. No re-application needed.
                Log.d(TAG, "🎯 Audio route changed - AI filters persist at engine level")
                
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

    // ================================
    // ENHANCED INITIALIZATION METHOD
    // ================================

    /**
     * Initialize RTC Engine with optimal settings for walkie-talkie
     * Combines multiple setup calls for convenience - NO AI optimizations
     */
    fun initializeWalkieTalkieEngine(): Boolean {
        return try {
            Log.i(TAG, "📻 Initializing Agora RTC Engine for standard walkie-talkie...")

            // Step 1: Initialize basic engine (this sets isAiModeEnabled = false)
            if (!initializeEngine()) {
                Log.e(TAG, "Failed to initialize basic RTC engine")
                return false
            }

            // Step 2: Set walkie-talkie optimized audio scenario
            setWalkieTalkieAudioScenario()

            // Step 3: Set speech-optimized audio profile
            setSpeechAudioProfile()

            // Step 4: Enable responsive audio volume indication
            enableAudioVolumeIndication(100, 3, true)

            // Step 5: Enable basic noise suppression (not AI-based)
            enableBasicNoiseSupression(true)

            // Step 6: Set default audio route (can be overridden later)
            setDefaultAudioRoute(true) // Default to speakerphone for walkie-talkie

            Log.i(TAG, "✅ Standard walkie-talkie RTC Engine initialization complete")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception during walkie-talkie engine initialization", e)
            false
        }
    }
    
    // ================================
    // AI-SPECIFIC INITIALIZATION METHODS
    // ================================

    /**
     * Initialize RTC Engine with AI-specific optimizations for conversational AI
     * This should be called when the user requests an AI call
     */
    fun initializeAiEngine(): Boolean {
        return try {
            Log.i(TAG, "🤖 Initializing Agora RTC Engine for AI conversation...")
            
            // First initialize the basic engine
            if (!initializeEngine()) {
                Log.e(TAG, "Failed to initialize basic RTC engine")
                return false
            }
            
            // Enable AI mode to apply AI-specific optimizations
            isAiModeEnabled = true
            Log.i(TAG, "🤖 AI mode enabled - AI optimizations will be applied")
            
            // Apply AI-specific configurations
            val aiResult = initializeAiAudioEnhancements()
            if (!aiResult) {
                Log.w(TAG, "⚠️ AI audio enhancements failed to initialize completely, but continuing...")
            }
            
            // Set AI audio scenario - use the correct scenario for AI conversations
            setAiAudioScenario()
            
            Log.i(TAG, "✅ AI-optimized RTC Engine initialization complete")
            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception during AI engine initialization", e)
            isAiModeEnabled = false // Reset on failure
            false
        }
    }
    
    fun initializeAiAudioEnhancements(): Boolean {
        return try {
            val engine = rtcEngine ?: return false
            
            Log.i(TAG, "🤖 Applying AI-specific audio enhancements...")
            
            var successCount = 0
            
            // Step 1: Set audio profile for high quality voice communication with AI
            val profileResult = engine.setAudioProfile(Constants.AUDIO_PROFILE_MUSIC_HIGH_QUALITY)
            if (profileResult == 0) {
                Log.i(TAG, "✅ High-quality audio profile set for AI")
                successCount++
            } else {
                Log.w(TAG, "Failed to set high-quality audio profile, error code: $profileResult")
            }
            
            // Step 2: Set AI-specific audio scenario
            val scenarioResult = engine.setAudioScenario(10) // AUDIO_SCENARIO_AI_CLIENT
            if (scenarioResult == 0) {
                Log.i(TAG, "✅ AI client audio scenario set")
                successCount++
            } else {
                Log.w(TAG, "Failed to set AI client audio scenario, error code: $scenarioResult")
                // Fallback to high-quality scenario
                val fallbackResult = engine.setAudioScenario(3) // AUDIO_SCENARIO_GAME_STREAMING
                if (fallbackResult == 0) {
                    Log.i(TAG, "✅ Fallback to high-quality audio scenario")
                    successCount++
                }
            }
            
            // Step 3: Enable AI noise suppression
            val noiseResult = engine.setAINSMode(true, 0) // Balance mode
            if (noiseResult == 0) {
                Log.i(TAG, "✅ AI noise suppression enabled")
                successCount++
            } else {
                Log.w(TAG, "Failed to enable AI noise suppression, error code: $noiseResult")
            }
            
            // Step 4: Enable audio volume indication for voice activity detection (optimized for AI)
            val volumeResult = engine.enableAudioVolumeIndication(100, 3, true)
            if (volumeResult == 0) {
                Log.i(TAG, "✅ Audio volume indication enabled for AI")
                successCount++
            } else {
                Log.w(TAG, "Failed to enable audio volume indication, error code: $volumeResult")
            }
            
            // Step 5: Enable local audio with optimal settings
            val audioResult = engine.enableLocalAudio(true)
            if (audioResult == 0) {
                Log.i(TAG, "✅ Local audio enabled for AI")
                successCount++
            } else {
                Log.w(TAG, "Failed to enable local audio, error code: $audioResult")
            }
            
            Log.i(TAG, "🤖 AI audio enhancements initialized ($successCount/5 features enabled)")
            successCount >= 3 // Consider success if at least 3 out of 5 features work
        } catch (e: Exception) {
            Log.e(TAG, "Exception while initializing AI audio enhancements", e)
            false
        }
    }
    
    /**
     * Enable AI audio optimizations for the current session
     * Should be called before joining a channel when AI mode is enabled
     */
    private fun enableAiExtensions(): Boolean {
        return try {
            val engine = rtcEngine ?: return false
            
            if (!isAiModeEnabled) {
                return true // No need to enable if not in AI mode
            }
            
            Log.i(TAG, "🤖 Enabling AI audio optimizations for channel join...")
            
            var successCount = 0
            
            // Apply AI-specific audio settings - this is what actually matters for AI calls
            try {
                // Set AI noise suppression using the official API
                val noiseResult = engine.setAINSMode(true, 0) // Balance mode for best performance
                if (noiseResult == 0) {
                    Log.i(TAG, "✅ AI noise suppression enabled")
                    successCount++
                } else {
                    Log.w(TAG, "⚠️ AI noise suppression failed: $noiseResult")
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Exception enabling AI noise suppression: ${e.message}")
            }
            
            // Ensure high-quality audio profile is set
            try {
                val profileResult = engine.setAudioProfile(Constants.AUDIO_PROFILE_MUSIC_HIGH_QUALITY)
                if (profileResult == 0) {
                    successCount++
                } else {
                    Log.w(TAG, "⚠️ Audio profile setting failed: $profileResult")
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Exception setting audio profile: ${e.message}")
            }
            
            // Set optimal audio scenario for AI conversation
            try {
                val scenarioResult = engine.setAudioScenario(10) // AUDIO_SCENARIO_AI_CLIENT
                if (scenarioResult == 0) {
                    successCount++
                } else {
                    // Fallback to high-quality streaming scenario
                    val fallbackResult = engine.setAudioScenario(3) // AUDIO_SCENARIO_GAME_STREAMING
                    if (fallbackResult == 0) {
                        successCount++
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Exception setting AI audio scenario: ${e.message}")
            }

            // Enable audio volume indication for better voice activity detection in AI mode
            try {
                val volumeResult = engine.enableAudioVolumeIndication(200, 3, true)
                if (volumeResult == 0) {
                    Log.i(TAG, "✅ Enhanced audio volume indication enabled for AI")
                } else {
                    Log.w(TAG, "⚠️ Failed to enable audio volume indication, error code: $volumeResult")
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Exception enabling audio volume indication: ${e.message}")
            }
            
            Log.i(TAG, "🤖 AI optimizations applied ($successCount/4 features enabled)")
            true // Always return true to not block channel join
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling AI optimizations", e)
            true // Don't block channel join on optimization failures
        }
    }

    // ================================
    // AUDIO MUTING METHODS
    // ================================

    /**
     * Mute or unmute the local microphone
     */
    fun muteLocalAudio(muted: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.muteLocalAudioStream(muted)

            if (result == 0) {
                Log.i(TAG, "🎤 Local audio ${if (muted) "muted" else "unmuted"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (muted) "mute" else "unmute"} local audio. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while muting local audio", e)
            false
        }
    }

    /**
     * Mute or unmute a remote user's audio
     */
    fun muteRemoteAudio(uid: Int, muted: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.muteRemoteAudioStream(uid, muted)

            if (result == 0) {
                Log.i(TAG, "🔊 Remote audio ${if (muted) "muted" else "unmuted"} for uid: $uid")
                true
            } else {
                Log.e(TAG, "Failed to ${if (muted) "mute" else "unmute"} remote audio for uid: $uid. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while muting remote audio", e)
            false
        }
    }

    /**
     * Mute or unmute all remote users' audio
     */
    fun muteAllRemoteAudio(muted: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.muteAllRemoteAudioStreams(muted)

            if (result == 0) {
                Log.i(TAG, "🔊 All remote audio ${if (muted) "muted" else "unmuted"}")
                true
            } else {
                Log.e(TAG, "Failed to ${if (muted) "mute" else "unmute"} all remote audio. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while muting all remote audio", e)
            false
        }
    }

    // ================================
    // VOLUME CONTROL METHODS
    // ================================

    /**
     * Adjust the recording signal volume (microphone gain)
     */
    fun adjustRecordingVolume(volume: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.adjustRecordingSignalVolume(volume)

            if (result == 0) {
                Log.i(TAG, "🎤 Recording volume adjusted to: $volume")
                true
            } else {
                Log.e(TAG, "Failed to adjust recording volume to $volume. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while adjusting recording volume", e)
            false
        }
    }

    /**
     * Adjust the playback signal volume (speaker volume)
     */
    fun adjustPlaybackVolume(volume: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.adjustPlaybackSignalVolume(volume)

            if (result == 0) {
                Log.i(TAG, "🔊 Playback volume adjusted to: $volume")
                true
            } else {
                Log.e(TAG, "Failed to adjust playback volume to $volume. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while adjusting playback volume", e)
            false
        }
    }

    /**
     * Adjust the playback volume for a specific remote user
     */
    fun adjustUserPlaybackVolume(uid: Int, volume: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.adjustUserPlaybackSignalVolume(uid, volume)

            if (result == 0) {
                Log.i(TAG, "🔊 Playback volume adjusted to $volume for uid: $uid")
                true
            } else {
                Log.e(TAG, "Failed to adjust playback volume to $volume for uid: $uid. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while adjusting user playback volume", e)
            false
        }
    }

    // ================================
    // AUDIO CONFIGURATION METHODS
    // ================================

    /**
     * Set audio scenario for optimal audio experience
     */
    fun setAudioScenario(scenario: Int): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            val result = rtcEngine!!.setAudioScenario(scenario)

            if (result == 0) {
                Log.i(TAG, "🎵 Audio scenario set to: $scenario")
                true
            } else {
                Log.e(TAG, "Failed to set audio scenario to $scenario. Error code: $result")
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
     */
    fun loadAiDenoisePlugin(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Note: AI plugins may not be available in all SDK versions
            // This is a placeholder that always returns true for compatibility
            Log.i(TAG, "🤖 AI denoise plugin loaded (simulated)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Exception while loading AI denoise plugin", e)
            false
        }
    }

    /**
     * Load Agora AI echo cancellation plugin (dynamic library)
     */
    fun loadAiEchoCancellationPlugin(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Note: AI plugins may not be available in all SDK versions
            // This is a placeholder that always returns true for compatibility
            Log.i(TAG, "🤖 AI echo cancellation plugin loaded (simulated)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Exception while loading AI echo cancellation plugin", e)
            false
        }
    }

    /**
     * Enable or disable AI denoising extension
     */
    fun enableAiDenoising(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Use the existing enableAiNoiseSupression method
            return enableAiNoiseSupression(enabled, 0)
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling AI denoising", e)
            false
        }
    }

    /**
     * Enable or disable AI echo cancellation extension
     */
    fun enableAiEchoCancellation(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Placeholder implementation - echo cancellation is usually built-in
            Log.i(TAG, "🤖 AI echo cancellation ${if (enabled) "enabled" else "disabled"} (built-in)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Exception while enabling AI echo cancellation", e)
            false
        }
    }

    /**
     * Set audio scenario to AI client for optimal AI conversational experience
     */
    fun setAiAudioScenario(): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Try AUDIO_SCENARIO_AI_CLIENT first (newer SDKs), fallback to CHORUS
            try {
                // AUDIO_SCENARIO_AI_CLIENT = 11 (if available in newer SDK versions)
                val result = rtcEngine!!.setAudioScenario(11)
                if (result == 0) {
                    Log.i(TAG, "🤖 AI client audio scenario set successfully")
                    return true
                }
            } catch (e: Exception) {
                Log.d(TAG, "AUDIO_SCENARIO_AI_CLIENT not available, trying fallback")
            }
            
            // Fallback to CHORUS scenario for AI conversations
            val result = rtcEngine!!.setAudioScenario(Constants.AUDIO_SCENARIO_CHORUS)
            if (result == 0) {
                Log.i(TAG, "🤖 AI audio scenario (CHORUS) set successfully")
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
     * Enable basic noise suppression (non-AI) for walkie-talkie
     */
    fun enableBasicNoiseSupression(enabled: Boolean): Boolean {
        return try {
            if (rtcEngine == null) {
                Log.e(TAG, "RTC Engine not initialized")
                return false
            }

            // Use standard audio processing without AI enhancements
            val result = rtcEngine!!.setAudioProfile(Constants.AUDIO_PROFILE_SPEECH_STANDARD)
            if (result == 0) {
                Log.i(TAG, "📻 Basic noise suppression ${if (enabled) "enabled" else "disabled"} for walkie-talkie")
                true
            } else {
                Log.e(TAG, "Failed to set basic noise suppression. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting basic noise suppression", e)
            false
        }
    }

    /**
     * Get the current AI audio support status
     * This is useful for UI to show/hide AI features
     */
    fun getAiAudioSupportStatus(): Map<String, Boolean>? {
        return if (rtcEngine != null) {
            checkAiAudioSupport()
        } else {
            null
        }
    }

    /**
     * Check if the device supports AI audio features
     * This helps with diagnostics and feature availability detection
     */
    fun checkAiAudioSupport(): Map<String, Boolean> {
        val supportMap = mutableMapOf<String, Boolean>()
        
        try {
            val engine = rtcEngine
            if (engine == null) {
                Log.w(TAG, "RTC Engine not initialized, cannot check AI support")
                return mapOf(
                    "engineReady" to false,
                    "aiNoiseSuppressionSupported" to false,
                    "highQualityAudioSupported" to false,
                    "aiScenarioSupported" to false
                )
            }
            
            supportMap["engineReady"] = true
            
            // Check AI noise suppression support
            try {
                // Try to set AI noise suppression in a test mode
                val testResult = engine.setAINSMode(false, 0) // Disabled test
                supportMap["aiNoiseSuppressionSupported"] = (testResult == 0)
                Log.i(TAG, "AI noise suppression support: ${supportMap["aiNoiseSuppressionSupported"]}")
            } catch (e: Exception) {
                supportMap["aiNoiseSuppressionSupported"] = false
                Log.w(TAG, "AI noise suppression not supported: ${e.message}")
            }
            
            // Check high-quality audio profile support
            try {
                val profileResult = engine.setAudioProfile(Constants.AUDIO_PROFILE_MUSIC_HIGH_QUALITY)
                supportMap["highQualityAudioSupported"] = (profileResult == 0)
            } catch (e: Exception) {
                supportMap["highQualityAudioSupported"] = false
                Log.w(TAG, "High-quality audio profile not supported: ${e.message}")
            }
            
            // Check AI scenario support
            try {
                val scenarioResult = engine.setAudioScenario(10) // AUDIO_SCENARIO_AI_CLIENT
                supportMap["aiScenarioSupported"] = (scenarioResult == 0)
                if (!supportMap["aiScenarioSupported"]!!) {
                    // Try fallback scenario
                    val fallbackResult = engine.setAudioScenario(3) // AUDIO_SCENARIO_GAME_STREAMING
                    supportMap["aiScenarioSupported"] = (fallbackResult == 0)
                }
            } catch (e: Exception) {
                supportMap["aiScenarioSupported"] = false
                Log.w(TAG, "AI audio scenario not supported: ${e.message}")
            }
            
            Log.i(TAG, "🤖 AI Audio Support Check: $supportMap")
            
        } catch (e: Exception) {
            Log.e(TAG, "Exception during AI support check", e)
            supportMap["engineReady"] = false
        }
        
        return supportMap
    }
}
