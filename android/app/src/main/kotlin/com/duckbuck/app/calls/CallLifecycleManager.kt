package com.duckbuck.app.calls
import com.duckbuck.app.core.AppLogger

import android.content.Context
import com.duckbuck.app.agora.AgoraCallManager
import com.duckbuck.app.agora.AgoraService
import com.duckbuck.app.callstate.CallStatePersistenceManager
import com.duckbuck.app.core.AgoraServiceManager
import com.duckbuck.app.core.CallUITrigger
import com.duckbuck.app.fcm.FcmDataHandler.CallData
import com.duckbuck.app.notifications.CallNotificationManager
import com.duckbuck.app.audio.VolumeAcquireManager

/**
 * Call Lifecycle Manager - Coordinates call operations across all modules
 * 
 * This manager orchestrates:
 * - Call state persistence
 * - Notification management
 * - Agora call operations
 * - Lifecycle event handling
 * 
 * Acts as a higher-level coordinator for complex call operations
 */
class CallLifecycleManager(private val context: Context) {
    
    companion object {
        private const val TAG = "CallLifecycleManager"
    }
    
    private val callStatePersistence = CallStatePersistenceManager(context)
    private val notificationManager = CallNotificationManager(context)
    private val agoraCallManager = AgoraCallManager(context)
    private val volumeAcquireManager = VolumeAcquireManager(context)
    
    /**
     * Handle incoming call - full lifecycle management
     */
    fun handleIncomingCall(
        callData: CallData,
        shouldAutoJoin: Boolean = false
    ): Boolean {
        try {
            AppLogger.i(TAG, "📞 Handling incoming call: ${callData.callName}")
            
            // 1. Persist the incoming call
            callStatePersistence.saveIncomingCallData(callData)
            
            // 2. For traditional calls, no auto-notification (use walkie-talkie flow instead)
            AppLogger.i(TAG, "⚠️  Legacy call flow - consider using walkie-talkie flow instead")
            
            // 3. Auto-join if requested (for foreground scenarios)
            if (shouldAutoJoin) {
                return joinCall(callData)
            }
            
            return true
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error handling incoming call", e)
            return false
        }
    }
    
    /**
     * Join a call with full lifecycle management
     */
    fun joinCall(callData: CallData): Boolean {
        try {
            AppLogger.i(TAG, "🔗 Joining call: ${callData.channelId}")
            
            // 1. Mark as joining
            callStatePersistence.markCallAsJoining(callData.channelId)
            
            // 2. Attempt to join
            val joined = agoraCallManager.joinCallOptimized(
                token = callData.token,
                uid = callData.uid,
                channelId = callData.channelId,
                eventListener = createCallEventListener(callData.channelId, callData.callName)
            )
            
            if (joined) {
                // 3. Mark as successfully joined
                callStatePersistence.markCallAsJoined(callData.channelId)
                
                // 4. Legacy call flow - no active call notification
                AppLogger.i(TAG, "⚠️  Legacy call joined - consider using walkie-talkie flow")
                
                AppLogger.i(TAG, "✅ Successfully joined call: ${callData.channelId}")
                return true
            } else {
                AppLogger.e(TAG, "❌ Failed to join call: ${callData.channelId}")
                return false
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error joining call", e)
            return false
        }
    }
    
    /**
     * End/leave current call
     */
    fun endCall(): Boolean {
        try {
            val currentCall = callStatePersistence.getCurrentCallData()
            if (currentCall == null) {
                AppLogger.w(TAG, "⚠️ No active call to end")
                return false
            }
            
            AppLogger.i(TAG, "📴 Ending call: ${currentCall.channelId}")
            
            // 1. Mark as ending
            callStatePersistence.markCallAsEnding(currentCall.channelId)
            
            // 2. Leave Agora channel (this will trigger onLeaveChannel callback)
            // The callback will handle cleanup
            
            return true
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error ending call", e)
            return false
        }
    }
    
    /**
     * Get current call status
     */
    fun getCurrentCallStatus(): CallStatus {
        val callData = callStatePersistence.getCurrentCallData()
        val callState = callStatePersistence.getCurrentCallState()
        val isActive = callStatePersistence.isInActiveCall()
        val duration = callStatePersistence.getCallDuration()
        
        return CallStatus(
            callData = callData,
            state = callState,
            isActive = isActive,
            duration = duration
        )
    }
    
    /**
     * Clear all call data and notifications (emergency cleanup)
     */
    fun clearAllCallData() {
        try {
            AppLogger.i(TAG, "🧹 Clearing all call data")
            callStatePersistence.clearCallData()
            notificationManager.clearWalkieTalkieNotifications()
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error clearing call data", e)
        }
    }
    
    /**
     * Create event listener for call lifecycle events
     */
    private fun createCallEventListener(channelId: String, callName: String): AgoraService.AgoraEventListener {
        return object : AgoraService.AgoraEventListener {
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                AppLogger.i(TAG, "✅ Call joined successfully: $channel")
                callStatePersistence.markCallAsJoined(channelId)
                
                // Trigger call UI for regular calls with actual mute state
                val isMuted = AgoraServiceManager.getAgoraService()?.isMicrophoneMuted() ?: true
                CallUITrigger.showCallUI(callName, null, isMuted)
                
                // Legacy call flow - no active call notification
                AppLogger.i(TAG, "⚠️  Legacy call event - consider using walkie-talkie flow")
            }
            
            override fun onLeaveChannel() {
                AppLogger.i(TAG, "📴 Left call: $channelId")
                
                // Dismiss call UI
                CallUITrigger.dismissCallUI()
                
                // Full cleanup on leave
                callStatePersistence.clearCallData()
                notificationManager.clearWalkieTalkieNotifications()
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                AppLogger.i(TAG, "👤 User joined: $uid")
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                AppLogger.i(TAG, "👋 User left: $uid")
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                AppLogger.d(TAG, "🎤 Mic toggled: $isMuted")
            }
            
            override fun onSpeakerToggled(isEnabled: Boolean) {
                AppLogger.d(TAG, "🔊 Speaker toggled: $isEnabled")
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                AppLogger.e(TAG, "❌ Call error: $errorCode - $errorMessage")
            }
            
            override fun onAllUsersLeft() {
                AppLogger.i(TAG, "👥 All users left - ending call")
                callStatePersistence.markCallAsEnding(channelId)
                // Clear after brief delay
                callStatePersistence.clearCallData()
                notificationManager.clearWalkieTalkieNotifications()
            }
            
            override fun onChannelEmpty() {
                AppLogger.i(TAG, "🏠 Channel empty")
            }
            
            override fun onUserSpeaking(uid: Int, volume: Int, isSpeaking: Boolean) {
                AppLogger.d(TAG, "🎤 CallLifecycle: User $uid speaking: $isSpeaking (volume: $volume) in regular call")
                // Regular calls don't need speaking notifications like walkie-talkie
            }
        }
    }
    
    /**
     * Data class for call status information
     */
    data class CallStatus(
        val callData: CallData?,
        val state: CallStatePersistenceManager.CallState,
        val isActive: Boolean,
        val duration: Long
    )
    
    /**
     * Handle walkie-talkie channel - Auto-join without notifications
     */
    fun handleWalkieTalkieChannel(
        channelData: CallData,
        shouldAutoJoin: Boolean = true
    ): Boolean {
        try {
            AppLogger.i(TAG, "📻 Handling walkie-talkie channel: ${channelData.callName}")
            
            // 1. Persist the channel data
            callStatePersistence.saveIncomingCallData(channelData)
            
            // 2. Auto-join walkie-talkie channel (no incoming call notification)
            if (shouldAutoJoin) {
                return joinWalkieTalkieChannel(channelData)
            }
            
            return true
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error handling walkie-talkie channel", e)
            return false
        }
    }

    /**
     * Join walkie-talkie channel with appropriate notifications
     */
    fun joinWalkieTalkieChannel(channelData: CallData): Boolean {
        try {
            AppLogger.i(TAG, "📻 Auto-joining walkie-talkie channel: ${channelData.channelId}")
            
            // 🔊 VOLUME ACQUIRE: Set volume to 100% when manually joining walkie-talkie
            volumeAcquireManager.acquireMaximumVolume(
                mode = VolumeAcquireManager.Companion.VolumeAcquireMode.MEDIA_AND_VOICE_CALL
            )
            
            val volumeInfo = volumeAcquireManager.getCurrentVolumeInfo()
            AppLogger.i(TAG, "🔊 Volume acquired for manual walkie-talkie join - $volumeInfo")
            
            // 1. Mark as joining
            callStatePersistence.markCallAsJoining(channelData.channelId)
            
            // 2. Attempt to join
            val joined = agoraCallManager.joinCallOptimized(
                token = channelData.token,
                uid = channelData.uid,
                channelId = channelData.channelId,
                eventListener = createWalkieTalkieEventListener(channelData.channelId, channelData.callName)
            )
            
            if (joined) {
                // 3. Mark as successfully joined
                callStatePersistence.markCallAsJoined(channelData.channelId)
                
                AppLogger.i(TAG, "✅ Successfully joined walkie-talkie channel: ${channelData.channelId}")
                return true
            } else {
                AppLogger.e(TAG, "❌ Failed to join walkie-talkie channel: ${channelData.channelId}")
                return false
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error joining walkie-talkie channel", e)
            return false
        }
    }

    /**
     * Create event listener for walkie-talkie lifecycle events
     */
    private fun createWalkieTalkieEventListener(channelId: String, channelName: String): AgoraService.AgoraEventListener {
        return object : AgoraService.AgoraEventListener {
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                AppLogger.i(TAG, "✅ Walkie-talkie channel joined: $channel")
                callStatePersistence.markCallAsJoined(channelId)
                
                // Trigger call UI for walkie-talkie calls with actual mute state and photo
                val isMuted = AgoraServiceManager.getAgoraService()?.isMicrophoneMuted() ?: true
                val callerPhoto = callStatePersistence.getCurrentCallData()?.callerPhoto
                CallUITrigger.showCallUI(channelName, callerPhoto, isMuted)
                
                // No notification on join for walkie-talkie
            }
            
            override fun onLeaveChannel() {
                AppLogger.i(TAG, "📻 Left walkie-talkie channel: $channelId")
                
                // Dismiss call UI
                CallUITrigger.dismissCallUI()
                
                // Don't show disconnection notification for self leaving
                // Clean up state
                callStatePersistence.clearCallData()
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                AppLogger.i(TAG, "👤 User joined walkie-talkie: $uid")
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                AppLogger.i(TAG, "👋 User left walkie-talkie: $uid")
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                AppLogger.d(TAG, "🎤 Walkie-talkie mic toggled: $isMuted")
                // Don't show speaking notifications for self
                // These should be handled by other users receiving the audio events
            }
            
            override fun onSpeakerToggled(isEnabled: Boolean) {
                AppLogger.d(TAG, "🔊 Speaker toggled in walkie-talkie: $isEnabled")
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                AppLogger.e(TAG, "❌ Walkie-talkie error: $errorCode - $errorMessage")
            }
            
            override fun onAllUsersLeft() {
                AppLogger.i(TAG, "👥 All users left walkie-talkie")
                // Don't show notification when all users leave
                callStatePersistence.clearCallData()
            }
            
            override fun onChannelEmpty() {
                AppLogger.i(TAG, "🏠 Walkie-talkie channel empty")
            }
            
            override fun onUserSpeaking(uid: Int, volume: Int, isSpeaking: Boolean) {
                AppLogger.d(TAG, "🎤 CallLifecycle: User $uid speaking: $isSpeaking (volume: $volume)")
                // CallLifecycleManager doesn't handle notifications - that's done by WalkieTalkieService
                // Just log for debugging purposes
            }
        }
    }
}
