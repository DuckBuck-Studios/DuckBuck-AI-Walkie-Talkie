package com.duckbuck.app.agora
import com.duckbuck.app.core.AppLogger

import android.content.Context
import com.duckbuck.app.core.AgoraServiceManager
import com.duckbuck.app.core.AgoraEngineInitializer

/**
 * Agora Call Manager responsible for managing call joining logic
 * Handles fast joining, engine validation, and retry mechanisms
 */
class AgoraCallManager(private val context: Context) {
    
    companion object {
        private const val TAG = "AgoraCallManager"
    }
    
    /**
     * Join a call with optimized speed and reliability
     * @param token Agora token for authentication
     * @param uid User ID for the call
     * @param channelId Channel to join
     * @param eventListener Optional event listener for call events
     * @return true if successfully joined, false otherwise
     */
    fun joinCallOptimized(
        token: String,
        uid: Int,
        channelId: String,
        eventListener: AgoraService.AgoraEventListener? = null
    ): Boolean {
        try {
            AppLogger.i(TAG, "🔗 OPTIMIZED JOIN: Joining channel: $channelId with UID: $uid")
            
            // Get or create Agora service
            val agoraService = getOrCreateAgoraService(eventListener)
            
            if (agoraService == null) {
                AppLogger.e(TAG, "❌ OPTIMIZED JOIN: Failed to obtain AgoraService instance")
                return false
            }
            
            // Ensure RTC engine is initialized
            if (!ensureEngineInitialized(agoraService)) {
                AppLogger.e(TAG, "❌ OPTIMIZED JOIN: RTC Engine not properly initialized")
                return false
            }
            
            // Mute microphone before joining (as per original logic)
            agoraService.turnMicrophoneOff()
            
            // Join the channel
            val joinResult = agoraService.joinChannel(channelId, token, uid)
            
            if (joinResult) {
                AppLogger.i(TAG, "✅ OPTIMIZED JOIN: Successfully joined channel: $channelId (UID: $uid)")
                return true
            } else {
                AppLogger.e(TAG, "❌ OPTIMIZED JOIN: Failed to join channel: $channelId")
                return false
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ OPTIMIZED JOIN: Exception during call join", e)
            return false
        }
    }
    
    /**
     * Get existing service or create new one with proper initialization
     */
    private fun getOrCreateAgoraService(eventListener: AgoraService.AgoraEventListener?): AgoraService? {
        // Try to get existing validated service
        var agoraService = AgoraServiceManager.getValidatedAgoraService()
        
        if (agoraService != null) {
            AppLogger.i(TAG, "✅ OPTIMIZED JOIN: Using existing validated AgoraService")
            val validService = agoraService
            eventListener?.let { validService.setEventListener(it) }
            return validService
        }
        
        // Check if service exists but not initialized
        agoraService = AgoraServiceManager.getAgoraService()
        if (agoraService != null) {
            AppLogger.w(TAG, "⚠️ OPTIMIZED JOIN: Service exists but not initialized, checking holder")
        }
        
        AppLogger.w(TAG, "⚠️ OPTIMIZED JOIN: No valid service found, creating new instance")
        
        // Create new service using initializer
        val (success, newService) = AgoraEngineInitializer.initializeAgoraService(context)
        
        if (success && newService != null) {
            AppLogger.i(TAG, "✅ OPTIMIZED JOIN: Created new AgoraService successfully")
            eventListener?.let { newService.setEventListener(it) }
            AgoraServiceManager.setAgoraService(newService)
            return newService
        }
        
        AppLogger.e(TAG, "❌ OPTIMIZED JOIN: Failed to create new AgoraService")
        return null
    }
    
    /**
     * Ensure the engine is properly initialized with retry logic
     */
    private fun ensureEngineInitialized(agoraService: AgoraService): Boolean {
        if (agoraService.isEngineInitialized()) {
            return true
        }
        
        AppLogger.w(TAG, "⚠️ OPTIMIZED JOIN: Engine not initialized, attempting re-initialization")
        
        // Try to re-initialize
        val initResult = agoraService.initializeEngine()
        if (initResult && agoraService.isEngineInitialized()) {
            AppLogger.i(TAG, "✅ OPTIMIZED JOIN: Engine re-initialized successfully")
            
            // Give engine time to fully initialize
            try {
                Thread.sleep(300)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            
            return true
        }
        
        AppLogger.e(TAG, "❌ OPTIMIZED JOIN: Failed to re-initialize engine")
        return false
    }
    
    /**
     * Leave current call and cleanup
     * @param reason Reason for leaving the call
     * @return true if successfully left
     */
    fun leaveCall(reason: String): Boolean {
        try {
            val agoraService = AgoraServiceManager.getAgoraService()
            if (agoraService != null) {
                AppLogger.i(TAG, "📱 LEAVE CALL: Leaving channel - $reason")
                return agoraService.leaveChannel()
            } else {
                AppLogger.w(TAG, "📱 LEAVE CALL: No AgoraService available for leaving")
                return true // Consider it successful if no service exists
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ LEAVE CALL: Exception during leave", e)
            return false
        }
    }
}
