package com.duckbuck.app.data.agora
import com.duckbuck.app.infrastructure.monitoring.AppLogger

import android.content.Context
import com.duckbuck.app.data.agora.AgoraService

/**
 * Core module responsible for Agora Engine initialization
 * Handles initialization logic with retries and validation
 */
object AgoraEngineInitializer {
    private const val TAG = "AgoraEngineInitializer"

    /**
     * Initialize Agora service with comprehensive validation and retry logic
     * @param context Application or Activity context
     * @param existingService Optional existing service instance to validate
     * @return Pair<Boolean, AgoraService?> - success status and service instance
     */
    fun initializeAgoraService(
        context: Context,
        existingService: AgoraService? = null
    ): Pair<Boolean, AgoraService?> {
        try {
            // First check if existing service is valid and initialized
            if (existingService != null && existingService.isEngineInitialized()) {
                AppLogger.i(TAG, "✅ Using existing initialized Agora Engine")
                return Pair(true, existingService)
            }

            // Create new service if needed
            val agoraService = AgoraService(context)
            val success = agoraService.initializeEngine()

            if (success) {
                AppLogger.i(TAG, "✅ Agora Engine initialized successfully")

                // Verify initialization
                if (agoraService.isEngineInitialized()) {
                    AppLogger.i(TAG, "✅ Agora Engine verification successful")
                    return Pair(true, agoraService)
                } else {
                    AppLogger.w(TAG, "⚠️ Agora Engine initialization succeeded but verification failed. Retrying...")
                    
                    // Retry with cleanup
                    return retryInitialization(context, agoraService)
                }
            } else {
                AppLogger.e(TAG, "❌ Failed to initialize Agora Engine")
                return Pair(false, null)
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Exception initializing Agora Engine", e)
            return Pair(false, null)
        }
    }

    /**
     * Retry initialization with cleanup
     */
    private fun retryInitialization(
        context: Context,
        agoraService: AgoraService
    ): Pair<Boolean, AgoraService?> {
        try {
            // Clean up previous attempt
            agoraService.destroy()
            
            // Create fresh service
            val newService = AgoraService(context)
            val retrySuccess = newService.initializeEngine()

            if (!retrySuccess || !newService.isEngineInitialized()) {
                AppLogger.e(TAG, "❌ Agora Engine failed to initialize even after retry")
                return Pair(false, null)
            }

            AppLogger.i(TAG, "✅ Agora Engine initialized successfully on retry attempt")
            return Pair(true, newService)
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Exception during retry initialization", e)
            return Pair(false, null)
        }
    }
}
