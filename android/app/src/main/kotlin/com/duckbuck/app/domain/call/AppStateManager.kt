package com.duckbuck.app.domain.call

import android.app.ActivityManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.duckbuck.app.data.local.CallStatePersistenceManager
import com.duckbuck.app.presentation.services.WalkieTalkieService
import com.duckbuck.app.infrastructure.audio.VolumeAcquireManager
import com.duckbuck.app.domain.call.ChannelOccupancyManager
import com.duckbuck.app.infrastructure.monitoring.AppLogger
import com.duckbuck.app.domain.messaging.FcmDataHandler
import com.duckbuck.app.data.agora.AgoraServiceManager

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
    private val occupancyManager = ChannelOccupancyManager()
    
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
                    mode = VolumeAcquireManager.Companion.VolumeAcquireMode.MEDIA_AND_VOICE_CALL
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
                    
                    // Optimized delay to ensure Flutter engine is ready - reduced for faster startup
                    Handler(Looper.getMainLooper()).postDelayed({
                        onCallFound(callData.callName, callData.callerPhoto, isMuted)
                        AppLogger.i(TAG, "✅ Call UI triggered for active call: ${callData.callName} (muted: $isMuted)")
                    }, 75) // Reduced from 150ms to 75ms for faster UI response
                } else {
                    // Service not running but call data exists - check channel occupancy before clearing
                    AppLogger.w(TAG, "🔍 Service not running but call data exists - checking channel occupancy before clearing")
                    checkChannelOccupancyAndDecide(callData, onCallFound)
                }
            } else {
                AppLogger.d(TAG, "📵 No call data found on resume")
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error checking for active calls on resume", e)
        }
    }
    
    /**
     * Check channel occupancy before deciding whether to rejoin or clear stale data
     * This prevents rejoining empty channels while preserving active ones
     */
    private fun checkChannelOccupancyAndDecide(
        callData: FcmDataHandler.CallData, 
        onCallFound: (callName: String, callerPhoto: String?, isMuted: Boolean) -> Unit
    ) {
        try {
            AppLogger.i(TAG, "🔍 Checking occupancy for channel: ${callData.channelId}")
            
            // First, we need to briefly join the channel to check occupancy
            // We'll use a quick join-check-decide approach
            occupancyManager.checkOccupancyWithQuickJoin(
                channelId = callData.channelId,
                token = callData.token,
                uid = callData.uid,
                onChannelOccupied = { userCount: Int ->
                    AppLogger.i(TAG, "✅ Channel has $userCount users - rejoining via service")
                    
                    // Channel has users, rejoin via WalkieTalkieService
                    WalkieTalkieService.joinChannel(
                        context = context,
                        channelId = callData.channelId,
                        channelName = callData.callName,
                        token = callData.token,
                        uid = callData.uid,
                        username = callData.callName,
                        callerPhoto = callData.callerPhoto
                    )
                    
                    // Show UI after a brief delay to allow service to start
                    Handler(Looper.getMainLooper()).postDelayed({
                        val agoraService = AgoraServiceManager.getAgoraService()
                        val isMuted = agoraService?.isMicrophoneMuted() ?: true
                        onCallFound(callData.callName, callData.callerPhoto, isMuted)
                        AppLogger.i(TAG, "✅ Rejoined and triggered UI for occupied channel: ${callData.callName}")
                    }, 200) // Small delay for service initialization
                },
                onChannelEmpty = {
                    AppLogger.i(TAG, "🏃‍♂️ Channel is empty - clearing stale data")
                    callStatePersistence.clearCallData()
                }
            )
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error checking channel occupancy, clearing stale data as fallback", e)
            callStatePersistence.clearCallData()
        }
    }
    
    /**
     * Check if WalkieTalkieService is currently running
     * Modern approach: Use persistent call data to infer service state
     */
    private fun isWalkieTalkieServiceRunning(): Boolean {
        // Instead of using deprecated getRunningServices(), we check if:
        // 1. We have active call data AND
        // 2. The call state indicates an active/joined call
        // This is more reliable and doesn't require deprecated APIs
        
        val callData = callStatePersistence.getCurrentCallData()
        val callState = callStatePersistence.getCurrentCallState()
        
        return callData != null && 
               (callState == CallStatePersistenceManager.CallState.ACTIVE || 
                callState == CallStatePersistenceManager.CallState.JOINING)
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
