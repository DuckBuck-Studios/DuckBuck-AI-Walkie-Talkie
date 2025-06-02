package com.duckbuck.app.fcm

import android.app.ActivityManager
import android.content.Context
import com.duckbuck.app.core.AppLogger

/**
 * FCM App State Detector responsible for determining current app state
 * Helps in deciding the appropriate call handling strategy
 */
class FcmAppStateDetector(private val context: Context) {
    
    companion object {
        private const val TAG = "FcmAppStateDetector"
    }
    
    /**
     * Enum representing different app states
     */
    enum class AppState {
        FOREGROUND,
        BACKGROUND,
        KILLED
    }
    
    /**
     * Get current app state
     * @return AppState indicating current state of the app
     */
    fun getCurrentAppState(): AppState {
        return try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val runningProcesses = activityManager.runningAppProcesses
            val packageName = context.packageName
            
            for (processInfo in runningProcesses) {
                if (processInfo.processName == packageName) {
                    val appState = when (processInfo.importance) {
                        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> AppState.FOREGROUND
                        ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE,
                        ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> AppState.BACKGROUND
                        else -> AppState.BACKGROUND
                    }
                    
                    AppLogger.d(TAG, "App state detected: $appState (importance: ${processInfo.importance})")
                    return appState
                }
            }
            
            AppLogger.d(TAG, "App state detected: KILLED (process not found)")
            AppState.KILLED
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error detecting app state", e)
            // Default to background as safest assumption
            AppState.BACKGROUND
        }
    }
    
    /**
     * Check if app is in foreground
     */
    fun isAppInForeground(): Boolean {
        return getCurrentAppState() == AppState.FOREGROUND
    }
    
    /**
     * Check if app is in background (backgrounded but not killed)
     */
    fun isAppInBackground(): Boolean {
        return getCurrentAppState() == AppState.BACKGROUND
    }
    
    /**
     * Check if app is killed/terminated
     */
    fun isAppKilled(): Boolean {
        return getCurrentAppState() == AppState.KILLED
    }
    
    /**
     * Get descriptive string for current app state
     */
    fun getAppStateDescription(): String {
        return when (getCurrentAppState()) {
            AppState.FOREGROUND -> "App is in foreground"
            AppState.BACKGROUND -> "App is in background"
            AppState.KILLED -> "App is killed/terminated"
        }
    }
}
