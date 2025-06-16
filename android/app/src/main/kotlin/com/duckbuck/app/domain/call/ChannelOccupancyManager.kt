package com.duckbuck.app.domain.call

import android.os.Handler
import android.os.Looper
import com.duckbuck.app.data.agora.AgoraService
import com.duckbuck.app.data.agora.AgoraServiceManager
import com.duckbuck.app.infrastructure.monitoring.AppLogger

/**
 * Manages channel occupancy checks for walkie-talkie functionality.
 * Ensures receivers only show notification/UI if the initiator is present.
 */
class ChannelOccupancyManager {
    
    companion object {
        private const val TAG = "ChannelOccupancyManager"
        private const val DISCOVERY_DELAY_MS = 800L
        private const val TIMEOUT_MS = 10000L
    }
    
    private var isCleanedUp = false

    /**
     * Check walkie-talkie channel occupancy specifically for receiver logic.
     * For walkie-talkie (PTT), receivers should show notification immediately since
     * FCM means someone WAS speaking, but should leave silently if channel becomes empty.
     */
    fun checkWalkieTalkieOccupancy(
        channelId: String,
        isInitiator: Boolean,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        if (isCleanedUp) {
            AppLogger.w(TAG, "🧹 ChannelOccupancyManager is cleaned up, ignoring occupancy check")
            return
        }
        
        AppLogger.i(TAG, "🔍 Receiver: Checking walkie-talkie occupancy for channel: $channelId")
        
        // Safety timeout - if occupancy check doesn't complete within 3 seconds, assume empty
        val timeoutHandler = Handler(Looper.getMainLooper())
        val timeoutRunnable = Runnable {
            AppLogger.w(TAG, "⏰ Occupancy check timeout for $channelId - assuming empty channel")
            onChannelEmpty()
        }
        timeoutHandler.postDelayed(timeoutRunnable, 3000) // 3 second timeout
        
        // Add a shorter delay to allow channel state to synchronize, but not too long
        // to prevent showing notifications for empty channels
        Handler(Looper.getMainLooper()).postDelayed({
            // Remove timeout since we're proceeding with the check
            timeoutHandler.removeCallbacks(timeoutRunnable)
            performWalkieTalkieOccupancyCheck(channelId, isInitiator, onChannelOccupied, onChannelEmpty)
        }, 500) // Reduced to 500ms for faster empty channel detection
    }
    
    /**
     * Quick join method for recovery scenarios - used by AppStateManager
     */
    fun checkOccupancyWithQuickJoin(
        channelId: String,
        token: String,
        uid: Int,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        if (isCleanedUp) {
            AppLogger.w(TAG, "🧹 ChannelOccupancyManager is cleaned up, ignoring quick join check")
            return
        }
        
        AppLogger.i(TAG, "🔍 Starting quick occupancy check for recovery: $channelId")
        
        val agoraService = AgoraServiceManager.getAgoraService()
        if (agoraService == null) {
            AppLogger.e(TAG, "❌ AgoraService not available for quick join check")
            onChannelEmpty()
            return
        }
        
        // Store original event listener to restore later
        val originalListener = agoraService.getEventListener()
        AppLogger.d(TAG, "📡 Stored original event listener: ${originalListener?.javaClass?.simpleName}")
        
        // Create temporary event listener for this quick check
        val tempListener = createQuickJoinListener(channelId, onChannelOccupied, onChannelEmpty, originalListener)
        
        try {
            // Set temporary listener and join for quick check
            agoraService.setEventListener(tempListener)
            agoraService.joinChannel(token, channelId, uid)
            
            // Timeout safety mechanism
            Handler(Looper.getMainLooper()).postDelayed({
                AppLogger.w(TAG, "⏰ Quick join timeout for $channelId")
                restoreOriginalListener(agoraService, originalListener)
                onChannelEmpty()
            }, TIMEOUT_MS)
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "💥 Exception during quick occupancy check", e)
            restoreOriginalListener(agoraService, originalListener)
            onChannelEmpty()
        }
    }
    
    private fun performWalkieTalkieOccupancyCheck(
        channelId: String,
        isInitiator: Boolean,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        AppLogger.i(TAG, "🔍 Performing walkie-talkie occupancy check for channel: $channelId (initiator: $isInitiator)")
        
        val agoraService = AgoraServiceManager.getAgoraService()
        if (agoraService == null) {
            AppLogger.e(TAG, "❌ AgoraService not available for occupancy check")
            onChannelEmpty()
            return
        }
        
        try {
            val userCount = agoraService.getRemoteUserCount()
            val hasOthers = userCount > 0
            
            AppLogger.i(TAG, "👥 Walkie-talkie occupancy: $userCount remote users, hasOthers: $hasOthers")
            
            if (isInitiator) {
                // Initiator always shows UI regardless of occupancy
                AppLogger.i(TAG, "🎤 Initiator: Always showing UI regardless of occupancy")
                onChannelOccupied(userCount)
            } else {
                // Receiver logic: only show UI if there are other users (initiator present)
                if (hasOthers) {
                    AppLogger.i(TAG, "✅ Receiver: Other users present ($userCount) - showing notification/UI")
                    onChannelOccupied(userCount)
                } else {
                    // Double-check after a brief moment to avoid false negatives due to network delays
                    AppLogger.i(TAG, "🔍 Receiver: Initial check shows empty channel, double-checking in 200ms...")
                    Handler(Looper.getMainLooper()).postDelayed({
                        val finalUserCount = agoraService.getRemoteUserCount()
                        if (finalUserCount > 0) {
                            AppLogger.i(TAG, "✅ Receiver: Double-check found users ($finalUserCount) - showing notification/UI")
                            onChannelOccupied(finalUserCount)
                        } else {
                            AppLogger.i(TAG, "🏃‍♂️ Receiver: Double-check confirms empty channel - leaving silently without notification/UI")
                            onChannelEmpty()
                        }
                    }, 200) // Brief 200ms double-check
                }
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "💥 Error during walkie-talkie occupancy check", e)
            // On error, assume empty to be safe
            onChannelEmpty()
        }
    }
    
    private fun createQuickJoinListener(
        channelId: String,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit,
        originalListener: AgoraService.AgoraEventListener?
    ): AgoraService.AgoraEventListener {
        
        return object : AgoraService.AgoraEventListener {
            private var hasJoined = false
            private var timeoutHandler: Handler? = null
            
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                if (!hasJoined && channel == channelId) {
                    hasJoined = true
                    AppLogger.d(TAG, "✅ Quick join successful for $channel")
                    
                    // Allow brief time for user discovery
                    timeoutHandler = Handler(Looper.getMainLooper()).apply {
                        postDelayed({
                            performQuickOccupancyCheck(channelId, onChannelOccupied, onChannelEmpty, originalListener)
                        }, DISCOVERY_DELAY_MS)
                    }
                }
            }
            
            override fun onLeaveChannel() {
                AppLogger.d(TAG, "🚪 Left channel during quick check")
                val agoraService = AgoraServiceManager.getAgoraService()
                if (agoraService != null) {
                    restoreOriginalListener(agoraService, originalListener)
                }
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                AppLogger.d(TAG, "👤 User joined during quick check: $uid")
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                AppLogger.d(TAG, "👤 User left during quick check: $uid (reason: $reason)")
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                // Not used in quick check
            }
            
            override fun onSpeakerToggled(isEnabled: Boolean) {
                // Not used in quick check
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                AppLogger.e(TAG, "❌ Agora error during quick check: $errorCode - $errorMessage")
                val agoraService = AgoraServiceManager.getAgoraService()
                if (agoraService != null) {
                    restoreOriginalListener(agoraService, originalListener)
                }
                onChannelEmpty()
            }
        }
    }
    
    private fun performQuickOccupancyCheck(
        channelId: String,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit,
        originalListener: AgoraService.AgoraEventListener?
    ) {
        val agoraService = AgoraServiceManager.getAgoraService()
        if (agoraService == null) {
            AppLogger.e(TAG, "❌ AgoraService not available for quick occupancy check")
            onChannelEmpty()
            return
        }
        
        try {
            val userCount = agoraService.getRemoteUserCount()
            AppLogger.d(TAG, "👥 Channel $channelId user count: $userCount")
            
            // Leave the channel after checking
            agoraService.leaveChannel()
            
            // Restore original listener
            restoreOriginalListener(agoraService, originalListener)
            
            // Report results
            if (userCount > 0) {
                AppLogger.d(TAG, "✅ Channel occupied with $userCount users")
                onChannelOccupied(userCount)
            } else {
                AppLogger.d(TAG, "🏃‍♂️ Channel is empty")
                onChannelEmpty()
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "💥 Error during quick occupancy check", e)
            agoraService.leaveChannel() // Ensure we leave
            restoreOriginalListener(agoraService, originalListener)
            onChannelEmpty()
        }
    }
    
    private fun restoreOriginalListener(
        agoraService: AgoraService,
        originalListener: AgoraService.AgoraEventListener?
    ) {
        try {
            if (originalListener != null) {
                agoraService.setEventListener(originalListener)
                AppLogger.d(TAG, "🔄 Restored original event listener: ${originalListener.javaClass.simpleName}")
            } else {
                AppLogger.d(TAG, "📡 No original listener to restore")
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "💥 Failed to restore original listener", e)
        }
    }
    
    /**
     * Cleanup resources
     */
    fun cleanup() {
        AppLogger.d(TAG, "🧹 ChannelOccupancyManager cleaning up")
        isCleanedUp = true
    }
}
