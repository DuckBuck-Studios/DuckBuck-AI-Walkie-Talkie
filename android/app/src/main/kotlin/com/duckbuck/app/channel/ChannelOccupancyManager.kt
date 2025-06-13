package com.duckbuck.app.channel

import android.os.Handler
import android.os.Looper
import com.duckbuck.app.agora.AgoraService
import com.duckbuck.app.core.AppLogger
import com.duckbuck.app.core.AgoraServiceManager

/**
 * Channel Occupancy Manager - Manages channel occupancy detection with brief discovery period
 * 
 * This manager provides:
 * - Channel occupancy detection with minimal delay for user discovery
 * - Auto-leave when channel is empty
 * - Prevents unnecessary notifications and UI triggers for empty channels
 */
class ChannelOccupancyManager {
    
    companion object {
        private const val TAG = "ChannelOccupancyManager"
        // Short delay to allow Agora SDK to discover existing users
        private const val USER_DISCOVERY_DELAY_MS = 800L
    }
    
    private val handler = Handler(Looper.getMainLooper())
    
    /**
     * Check channel occupancy after a brief delay for user discovery
     * This allows Agora SDK time to discover existing users via onUserJoined callbacks
     * 
     * @param channelId The channel ID that was joined
     * @param onChannelOccupied Callback when channel has other users
     * @param onChannelEmpty Callback when channel is empty (should leave)
     */
    fun checkOccupancyAfterDiscovery(
        channelId: String,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        try {
            AppLogger.i(TAG, "🔍 Starting occupancy check with ${USER_DISCOVERY_DELAY_MS}ms discovery delay for channel: $channelId")
            
            // Give Agora SDK brief time to discover existing users
            handler.postDelayed({
                performOccupancyCheck(channelId, onChannelOccupied, onChannelEmpty)
            }, USER_DISCOVERY_DELAY_MS)
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error during occupancy check setup", e)
            onChannelEmpty()
        }
    }
    
    /**
     * Check channel occupancy immediately (for testing/special cases)
     * Note: This may not detect users who haven't been discovered by Agora yet
     */
    fun checkOccupancyImmediately(
        channelId: String,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        AppLogger.i(TAG, "⚡ Checking occupancy immediately for channel: $channelId")
        performOccupancyCheck(channelId, onChannelOccupied, onChannelEmpty)
    }
    
    /**
     * Perform the actual occupancy check
     */
    private fun performOccupancyCheck(
        channelId: String,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        try {
            AppLogger.i(TAG, "🔍 Performing occupancy check for channel: $channelId")
            
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            
            if (agoraService == null) {
                AppLogger.e(TAG, "❌ AgoraService not available for occupancy check")
                onChannelEmpty()
                return
            }
            
            if (!agoraService.isChannelJoined()) {
                AppLogger.w(TAG, "⚠️ Not joined to channel, treating as empty")
                onChannelEmpty()
                return
            }
            
            val remoteUserCount = agoraService.getRemoteUserCount()
            val hasOtherUsers = agoraService.hasOtherUsers()
            
            AppLogger.i(TAG, "👥 Channel occupancy: $remoteUserCount remote users, hasOthers: $hasOtherUsers")
            
            if (hasOtherUsers && remoteUserCount > 0) {
                // Channel has other users - proceed with normal flow
                AppLogger.i(TAG, "✅ Channel has $remoteUserCount users - proceeding with normal flow")
                onChannelOccupied(remoteUserCount)
            } else {
                // Channel is empty - leave immediately
                AppLogger.i(TAG, "🏃‍♂️ Channel is empty - triggering immediate auto-leave")
                onChannelEmpty()
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error during occupancy check", e)
            onChannelEmpty()
        }
    }
    
    /**
     * Check if channel is currently occupied (immediate check)
     */
    fun isChannelCurrentlyOccupied(): Boolean {
        return try {
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val hasUsers = agoraService?.hasOtherUsers() ?: false
            AppLogger.d(TAG, "🔍 Immediate occupancy check: $hasUsers")
            hasUsers
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error checking immediate occupancy", e)
            false
        }
    }
    
    /**
     * Get current user count in channel
     */
    fun getCurrentUserCount(): Int {
        return try {
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            val count = agoraService?.getRemoteUserCount() ?: 0
            AppLogger.d(TAG, "👥 Current user count: $count")
            count
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error getting user count", e)
            0
        }
    }
    
    /**
     * Check channel occupancy with a quick join-check-leave approach for recovery scenarios
     * Used when app resumes and finds stale call data to determine if channel should be rejoined
     * 
     * @param channelId Channel to check
     * @param token Agora token for temporary join
     * @param uid User ID for temporary join  
     * @param onChannelOccupied Callback when channel has users (should rejoin)
     * @param onChannelEmpty Callback when channel is empty (should clear data)
     */
    fun checkOccupancyWithQuickJoin(
        channelId: String,
        token: String,
        uid: Int,
        onChannelOccupied: (userCount: Int) -> Unit,
        onChannelEmpty: () -> Unit
    ) {
        try {
            AppLogger.i(TAG, "🔍 Quick occupancy check for recovery - channel: $channelId")
            
            val agoraService = AgoraServiceManager.getValidatedAgoraService()
            if (agoraService == null) {
                AppLogger.w(TAG, "⚠️ No Agora service available for quick check, treating as empty")
                onChannelEmpty()
                return
            }
            
            // Store original event listener to restore after quick check
            val originalListener = agoraService.getEventListener()
            AppLogger.d(TAG, "🔄 Stored original event listener: ${if (originalListener != null) "present" else "none"}")
            
            // Create a temporary event listener for quick check
            val tempListener = object : AgoraService.AgoraEventListener {
                override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                    AppLogger.d(TAG, "🔍 Quick join successful, checking users after discovery delay")
                    
                    // Allow brief time for user discovery, then check occupancy
                    handler.postDelayed({
                        val userCount = agoraService.getRemoteUserCount()
                        AppLogger.i(TAG, "👥 Quick check found $userCount users in channel")
                        
                        // Leave immediately after check
                        agoraService.leaveChannel()
                        
                        if (userCount > 0) {
                            onChannelOccupied(userCount)
                        } else {
                            onChannelEmpty()
                        }
                    }, 500) // Shorter delay for quick check
                }
                
                override fun onLeaveChannel() {
                    AppLogger.d(TAG, "🔍 Quick check completed, restoring original event listener")
                    
                    // Restore original event listener after leaving
                    if (originalListener != null) {
                        agoraService.setEventListener(originalListener)
                        AppLogger.d(TAG, "✅ Original event listener restored")
                    } else {
                        agoraService.removeEventListener()
                        AppLogger.d(TAG, "✅ No original listener to restore, cleared listener")
                    }
                }
                
                override fun onUserJoined(uid: Int, elapsed: Int) {}
                override fun onUserOffline(uid: Int, reason: Int) {}
                override fun onMicrophoneToggled(isMuted: Boolean) {}
                override fun onSpeakerToggled(isEnabled: Boolean) {}
                override fun onError(errorCode: Int, errorMessage: String) {
                    AppLogger.e(TAG, "❌ Quick check error: $errorMessage, treating as empty")
                    
                    // Restore original listener even on error
                    if (originalListener != null) {
                        agoraService.setEventListener(originalListener)
                        AppLogger.d(TAG, "✅ Original event listener restored after error")
                    } else {
                        agoraService.removeEventListener()
                        AppLogger.d(TAG, "✅ No original listener to restore after error, cleared listener")
                    }
                    
                    onChannelEmpty()
                }
            }
            
            // Set temporary listener and join
            agoraService.setEventListener(tempListener)
            val joinResult = agoraService.joinChannel(channelId, token, uid)
            
            if (!joinResult) {
                AppLogger.w(TAG, "⚠️ Quick join failed, treating channel as empty")
                
                // Restore original listener if join failed
                if (originalListener != null) {
                    agoraService.setEventListener(originalListener)
                    AppLogger.d(TAG, "✅ Original event listener restored after join failure")
                } else {
                    agoraService.removeEventListener()
                    AppLogger.d(TAG, "✅ No original listener to restore after join failure, cleared listener")
                }
                
                onChannelEmpty()
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error during quick occupancy check", e)
            
            // Try to clean up any potential listener state issues on exception
            try {
                val agoraService = AgoraServiceManager.getValidatedAgoraService()
                agoraService?.removeEventListener()
                AppLogger.d(TAG, "🧹 Cleared listener state after exception")
            } catch (cleanupException: Exception) {
                AppLogger.e(TAG, "❌ Error during cleanup after exception", cleanupException)
            }
            
            onChannelEmpty()
        }
    }
    
    /**
     * Clean up resources
     */
    fun cleanup() {
        AppLogger.d(TAG, "🧹 ChannelOccupancyManager cleaning up")
        handler.removeCallbacksAndMessages(null)
    }
}
