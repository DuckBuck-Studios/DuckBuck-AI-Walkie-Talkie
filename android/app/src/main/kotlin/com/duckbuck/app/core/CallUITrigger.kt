package com.duckbuck.app.core

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/**
 * Utility class for triggering call UI in Flutter from Kotlin
 * Provides static methods to show/dismiss call UI screens
 */
object CallUITrigger {
    private const val TAG = "CallUITrigger"
    
    @Volatile
    private var methodChannel: MethodChannel? = null
    
    // Main thread handler for method channel calls
    private val mainHandler = Handler(Looper.getMainLooper())
    
    /**
     * Set the method channel instance (called from MainActivity)
     */
    fun setMethodChannel(channel: MethodChannel?) {
        methodChannel = channel
        AppLogger.d(TAG, "Call UI method channel ${if (channel != null) "set" else "cleared"}")
    }
    
    /**
     * Trigger the call UI to show in Flutter
     */
    fun showCallUI(callerName: String, callerPhotoUrl: String?, isMuted: Boolean = true) {
        mainHandler.post {
            try {
                val channel = methodChannel
                if (channel == null) {
                    AppLogger.w(TAG, "Call UI method channel not available - cannot show call UI")
                    return@post
                }
                
                AppLogger.i(TAG, "Triggering call UI for: $callerName (muted: $isMuted)")
                
                val arguments = mapOf(
                    "callerName" to callerName,
                    "callerPhotoUrl" to (callerPhotoUrl ?: ""),
                    "isMuted" to isMuted
                )
                
                channel.invokeMethod("showCallUI", arguments)
                
            } catch (e: Exception) {
                AppLogger.e(TAG, "Error triggering call UI", e)
            }
        }
    }
    
    /**
     * Trigger the call UI to dismiss in Flutter
     */
    fun dismissCallUI() {
        mainHandler.post {
            try {
                val channel = methodChannel
                if (channel == null) {
                    AppLogger.w(TAG, "Call UI method channel not available - cannot dismiss call UI")
                    return@post
                }
                
                AppLogger.i(TAG, "Dismissing call UI")
                
                channel.invokeMethod("dismissCallUI", null)
                
            } catch (e: Exception) {
                AppLogger.e(TAG, "Error dismissing call UI", e)
            }
        }
    }
}
