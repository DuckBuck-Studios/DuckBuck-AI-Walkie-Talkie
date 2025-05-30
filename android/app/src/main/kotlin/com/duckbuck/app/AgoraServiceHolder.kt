package com.duckbuck.app

import android.util.Log
import com.duckbuck.app.agora.AgoraService

/**
 * Singleton to hold the AgoraService instance that can be accessed from
 * multiple components (MainActivity and FCMService)
 */
object AgoraServiceHolder {
    private const val TAG = "AgoraServiceHolder"
    
    private var agoraService: AgoraService? = null
    
    @Synchronized
    fun setAgoraService(service: AgoraService) {
        agoraService = service
        Log.d(TAG, "AgoraService instance set in holder")
    }
    
    @Synchronized
    fun getAgoraService(): AgoraService? {
        return agoraService
    }
    
    @Synchronized
    fun clear() {
        agoraService = null
        Log.d(TAG, "AgoraService instance cleared from holder")
    }
}
