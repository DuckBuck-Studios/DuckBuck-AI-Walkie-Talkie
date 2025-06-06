package com.duckbuck.app.agora
import com.duckbuck.app.core.AppLogger

import android.content.Context
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.IRtcEngineEventHandler.AudioVolumeInfo
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class AgoraService(private val context: Context) {
    
    companion object {
        private const val TAG = "AgoraService"
        private const val APP_ID = "3983e52a08424b7da5e79be4c9dfae0f"  
    }
    
    private var rtcEngine: RtcEngine? = null
    private var isJoined = false
    private var isMicMuted = false
    private var isSpeakerOn = true
    private var currentChannelName: String? = null
    private var myUid: Int = 0
    
    // Track remote users in the channel
    private val remoteUsersInChannel = mutableSetOf<Int>()
    
    // For joinChannelAndWaitForUsers functionality
    private var userJoinedLatch: CountDownLatch? = null
    private var isWaitingForUsers = false
    
    private var eventListener: AgoraEventListener? = null
    
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            super.onJoinChannelSuccess(channel, uid, elapsed)
            AppLogger.d(TAG, "Join channel success: $channel, uid: $uid")
            isJoined = true
            currentChannelName = channel
            myUid = uid
            // Clear remote users set and start fresh
            remoteUsersInChannel.clear()
            eventListener?.onJoinChannelSuccess(channel ?: "", uid, elapsed)
        }
        
        override fun onLeaveChannel(stats: RtcStats?) {
            super.onLeaveChannel(stats)
            AppLogger.d(TAG, "Leave channel")
            isJoined = false
            currentChannelName = null
            myUid = 0
            // Clear remote users when leaving
            remoteUsersInChannel.clear()
            eventListener?.onLeaveChannel()
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            super.onUserJoined(uid, elapsed)
            AppLogger.d(TAG, "Remote user joined: $uid")
            // Add user to our tracking set
            remoteUsersInChannel.add(uid)
            AppLogger.d(TAG, "Remote users in channel: ${remoteUsersInChannel.size}")
            
            // If we're waiting for users to join, signal the latch
            if (isWaitingForUsers && userJoinedLatch != null) {
                AppLogger.d(TAG, "User joined while waiting - signaling latch")
                userJoinedLatch?.countDown()
            }
            
            eventListener?.onUserJoined(uid, elapsed)
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            super.onUserOffline(uid, reason)
            AppLogger.d(TAG, "Remote user offline: $uid, reason: $reason")
            // Remove user from our tracking set
            remoteUsersInChannel.remove(uid)
            AppLogger.d(TAG, "Remote users in channel after user left: ${remoteUsersInChannel.size}")
            
            // Notify about this specific user leaving
            eventListener?.onUserOffline(uid, reason)
            
            // Check if channel is now empty (only we are left)
            if (remoteUsersInChannel.isEmpty() && isJoined) {
                AppLogger.i(TAG, "🏃‍♂️ All other users have left the channel - triggering auto-leave")
                // Call force leave directly as a failsafe
                val autoLeaveResult = forceLeaveChannel()
                AppLogger.i(TAG, "🚪 Auto-leave result: ${if(autoLeaveResult) "SUCCESS" else "FAILED"}")
                
                // Also notify listeners for additional handling
                eventListener?.onAllUsersLeft()
                eventListener?.onChannelEmpty()
            }
        }
        
        override fun onError(err: Int) {
            super.onError(err)
            AppLogger.e(TAG, "Agora error: $err")
            val errorMessage = getErrorMessage(err)
            eventListener?.onError(err, errorMessage)
        }
        
        override fun onAudioVolumeIndication(speakers: Array<AudioVolumeInfo>?, totalVolume: Int) {
            super.onAudioVolumeIndication(speakers, totalVolume)
            
            speakers?.forEach { audioInfo ->
                val uid = audioInfo.uid
                val volume = audioInfo.volume
                val vad = audioInfo.vad // Voice Activity Detection
                
                // Only process remote users (not ourselves) and only when actively speaking
                if (uid != 0 && uid != myUid && volume > 0 && vad > 0) {
                    AppLogger.d(TAG, "🎤 User $uid is speaking (volume: $volume, vad: $vad)")
                    eventListener?.onUserSpeaking(uid, volume, true)
                } else if (uid != 0 && uid != myUid && (volume == 0 || vad == 0)) {
                    // User stopped speaking
                    eventListener?.onUserSpeaking(uid, volume, false)
                }
            }
        }
    }
    
    /**
     * Initialize Agora RTC Engine
     */
    fun initializeEngine(): Boolean {
        return try {
            // Check if engine already exists and destroy it first
            if (rtcEngine != null) {
                AppLogger.d(TAG, "Existing RTC Engine found, destroying it before creating new one")
                try {
                    if (isJoined) {
                        leaveChannel()
                    }
                    // Clear tracking data
                    remoteUsersInChannel.clear()
                    myUid = 0
                    
                    rtcEngine?.let {
                        RtcEngine.destroy()
                        rtcEngine = null
                    }
                    AppLogger.d(TAG, "Previous RTC Engine destroyed successfully")
                } catch (destroyException: Exception) {
                    AppLogger.w(TAG, "Warning: Failed to properly destroy previous RTC Engine", destroyException)
                    // Continue with initialization even if destroy failed
                    rtcEngine = null
                }
            }
            
            try {
                // Create configuration with proper error handling
                val config = RtcEngineConfig()
                config.mContext = context
                config.mAppId = APP_ID
                config.mEventHandler = rtcEventHandler
                // Set area code for better performance based on region
                config.mAreaCode = RtcEngineConfig.AreaCode.AREA_CODE_GLOB
                
                // Create engine with better error handling
                AppLogger.d(TAG, "Creating Agora RTC Engine with config: appId=${APP_ID.substring(0, 4)}...")
                rtcEngine = RtcEngine.create(config)
                
                if (rtcEngine == null) {
                    AppLogger.e(TAG, "RTC Engine creation returned null - critical error")
                    return false
                }
                
                AppLogger.d(TAG, "RTC Engine created successfully, applying configuration")
                
                // Apply necessary configurations right after creation
                rtcEngine?.setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
                rtcEngine?.enableAudio()
                
                // Enable audio volume indication for speaking detection
                // Interval: 200ms, smooth: 3 (smooth the volume), reportVad: true (voice activity detection)
                rtcEngine?.enableAudioVolumeIndication(200, 3, true)
                AppLogger.d(TAG, "Audio volume indication enabled for speaking detection")
                
                // Set audio profile for better call quality
                rtcEngine?.setAudioProfile(
                    Constants.AUDIO_PROFILE_DEFAULT,
                    Constants.AUDIO_SCENARIO_CHATROOM
                )
                
                // Set default audio route to speaker
                rtcEngine?.setDefaultAudioRoutetoSpeakerphone(isSpeakerOn)
                
                // Give the engine sufficient time to complete internal initialization
                // This prevents timing issues where joinChannel is called immediately after creation
                AppLogger.d(TAG, "Waiting for engine to fully initialize...")
                
                // Use asynchronous delay to avoid blocking the main thread
                val initializationLatch = java.util.concurrent.CountDownLatch(1)
                val initHandler = android.os.Handler(android.os.Looper.getMainLooper())
                
                initHandler.postDelayed({
                    initializationLatch.countDown()
                }, 300)
                
                // Wait for initialization with timeout
                try {
                    val initialized = initializationLatch.await(500, java.util.concurrent.TimeUnit.MILLISECONDS)
                    if (!initialized) {
                        AppLogger.w(TAG, "Engine initialization timeout, proceeding anyway")
                    }
                } catch (e: InterruptedException) {
                    AppLogger.w(TAG, "Engine initialization interrupted", e)
                    Thread.currentThread().interrupt()
                }
                
                // Extra validation to confirm initialization succeeded
                if (rtcEngine == null) {
                    AppLogger.e(TAG, "Engine is null after initialization delay - something went wrong")
                    return false
                }
            } catch (e: InterruptedException) {
                AppLogger.w(TAG, "Engine initialization delay interrupted", e)
                Thread.currentThread().interrupt()
            } catch (e: Exception) {
                AppLogger.e(TAG, "Error during post-initialization configuration", e)
                return false
            }
            
            AppLogger.d(TAG, "Agora RTC Engine initialized successfully and ready for operations")
            true
        } catch (e: Exception) {
            AppLogger.e(TAG, "Failed to initialize Agora RTC Engine", e)
            false
        }
    }
    
    /**
     * Join a channel
     */
    fun joinChannel(channelName: String, token: String? = null, uid: Int = 0): Boolean {
        if (rtcEngine == null) {
            AppLogger.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        if (isJoined) {
            AppLogger.w(TAG, "Already joined a channel. Leave current channel first.")
            return false
        }
        
        try {
            val options = ChannelMediaOptions().apply {
                channelProfile = Constants.CHANNEL_PROFILE_COMMUNICATION
                clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
                autoSubscribeAudio = true
                autoSubscribeVideo = false
                publishCameraTrack = false
                publishMicrophoneTrack = true
            }
            
            val result = rtcEngine?.joinChannel(token, channelName, uid, options)
            
            return if (result == 0) {
                AppLogger.d(TAG, "Joining channel: $channelName")
                true
            } else {
                AppLogger.e(TAG, "Failed to join channel. Error code: $result")
                false
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Exception while joining channel", e)
            return false
        }
    }
    
    /**
     * Join a channel and wait for other users to join within the specified timeout
     * @param channelName The name of the channel to join
     * @param token Optional token for channel authentication
     * @param uid User ID (0 for auto-assignment)
     * @param timeoutSeconds Maximum time to wait for users (default 15 seconds)
     * @return true if users joined within timeout, false otherwise
     */
    fun joinChannelAndWaitForUsers(
        channelName: String, 
        token: String? = null, 
        uid: Int = 0, 
        timeoutSeconds: Int = 15
    ): Boolean {
        AppLogger.d(TAG, "joinChannelAndWaitForUsers: $channelName, timeout: ${timeoutSeconds}s")
        
        // First, try to join the channel using existing method
        val joinResult = joinChannel(channelName, token, uid)
        if (!joinResult) {
            AppLogger.e(TAG, "Failed to join channel in joinChannelAndWaitForUsers")
            return false
        }
        
        // Check if there are already users in the channel
        if (remoteUsersInChannel.isNotEmpty()) {
            AppLogger.d(TAG, "Users already present in channel: ${remoteUsersInChannel.size}")
            return true
        }
        
        // Set up waiting mechanism
        isWaitingForUsers = true
        userJoinedLatch = CountDownLatch(1)
        
        AppLogger.d(TAG, "Waiting for users to join channel for $timeoutSeconds seconds...")
        
        return try {
            // Wait for the specified timeout or until someone joins
            val userJoined = userJoinedLatch?.await(timeoutSeconds.toLong(), TimeUnit.SECONDS) ?: false
            
            if (userJoined) {
                AppLogger.d(TAG, "✅ User(s) joined within timeout! Users in channel: ${remoteUsersInChannel.size}")
                true
            } else {
                AppLogger.d(TAG, "❌ No users joined within $timeoutSeconds seconds timeout")
                false
            }
        } catch (e: InterruptedException) {
            AppLogger.w(TAG, "Wait for users interrupted", e)
            Thread.currentThread().interrupt()
            false
        } catch (e: Exception) {
            AppLogger.e(TAG, "Exception while waiting for users", e)
            false
        } finally {
            // Cleanup waiting state
            isWaitingForUsers = false
            userJoinedLatch = null
            AppLogger.d(TAG, "Cleaned up waiting state")
        }
    }
    
    /**
     * Leave the current channel
     */
    fun leaveChannel(): Boolean {
        if (rtcEngine == null) {
            AppLogger.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        if (!isJoined) {
            AppLogger.w(TAG, "Not currently in any channel")
            return false
        }
        
        return try {
            val result = rtcEngine?.leaveChannel()
            
            if (result == 0) {
                AppLogger.d(TAG, "Leaving channel: $currentChannelName")
                true
            } else {
                AppLogger.e(TAG, "Failed to leave channel. Error code: $result")
                false
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Exception while leaving channel", e)
            false
        }
    }
    
    /**
     * Toggle microphone on/off
     */
    fun toggleMicrophone(): Boolean {
        if (rtcEngine == null) {
            AppLogger.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        return try {
            isMicMuted = !isMicMuted
            val result = rtcEngine?.muteLocalAudioStream(isMicMuted)
            
            if (result == 0) {
                AppLogger.d(TAG, "Microphone ${if (isMicMuted) "muted" else "unmuted"}")
                eventListener?.onMicrophoneToggled(isMicMuted)
                true
            } else {
                AppLogger.e(TAG, "Failed to toggle microphone. Error code: $result")
                // Revert the state if operation failed
                isMicMuted = !isMicMuted
                false
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Exception while toggling microphone", e)
            // Revert the state if operation failed
            isMicMuted = !isMicMuted
            false
        }
    }
    
    /**
     * Turn microphone on
     */
    fun turnMicrophoneOn(): Boolean {
        if (isMicMuted) {
            return toggleMicrophone()
        }
        return true // Already on
    }
    
    /**
     * Turn microphone off
     */
    fun turnMicrophoneOff(): Boolean {
        if (!isMicMuted) {
            return toggleMicrophone()
        }
        return true // Already off
    }
    
    /**
     * Toggle speaker on/off
     */
    fun toggleSpeaker(): Boolean {
        if (rtcEngine == null) {
            AppLogger.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        return try {
            isSpeakerOn = !isSpeakerOn
            val result = rtcEngine?.setDefaultAudioRoutetoSpeakerphone(isSpeakerOn)
            
            if (result == 0) {
                AppLogger.d(TAG, "Speaker ${if (isSpeakerOn) "enabled" else "disabled"}")
                eventListener?.onSpeakerToggled(isSpeakerOn)
                true
            } else {
                AppLogger.e(TAG, "Failed to toggle speaker. Error code: $result")
                // Revert the state if operation failed
                isSpeakerOn = !isSpeakerOn
                false
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Exception while toggling speaker", e)
            // Revert the state if operation failed
            isSpeakerOn = !isSpeakerOn
            false
        }
    }
    
    /**
     * Turn speaker on
     */
    fun turnSpeakerOn(): Boolean {
        if (!isSpeakerOn) {
            return toggleSpeaker()
        }
        return true // Already on
    }
    
    /**
     * Turn speaker off
     */
    fun turnSpeakerOff(): Boolean {
        if (isSpeakerOn) {
            return toggleSpeaker()
        }
        return true // Already off
    }
    
    /**
     * Set event listener for callbacks
     */
    fun setEventListener(listener: AgoraEventListener) {
        this.eventListener = listener
    }
    
    /**
     * Remove event listener
     */
    fun removeEventListener() {
        this.eventListener = null
    }
    
    /**
     * Get current channel status
     */
    fun isChannelJoined(): Boolean = isJoined
    
    /**
     * Get current microphone status
     */
    fun isMicrophoneMuted(): Boolean = isMicMuted
    
    /**
     * Get current speaker status
     */
    fun isSpeakerEnabled(): Boolean = isSpeakerOn
    
    /**
     * Get current channel name
     */
    fun getCurrentChannelName(): String? = currentChannelName
    
    /**
     * Get my UID in the channel
     */
    fun getMyUid(): Int = myUid
    
    /**
     * Get number of remote users in channel
     */
    fun getRemoteUserCount(): Int = remoteUsersInChannel.size
    
    /**
     * Check if channel has other users besides me
     */
    fun hasOtherUsers(): Boolean = remoteUsersInChannel.isNotEmpty()
    
    /**
     * Get list of remote user UIDs
     */
    fun getRemoteUserIds(): Set<Int> = remoteUsersInChannel.toSet()
    
    /**
     * Check if RTC Engine is initialized and ready
     */
    fun isEngineInitialized(): Boolean {
        val engineExists = rtcEngine != null
        
        // Additional verification that the engine is actually ready
        if (engineExists) {
            try {
                // Get RTC Engine state (should not throw exception if properly initialized)
                val connectionState = rtcEngine?.getConnectionState() ?: -1
                AppLogger.d(TAG, "RTC Engine connection state: $connectionState")
                
                // Test parameter setting (safe operation that should not fail)
                rtcEngine?.setParameters("{\"che.audio.keep_audiosession\": true}")
                
                // Basic audio control that should work if engine is ready
                rtcEngine?.setDefaultAudioRoutetoSpeakerphone(isSpeakerOn)
                
                AppLogger.d(TAG, "✅ RTC Engine is confirmed to be fully initialized and responsive")
                return true
            } catch (e: Exception) {
                AppLogger.e(TAG, "❌ Engine verification failed. Engine exists but is not properly initialized: ${e.message}", e)
                
                // Try to diagnose the specific issue
                try {
                    if (rtcEngine?.getConnectionState() == Constants.CONNECTION_STATE_DISCONNECTED) {
                        AppLogger.d(TAG, "Engine is in disconnected state - this is normal before joining a channel")
                    }
                } catch (e2: Exception) {
                    AppLogger.e(TAG, "Could not even check connection state - engine is in a bad state", e2)
                }
                
                return false
            }
        }
        
        AppLogger.e(TAG, "❌ RTC Engine is null - not initialized")
        return false
    }
    
    /**
     * Force leave channel and cleanup (used for auto-leave scenarios)
     */
    fun forceLeaveChannel(): Boolean {
        AppLogger.i(TAG, "🚪 Force leaving channel due to auto-leave trigger")
        
        try {
            // Check if we're already joined to avoid unnecessary operations
            if (!isJoined) {
                AppLogger.w(TAG, "Not in a channel - no need to force leave")
                return true
            }
            
            // Always clear our tracking data regardless of outcome
            remoteUsersInChannel.clear()
            
            // Try to leave the channel properly
            val leaveResult = rtcEngine?.leaveChannel() == 0
            
            if (leaveResult) {
                AppLogger.i(TAG, "✅ Successfully left channel via forceLeaveChannel")
                isJoined = false
                currentChannelName = null
                myUid = 0
            } else {
                AppLogger.e(TAG, "❌ Failed to leave channel via forceLeaveChannel")
                // Force the state to be reset even if API call failed
                isJoined = false
                currentChannelName = null
                myUid = 0
            }
            
            return leaveResult
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Exception during forceLeaveChannel", e)
            // Force reset state even when exception occurs
            isJoined = false
            currentChannelName = null
            myUid = 0
            remoteUsersInChannel.clear()
            return false
        }
    }
    
    /**
     * Destroy the RTC Engine
     */
    fun destroy() {
        try {
            if (isJoined) {
                leaveChannel()
            }
            // Clear tracking data
            remoteUsersInChannel.clear()
            myUid = 0
            
            rtcEngine?.let {
                RtcEngine.destroy()
                rtcEngine = null
            }
            eventListener = null
            AppLogger.d(TAG, "Agora RTC Engine destroyed")
        } catch (e: Exception) {
            AppLogger.e(TAG, "Exception while destroying RTC Engine", e)
        }
    }
    
    /**
     * Convert error code to human-readable message
     */
    private fun getErrorMessage(errorCode: Int): String {
        return when (errorCode) {
            Constants.ERR_INVALID_APP_ID -> "Invalid App ID"
            Constants.ERR_INVALID_CHANNEL_NAME -> "Invalid channel name" 
            Constants.ERR_REFUSED -> "Request refused"
            Constants.ERR_NOT_INITIALIZED -> "RTC Engine not initialized"
            Constants.ERR_INVALID_ARGUMENT -> "Invalid argument"
            Constants.ERR_JOIN_CHANNEL_REJECTED -> "Join channel rejected"
            Constants.ERR_LEAVE_CHANNEL_REJECTED -> "Leave channel rejected"
            Constants.ERR_ALREADY_IN_USE -> "Already in use"
            Constants.ERR_ABORTED -> "Operation aborted"
            Constants.ERR_INIT_NET_ENGINE -> "Network engine initialization failed"
            Constants.ERR_RESOURCE_LIMITED -> "Resource limited"
            Constants.ERR_INVALID_USER_ACCOUNT -> "Invalid user account"
            Constants.ERR_AUDIO_BT_SCO_FAILED -> "Bluetooth SCO failed"
            Constants.ERR_ADM_GENERAL_ERROR -> "Audio device module general error"
            else -> "Unknown error: $errorCode"
        }
    }
    
    /**
     * Event listener interface for Agora callbacks
     */
    interface AgoraEventListener {
        fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int)
        fun onLeaveChannel()
        fun onUserJoined(uid: Int, elapsed: Int)
        fun onUserOffline(uid: Int, reason: Int)
        fun onMicrophoneToggled(isMuted: Boolean)
        fun onSpeakerToggled(isEnabled: Boolean)
        fun onError(errorCode: Int, errorMessage: String)
        fun onAllUsersLeft() {}
        fun onChannelEmpty() {}
        fun onUserSpeaking(uid: Int, volume: Int, isSpeaking: Boolean) {}
    }
}
