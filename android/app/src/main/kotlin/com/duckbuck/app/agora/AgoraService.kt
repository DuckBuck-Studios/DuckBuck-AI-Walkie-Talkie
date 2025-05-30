package com.duckbuck.app.agora

import android.content.Context
import android.util.Log
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.video.VideoCanvas

class AgoraService(private val context: Context) {
    
    companion object {
        private const val TAG = "AgoraService"
        private const val APP_ID = "3983e52a08424b7da5e79be4c9dfae0f"  
    }
    
    private var rtcEngine: RtcEngine? = null
    private var isJoined = false
    private var isMicMuted = false
    private var isVideoEnabled = true
    private var currentChannelName: String? = null
    private var myUid: Int = 0
    
    // Track remote users in the channel
    private val remoteUsersInChannel = mutableSetOf<Int>()
    
    private var eventListener: AgoraEventListener? = null
    
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            super.onJoinChannelSuccess(channel, uid, elapsed)
            Log.d(TAG, "Join channel success: $channel, uid: $uid")
            isJoined = true
            currentChannelName = channel
            myUid = uid
            // Clear remote users set and start fresh
            remoteUsersInChannel.clear()
            eventListener?.onJoinChannelSuccess(channel ?: "", uid, elapsed)
        }
        
        override fun onLeaveChannel(stats: RtcStats?) {
            super.onLeaveChannel(stats)
            Log.d(TAG, "Leave channel")
            isJoined = false
            currentChannelName = null
            myUid = 0
            // Clear remote users when leaving
            remoteUsersInChannel.clear()
            eventListener?.onLeaveChannel()
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            super.onUserJoined(uid, elapsed)
            Log.d(TAG, "Remote user joined: $uid")
            // Add user to our tracking set
            remoteUsersInChannel.add(uid)
            Log.d(TAG, "Remote users in channel: ${remoteUsersInChannel.size}")
            eventListener?.onUserJoined(uid, elapsed)
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            super.onUserOffline(uid, reason)
            Log.d(TAG, "Remote user offline: $uid, reason: $reason")
            // Remove user from our tracking set
            remoteUsersInChannel.remove(uid)
            Log.d(TAG, "Remote users in channel after user left: ${remoteUsersInChannel.size}")
            
            // Notify about this specific user leaving
            eventListener?.onUserOffline(uid, reason)
            
            // Check if channel is now empty (only we are left)
            if (remoteUsersInChannel.isEmpty() && isJoined) {
                Log.i(TAG, "🏃‍♂️ All other users have left the channel - triggering auto-leave")
                // Call force leave directly as a failsafe
                val autoLeaveResult = forceLeaveChannel()
                Log.i(TAG, "🚪 Auto-leave result: ${if(autoLeaveResult) "SUCCESS" else "FAILED"}")
                
                // Also notify listeners for additional handling
                eventListener?.onAllUsersLeft()
                eventListener?.onChannelEmpty()
            }
        }
        
        override fun onError(err: Int) {
            super.onError(err)
            Log.e(TAG, "Agora error: $err")
            val errorMessage = getErrorMessage(err)
            eventListener?.onError(err, errorMessage)
        }
    }
    
    /**
     * Initialize Agora RTC Engine
     */
    fun initializeEngine(): Boolean {
        return try {
            // Check if engine already exists and destroy it first
            if (rtcEngine != null) {
                Log.d(TAG, "Existing RTC Engine found, destroying it before creating new one")
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
                    Log.d(TAG, "Previous RTC Engine destroyed successfully")
                } catch (destroyException: Exception) {
                    Log.w(TAG, "Warning: Failed to properly destroy previous RTC Engine", destroyException)
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
                Log.d(TAG, "Creating Agora RTC Engine with config: appId=${APP_ID.substring(0, 4)}...")
                rtcEngine = RtcEngine.create(config)
                
                if (rtcEngine == null) {
                    Log.e(TAG, "RTC Engine creation returned null - critical error")
                    return false
                }
                
                Log.d(TAG, "RTC Engine created successfully, applying configuration")
                
                // Apply necessary configurations right after creation
                rtcEngine?.setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
                rtcEngine?.enableVideo()
                rtcEngine?.enableAudio()
                
                // Set audio profile for better call quality
                rtcEngine?.setAudioProfile(
                    Constants.AUDIO_PROFILE_DEFAULT,
                    Constants.AUDIO_SCENARIO_CHATROOM
                )
                
                // Set default audio route
                rtcEngine?.setDefaultAudioRoutetoSpeakerphone(true)
                
                // Give the engine sufficient time to complete internal initialization
                // This prevents timing issues where joinChannel is called immediately after creation
                Log.d(TAG, "Waiting for engine to fully initialize...")
                Thread.sleep(300)
                
                // Extra validation to confirm initialization succeeded
                if (rtcEngine == null) {
                    Log.e(TAG, "Engine is null after initialization delay - something went wrong")
                    return false
                }
            } catch (e: InterruptedException) {
                Log.w(TAG, "Engine initialization delay interrupted", e)
                Thread.currentThread().interrupt()
            } catch (e: Exception) {
                Log.e(TAG, "Error during post-initialization configuration", e)
                return false
            }
            
            Log.d(TAG, "Agora RTC Engine initialized successfully and ready for operations")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Agora RTC Engine", e)
            false
        }
    }
    
    /**
     * Join a channel
     */
    fun joinChannel(channelName: String, token: String? = null, uid: Int = 0): Boolean {
        if (rtcEngine == null) {
            Log.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        if (isJoined) {
            Log.w(TAG, "Already joined a channel. Leave current channel first.")
            return false
        }
        
        try {
            val options = ChannelMediaOptions().apply {
                channelProfile = Constants.CHANNEL_PROFILE_COMMUNICATION
                clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
                autoSubscribeAudio = true
                autoSubscribeVideo = true
                publishCameraTrack = true
                publishMicrophoneTrack = true
            }
            
            val result = rtcEngine?.joinChannel(token, channelName, uid, options)
            
            return if (result == 0) {
                Log.d(TAG, "Joining channel: $channelName")
                true
            } else {
                Log.e(TAG, "Failed to join channel. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while joining channel", e)
            return false
        }
    }
    
    /**
     * Leave the current channel
     */
    fun leaveChannel(): Boolean {
        if (rtcEngine == null) {
            Log.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        if (!isJoined) {
            Log.w(TAG, "Not currently in any channel")
            return false
        }
        
        return try {
            val result = rtcEngine?.leaveChannel()
            
            if (result == 0) {
                Log.d(TAG, "Leaving channel: $currentChannelName")
                true
            } else {
                Log.e(TAG, "Failed to leave channel. Error code: $result")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while leaving channel", e)
            false
        }
    }
    
    /**
     * Toggle microphone on/off
     */
    fun toggleMicrophone(): Boolean {
        if (rtcEngine == null) {
            Log.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        return try {
            isMicMuted = !isMicMuted
            val result = rtcEngine?.muteLocalAudioStream(isMicMuted)
            
            if (result == 0) {
                Log.d(TAG, "Microphone ${if (isMicMuted) "muted" else "unmuted"}")
                eventListener?.onMicrophoneToggled(isMicMuted)
                true
            } else {
                Log.e(TAG, "Failed to toggle microphone. Error code: $result")
                // Revert the state if operation failed
                isMicMuted = !isMicMuted
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while toggling microphone", e)
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
     * Toggle video on/off
     */
    fun toggleVideo(): Boolean {
        if (rtcEngine == null) {
            Log.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        return try {
            isVideoEnabled = !isVideoEnabled
            val result = rtcEngine?.muteLocalVideoStream(!isVideoEnabled)
            
            if (result == 0) {
                Log.d(TAG, "Video ${if (isVideoEnabled) "enabled" else "disabled"}")
                eventListener?.onVideoToggled(isVideoEnabled)
                true
            } else {
                Log.e(TAG, "Failed to toggle video. Error code: $result")
                // Revert the state if operation failed
                isVideoEnabled = !isVideoEnabled
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception while toggling video", e)
            // Revert the state if operation failed
            isVideoEnabled = !isVideoEnabled
            false
        }
    }
    
    /**
     * Turn video on
     */
    fun turnVideoOn(): Boolean {
        if (!isVideoEnabled) {
            return toggleVideo()
        }
        return true // Already on
    }
    
    /**
     * Turn video off
     */
    fun turnVideoOff(): Boolean {
        if (isVideoEnabled) {
            return toggleVideo()
        }
        return true // Already off
    }
    
    /**
     * Set up local video view
     */
    fun setupLocalVideo(view: android.view.SurfaceView): Boolean {
        if (rtcEngine == null) {
            Log.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        return try {
            val videoCanvas = VideoCanvas(view, VideoCanvas.RENDER_MODE_HIDDEN, 0)
            rtcEngine?.setupLocalVideo(videoCanvas)
            Log.d(TAG, "Local video setup completed")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting up local video", e)
            false
        }
    }
    
    /**
     * Set up remote video view
     */
    fun setupRemoteVideo(view: android.view.SurfaceView, uid: Int): Boolean {
        if (rtcEngine == null) {
            Log.e(TAG, "RTC Engine not initialized")
            return false
        }
        
        return try {
            val videoCanvas = VideoCanvas(view, VideoCanvas.RENDER_MODE_HIDDEN, uid)
            rtcEngine?.setupRemoteVideo(videoCanvas)
            Log.d(TAG, "Remote video setup completed for uid: $uid")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Exception while setting up remote video", e)
            false
        }
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
     * Get current video status
     */
    fun isVideoEnabled(): Boolean = isVideoEnabled
    
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
                Log.d(TAG, "RTC Engine connection state: $connectionState")
                
                // Test parameter setting (safe operation that should not fail)
                rtcEngine?.setParameters("{\"che.audio.keep_audiosession\": true}")
                
                // Basic audio control that should work if engine is ready
                rtcEngine?.setDefaultAudioRoutetoSpeakerphone(true)
                
                Log.d(TAG, "✅ RTC Engine is confirmed to be fully initialized and responsive")
                return true
            } catch (e: Exception) {
                Log.e(TAG, "❌ Engine verification failed. Engine exists but is not properly initialized: ${e.message}", e)
                
                // Try to diagnose the specific issue
                try {
                    if (rtcEngine?.getConnectionState() == Constants.CONNECTION_STATE_DISCONNECTED) {
                        Log.d(TAG, "Engine is in disconnected state - this is normal before joining a channel")
                    }
                } catch (e2: Exception) {
                    Log.e(TAG, "Could not even check connection state - engine is in a bad state", e2)
                }
                
                return false
            }
        }
        
        Log.e(TAG, "❌ RTC Engine is null - not initialized")
        return false
    }
    
    /**
     * Force leave channel and cleanup (used for auto-leave scenarios)
     */
    fun forceLeaveChannel(): Boolean {
        Log.i(TAG, "🚪 Force leaving channel due to auto-leave trigger")
        
        try {
            // Check if we're already joined to avoid unnecessary operations
            if (!isJoined) {
                Log.w(TAG, "Not in a channel - no need to force leave")
                return true
            }
            
            // Always clear our tracking data regardless of outcome
            remoteUsersInChannel.clear()
            
            // Try to leave the channel properly
            val leaveResult = rtcEngine?.leaveChannel() == 0
            
            if (leaveResult) {
                Log.i(TAG, "✅ Successfully left channel via forceLeaveChannel")
                isJoined = false
                currentChannelName = null
                myUid = 0
            } else {
                Log.e(TAG, "❌ Failed to leave channel via forceLeaveChannel")
                // Force the state to be reset even if API call failed
                isJoined = false
                currentChannelName = null
                myUid = 0
            }
            
            return leaveResult
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception during forceLeaveChannel", e)
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
            Log.d(TAG, "Agora RTC Engine destroyed")
        } catch (e: Exception) {
            Log.e(TAG, "Exception while destroying RTC Engine", e)
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
        fun onVideoToggled(isEnabled: Boolean)
        fun onError(errorCode: Int, errorMessage: String)
        fun onAllUsersLeft() {}
        fun onChannelEmpty() {}
    }
}
