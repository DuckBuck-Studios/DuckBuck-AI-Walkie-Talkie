package com.duckbuck.app.data.agora
import com.duckbuck.app.infrastructure.monitoring.AppLogger

import com.duckbuck.app.data.agora.AgoraService

/**
 * Centralized Agora Service Manager that replaces AgoraServiceHolder
 * Provides thread-safe access to the shared AgoraService instance
 * with better lifecycle management
 */
object AgoraServiceManager {
    private const val TAG = "AgoraServiceManager"
    
    @Volatile
    private var agoraService: AgoraService? = null
    private val lock = Any()
    
    /**
     * Set the shared AgoraService instance
     * @param service The AgoraService instance to store
     */
    @Synchronized
    fun setAgoraService(service: AgoraService) {
        synchronized(lock) {
            agoraService = service
            AppLogger.d(TAG, "AgoraService instance set in manager")
        }
    }
    
    /**
     * Get the shared AgoraService instance
     * @return AgoraService instance or null if not available
     */
    @Synchronized
    fun getAgoraService(): AgoraService? {
        synchronized(lock) {
            return agoraService
        }
    }
    
    /**
     * Get AgoraService with validation
     * @return AgoraService if available and properly initialized, null otherwise
     */
    @Synchronized
    fun getValidatedAgoraService(): AgoraService? {
        synchronized(lock) {
            val service = agoraService
            return if (service != null && service.isEngineInitialized()) {
                service
            } else {
                if (service != null && !service.isEngineInitialized()) {
                    AppLogger.w(TAG, "AgoraService exists but engine is not initialized")
                }
                null
            }
        }
    }
    
    /**
     * Check if AgoraService is available and properly initialized
     * @return true if service is ready for use
     */
    @Synchronized
    fun isServiceReady(): Boolean {
        synchronized(lock) {
            val service = agoraService
            return service != null && service.isEngineInitialized()
        }
    }
    
    /**
     * Clear the AgoraService instance (should be called on cleanup)
     */
    @Synchronized
    fun clear() {
        synchronized(lock) {
            agoraService = null
            AppLogger.d(TAG, "AgoraService instance cleared from manager")
        }
    }
    
    /**
     * Destroy the current service and clear reference
     * Use with caution - only during app termination
     */
    @Synchronized
    fun destroyAndClear() {
        synchronized(lock) {
            try {
                agoraService?.destroy()
                AppLogger.d(TAG, "AgoraService destroyed successfully")
            } catch (e: Exception) {
                AppLogger.e(TAG, "Error destroying AgoraService", e)
            } finally {
                agoraService = null
                AppLogger.d(TAG, "AgoraService instance cleared after destruction")
            }
        }
    }
    
    /**
     * Leave the channel and clean up resources
     * This ensures that all resources are released and the service is stopped
     */
    @Synchronized
    fun leaveChannelAndCleanup(context: android.content.Context): Boolean {
        return try {
            AppLogger.i(TAG, "🚪 Leaving channel and cleaning up resources...")
            
            // Leave the channel gracefully
            val leaveResult = agoraService?.leaveChannel() ?: false
            AppLogger.i(TAG, "Leave channel result: $leaveResult")
            
            // Stop the WalkieTalkieService if it's running
            val stopIntent = android.content.Intent(context, com.duckbuck.app.presentation.services.WalkieTalkieService::class.java).apply {
                putExtra("action", "stop_service")
            }
            context.startService(stopIntent)
            AppLogger.i(TAG, "✅ Sent stop service intent to WalkieTalkieService")
            
            // Return the result of the leave operation
            leaveResult
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error leaving channel and cleaning up", e)
            false
        }
    }
}
