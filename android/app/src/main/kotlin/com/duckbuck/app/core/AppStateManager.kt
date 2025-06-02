package com.duckbuck.app.core

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.duckbuck.app.callstate.CallStatePersistenceManager
import com.duckbuck.app.services.WalkieTalkieService
import com.duckbuck.app.audio.VolumeAcquireManager

/**
 * App State Manager - Handles app lifecycle state management
 * Extracted from MainActivity for better separation of concerns
 */
class AppStateManager(private val context: Context) {
    
    companion object {
        private const val TAG = "AppStateManager"
    }
    
    private val callStatePersistence = CallStatePersistenceManager(context)
    private val volumeAcquireManager = VolumeAcquireManager(context)
    
    /**
     * Check for active calls when app is resumed and trigger appropriate UI
     * This handles the scenario where the app was killed and user returns to it
     */
    fun checkForActiveCallsOnResume(onCallFound: (callName: String, callerPhoto: String?, isMuted: Boolean) -> Unit) {
        try {
            AppLogger.i(TAG, "🔄 Checking for active calls on app resume")
            
            val callData = callStatePersistence.getCurrentCallData()
            
            if (callData != null) {
                AppLogger.i(TAG, "📞 Found call data on resume: ${callData.callName}")
                
                // 🔊 VOLUME ACQUIRE: Set volume to 100% when resuming active call
                volumeAcquireManager.acquireMaximumVolume(
                    mode = VolumeAcquireManager.Companion.VolumeAcquireMode.MEDIA_AND_VOICE_CALL,
                    showUIFeedback = true // Show UI feedback when user resumes app
                )
                
                val volumeInfo = volumeAcquireManager.getCurrentVolumeInfo()
                AppLogger.i(TAG, "🔊 Volume acquired on app resume - $volumeInfo")
                
                // Check if WalkieTalkieService is running
                val isServiceRunning = isWalkieTalkieServiceRunning()
                AppLogger.d(TAG, "🔧 WalkieTalkieService running: $isServiceRunning")
                
                if (isServiceRunning) {
                    // Service is running, so call is likely active - show UI immediately
                    val agoraService = AgoraServiceManager.getAgoraService()
                    val isMuted = agoraService?.isMicrophoneMuted() ?: true
                    
                    // Small delay to ensure Flutter engine is ready
                    Handler(Looper.getMainLooper()).postDelayed({
                        onCallFound(callData.callName, callData.callerPhoto, isMuted)
                        AppLogger.i(TAG, "✅ Call UI triggered for active call: ${callData.callName} (muted: $isMuted)")
                    }, 200) // Delay for Flutter engine readiness
                } else {
                    // Service not running but call data exists - clear stale data
                    AppLogger.w(TAG, "🧹 Service not running but call data exists - clearing stale data")
                    callStatePersistence.clearCallData()
                }
            } else {
                AppLogger.d(TAG, "📵 No call data found on resume")
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error checking for active calls on resume", e)
        }
    }
    
    /**
     * Check if WalkieTalkieService is currently running
     */
    private fun isWalkieTalkieServiceRunning(): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in activityManager.getRunningServices(Integer.MAX_VALUE)) {
            if (WalkieTalkieService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }
    
    /**
     * Get current app state for lifecycle management
     */
    fun getCurrentAppState(): AppState {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningProcesses = activityManager.runningAppProcesses
        val packageName = context.packageName
        
        for (processInfo in runningProcesses) {
            if (processInfo.processName == packageName) {
                return when (processInfo.importance) {
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> AppState.FOREGROUND
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE,
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> AppState.BACKGROUND
                    else -> AppState.BACKGROUND
                }
            }
        }
        
        return AppState.KILLED
    }
    
    enum class AppState {
        FOREGROUND,
        BACKGROUND,
        KILLED
    }
}
