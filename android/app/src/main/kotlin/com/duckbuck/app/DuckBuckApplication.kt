package com.duckbuck.app

import android.app.Application
import android.util.Log
import com.duckbuck.app.agora.AgoraService

/**
 * Main Application class for DuckBuck
 * Initializes critical components like Agora at the earliest possible point
 */
class DuckBuckApplication : Application() {
    
    companion object {
        private const val TAG = "DuckBuckApplication"
    }
    
    private lateinit var agoraService: AgoraService
    
    override fun onCreate() {
        super.onCreate()
        
        Log.i(TAG, "🚀 DuckBuck Application created - initializing core services")
        
        // Initialize Agora as early as possible during app startup
        initializeAgoraService()
    }
    
    private fun initializeAgoraService() {
        try {
            agoraService = AgoraService(this)
            val success = agoraService.initializeEngine()
            
            if (success) {
                Log.i(TAG, "✅ Agora Engine initialized successfully during application startup")
                
                // Verify that it's truly initialized
                if (agoraService.isEngineInitialized()) {
                    Log.i(TAG, "✅ Agora Engine verified as fully initialized and ready for calls")
                } else {
                    Log.w(TAG, "⚠️ Agora Engine initialization succeeded but verification failed. Retrying...")
                    
                    // Try one more initialization attempt with longer delay
                    val retrySuccess = agoraService.initializeEngine()
                    if (retrySuccess && agoraService.isEngineInitialized()) {
                        Log.i(TAG, "✅ Agora Engine successfully initialized on retry attempt")
                    } else {
                        Log.e(TAG, "❌ Agora Engine failed verification even after retry")
                    }
                }
                
                // Store reference in singleton for global access
                AgoraServiceHolder.setAgoraService(agoraService)
            } else {
                Log.e(TAG, "❌ Failed to initialize Agora Engine during application startup")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception initializing Agora Engine in Application", e)
        }
    }
    
    override fun onTerminate() {
        super.onTerminate()
        
        // Cleanup Agora engine
        if (::agoraService.isInitialized) {
            try {
                agoraService.destroy()
                AgoraServiceHolder.clear()
                Log.i(TAG, "🧹 Cleaned up Agora Engine on application terminate")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clean up Agora Engine", e)
            }
        }
    }
}
