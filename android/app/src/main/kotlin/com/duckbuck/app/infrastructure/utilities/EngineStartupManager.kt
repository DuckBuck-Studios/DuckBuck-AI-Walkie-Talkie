package com.duckbuck.app.infrastructure.utilities

import android.content.Context
import com.duckbuck.app.infrastructure.monitoring.AppLogger
import com.duckbuck.app.data.agora.AgoraServiceManager
import com.duckbuck.app.data.agora.AgoraEngineInitializer

/**
 * Engine Startup Manager - Handles Agora engine initialization at app startup
 * Extracted from MainActivity for better separation of concerns
 */
class EngineStartupManager(private val context: Context) {
    
    companion object {
        private const val TAG = "EngineStartupManager"
    }
    
    /**
     * Initialize Agora service during app startup
     * Handles validation of existing services and creation of new ones
     */
    fun initializeAgoraService(): Boolean {
        try {
            AppLogger.i(TAG, "Initializing/verifying Agora service at app startup")
            
            // First check if a valid instance exists in the service manager
            val existingService = AgoraServiceManager.getValidatedAgoraService()
            if (existingService != null) {
                AppLogger.i(TAG, "✅ Using existing validated Agora Engine from service manager")
                return true
            }
            
            // Use modular initializer to create or restore service
            val (success, agoraService) = AgoraEngineInitializer.initializeAgoraService(context)
            
            if (success && agoraService != null) {
                AppLogger.i(TAG, "✅ Agora Engine initialized successfully at startup")
                
                // Store reference in service manager
                AgoraServiceManager.setAgoraService(agoraService)
                return true
            } else {
                AppLogger.e(TAG, "❌ Failed to initialize Agora Engine at startup")
                return false
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Exception initializing Agora Engine at startup", e)
            return false
        }
    }
    
    /**
     * Verify engine readiness after initialization
     */
    fun verifyEngineReadiness(): Boolean {
        val service = AgoraServiceManager.getValidatedAgoraService()
        val isReady = service?.isEngineInitialized() ?: false
        
        if (isReady) {
            AppLogger.production(TAG, "ENGINE_STARTUP_SUCCESS", mapOf(
                "hasService" to true,
                "isInitialized" to true
            ))
        } else {
            AppLogger.production(TAG, "ENGINE_STARTUP_FAILED", mapOf(
                "hasService" to (service != null),
                "isInitialized" to false
            ))
        }
        
        return isReady
    }
}
