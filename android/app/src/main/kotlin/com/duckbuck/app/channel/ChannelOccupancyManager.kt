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
     * Clean up resources
     */
    fun cleanup() {
        AppLogger.d(TAG, "🧹 ChannelOccupancyManager cleaning up")
        handler.removeCallbacksAndMessages(null)
    }
}
