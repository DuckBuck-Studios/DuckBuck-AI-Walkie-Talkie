package com.duckbuck.app

import android.app.Application
import android.util.Log
import com.duckbuck.app.core.AgoraEngineInitializer
import com.duckbuck.app.core.AgoraServiceManager

/**
 * Main Application class for DuckBuck
 * Initializes critical components like Agora at the earliest possible point
 * Now uses modularized initialization system
 */
class DuckBuckApplication : Application() {
    
    companion object {
        private const val TAG = "DuckBuckApplication"
    }
    
    override fun onCreate() {
        super.onCreate()
        
        Log.i(TAG, "🚀 DuckBuck Application created - initializing core services")
        
        // Initialize Agora using the new modular system
        initializeAgoraService()
    }
    
    private fun initializeAgoraService() {
        try {
            Log.i(TAG, "Initializing Agora service using modular initializer")
            
            // Use the new modular initializer
            val (success, agoraService) = AgoraEngineInitializer.initializeAgoraService(this)
            
            if (success && agoraService != null) {
                Log.i(TAG, "✅ Agora Engine initialized successfully during application startup")
                
                // Store reference in new service manager
                AgoraServiceManager.setAgoraService(agoraService)
                Log.i(TAG, "✅ Agora service stored in service manager")
            } else {
                Log.e(TAG, "❌ Failed to initialize Agora Engine during application startup")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception initializing Agora Engine in Application", e)
        }
    }
    
    override fun onTerminate() {
        super.onTerminate()
        
        Log.i(TAG, "🧹 Application terminating - cleaning up Agora Engine")
        
        // Cleanup using new service manager
        try {
            AgoraServiceManager.destroyAndClear()
            Log.i(TAG, "🧹 Cleaned up Agora Engine on application terminate")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clean up Agora Engine", e)
        }
    }
}
