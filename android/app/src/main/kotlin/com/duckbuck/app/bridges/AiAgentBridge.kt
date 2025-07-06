package com.duckbuck.app.bridges

import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.duckbuck.app.services.aiagent.AiAgentService
import com.duckbuck.app.services.aiagent.utils.AiAgentPrefsUtil
import com.duckbuck.app.services.agora.AgoraService

/**
 * AiAgentBridge - Flutter MethodChannel bridge for AI Agent Service communication
 * Handles starting, stopping, and managing AI agent background service
 */
class AiAgentBridge(private val context: Context) : MethodCallHandler {
    
    companion object {
        private const val TAG = "AiAgentBridge"
        const val CHANNEL_NAME = "com.duckbuck.app/ai_agent"
        
        // Method names
        private const val METHOD_START_AI_AGENT_SERVICE = "startAiAgentService"
        private const val METHOD_STOP_AI_AGENT_SERVICE = "stopAiAgentService"
        private const val METHOD_IS_AI_AGENT_SERVICE_RUNNING = "isAiAgentServiceRunning"
        private const val METHOD_GET_AI_AGENT_SESSION_INFO = "getAiAgentSessionInfo"
        private const val METHOD_ON_APP_BACKGROUNDED = "onAppBackgrounded"
        private const val METHOD_ON_APP_FOREGROUNDED = "onAppForegrounded"
    }
    
    private val prefsUtil = AiAgentPrefsUtil(context)
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            Log.d(TAG, "🤖 AI Agent Bridge method called: ${call.method}")
            
            when (call.method) {
                METHOD_START_AI_AGENT_SERVICE -> {
                    handleStartAiAgentService(call, result)
                }
                METHOD_STOP_AI_AGENT_SERVICE -> {
                    handleStopAiAgentService(result)
                }
                METHOD_IS_AI_AGENT_SERVICE_RUNNING -> {
                    handleIsAiAgentServiceRunning(result)
                }
                METHOD_GET_AI_AGENT_SESSION_INFO -> {
                    handleGetAiAgentSessionInfo(result)
                }
                METHOD_ON_APP_BACKGROUNDED -> {
                    handleAppBackgrounded(result)
                }
                METHOD_ON_APP_FOREGROUNDED -> {
                    handleAppForegrounded(result)
                }
                else -> {
                    Log.w(TAG, "⚠️ Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling method call: ${call.method}", e)
            result.error("AI_AGENT_ERROR", "Error handling ${call.method}: ${e.message}", null)
        }
    }
    
    /**
     * Start AI agent foreground service
     */
    private fun handleStartAiAgentService(call: MethodCall, result: Result) {
        try {
            val userId = call.argument<String>("userId")
            val channelName = call.argument<String>("channelName")
            
            if (userId.isNullOrEmpty()) {
                Log.e(TAG, "❌ Missing userId for AI agent service")
                result.error("INVALID_ARGUMENTS", "userId is required", null)
                return
            }
            
            if (channelName.isNullOrEmpty()) {
                Log.e(TAG, "❌ Missing channelName for AI agent service")
                result.error("INVALID_ARGUMENTS", "channelName is required", null)
                return
            }
            
            Log.i(TAG, "🤖 Starting AI agent service for user: $userId, channel: $channelName")
            
            // Create intent to start AI agent service
            val intent = Intent(context, AiAgentService::class.java).apply {
                action = AiAgentService.ACTION_START_AI_AGENT
                putExtra(AiAgentService.EXTRA_USER_ID, userId)
                putExtra(AiAgentService.EXTRA_CHANNEL_NAME, channelName)
                putExtra(AiAgentService.EXTRA_SESSION_START_TIME, System.currentTimeMillis())
            }
            
            // Start the foreground service
            context.startForegroundService(intent)
            
            Log.i(TAG, "✅ AI agent service start command sent")
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting AI agent service", e)
            result.error("START_SERVICE_ERROR", "Failed to start AI agent service: ${e.message}", null)
        }
    }
    
    /**
     * Stop AI agent foreground service
     */
    private fun handleStopAiAgentService(result: Result) {
        try {
            Log.i(TAG, "🤖 Stopping AI agent service")
            
            // Create intent to stop AI agent service
            val intent = Intent(context, AiAgentService::class.java).apply {
                action = AiAgentService.ACTION_STOP_AI_AGENT
            }
            
            // Send stop command to service
            context.startService(intent)
            
            Log.i(TAG, "✅ AI agent service stop command sent")
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping AI agent service", e)
            result.error("STOP_SERVICE_ERROR", "Failed to stop AI agent service: ${e.message}", null)
        }
    }
    
    /**
     * Check if AI agent service is currently running
     */
    private fun handleIsAiAgentServiceRunning(result: Result) {
        try {
            val isRunning = prefsUtil.hasActiveAiAgentSession()
            Log.d(TAG, "🤖 AI agent service running: $isRunning")
            result.success(isRunning)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking AI agent service status", e)
            result.error("SERVICE_STATUS_ERROR", "Failed to check service status: ${e.message}", null)
        }
    }
    
    /**
     * Get current AI agent session information
     */
    private fun handleGetAiAgentSessionInfo(result: Result) {
        try {
            val sessionData = prefsUtil.getAiAgentSession()
            
            val sessionInfo = if (sessionData != null) {
                mapOf(
                    "isActive" to true,
                    "userId" to sessionData.userId,
                    "channelName" to sessionData.channelName,
                    "startTime" to sessionData.startTime,
                    "duration" to sessionData.getDurationSeconds(),
                    "formattedDuration" to sessionData.getFormattedDuration()
                )
            } else {
                mapOf(
                    "isActive" to false,
                    "userId" to null,
                    "channelName" to null,
                    "startTime" to null,
                    "duration" to 0,
                    "formattedDuration" to "0s"
                )
            }
            
            Log.d(TAG, "🤖 AI agent session info: $sessionInfo")
            result.success(sessionInfo)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting AI agent session info", e)
            result.error("SESSION_INFO_ERROR", "Failed to get session info: ${e.message}", null)
        }
    }
    
    /**
     * Handle app going to background - start foreground service if AI agent is active
     */
    private fun handleAppBackgrounded(result: Result) {
        try {
            Log.i(TAG, "🤖 App backgrounded - checking for active AI call")
            
            val agoraService = AgoraService.getInstance(context)
            
            // Check if there's an active AI call
            if (agoraService.isChannelConnected() && agoraService.getAiModeStatus()) {
                Log.i(TAG, "🤖 Active AI call detected, starting AI agent service for background mode")
                
                val channelName = agoraService.getCurrentChannelName()
                val userId = "ai_user_${System.currentTimeMillis()}" // Generate unique ID for AI session
                
                val intent = Intent(context, AiAgentService::class.java).apply {
                    action = AiAgentService.ACTION_START_AI_AGENT
                    putExtra(AiAgentService.EXTRA_USER_ID, userId)
                    putExtra(AiAgentService.EXTRA_CHANNEL_NAME, channelName)
                    putExtra(AiAgentService.EXTRA_SESSION_START_TIME, System.currentTimeMillis())
                }
                
                context.startForegroundService(intent)
                Log.i(TAG, "✅ AI agent service started for background mode")
                result.success(true)
            } else {
                // Fallback: Check if there's already a saved AI agent session
                val sessionData = prefsUtil.getAiAgentSession()
                if (sessionData != null) {
                    Log.i(TAG, "🤖 Saved AI agent session found, ensuring foreground service is running")
                    
                    // Create intent to ensure foreground service is running
                    val intent = Intent(context, AiAgentService::class.java).apply {
                        action = AiAgentService.ACTION_START_AI_AGENT
                        putExtra(AiAgentService.EXTRA_USER_ID, sessionData.userId)
                        putExtra(AiAgentService.EXTRA_CHANNEL_NAME, sessionData.channelName)
                        putExtra(AiAgentService.EXTRA_SESSION_START_TIME, sessionData.startTime)
                    }
                    
                    // Start foreground service to keep app alive
                    context.startForegroundService(intent)
                    
                    Log.i(TAG, "✅ AI agent foreground service ensured for background operation")
                    result.success(true)
                } else {
                    Log.d(TAG, "💡 No active AI call or session, AI agent service not needed")
                    result.success(false)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking for AI call and starting service", e)
            result.error("APP_BACKGROUND_ERROR", "Failed to handle app backgrounded: ${e.message}", null)
        }
    }
    
    /**
     * Handle app coming to foreground - can stop foreground service if desired
     */
    private fun handleAppForegrounded(result: Result) {
        try {
            Log.i(TAG, "🤖 App foregrounded - AI agent session can continue in app")
            
            // Update last updated timestamp to keep session fresh
            prefsUtil.updateLastUpdated()
            
            // Note: We keep the foreground service running even when app is in foreground
            // This ensures consistent behavior and notification presence
            // The service will only stop when AI agent session actually ends
            
            Log.d(TAG, "✅ App foreground state handled")
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling app foregrounded", e)
            result.error("APP_FOREGROUND_ERROR", "Failed to handle app foregrounded: ${e.message}", null)
        }
    }
    
    /**
     * Public method to handle app going to background (called from MainActivity)
     */
    fun onAppBackgrounded() {
        try {
            Log.i(TAG, "🤖 App backgrounded - checking for active AI call")
            
            val agoraService = AgoraService.getInstance(context)
            
            // Check if there's an active AI call
            if (agoraService.isChannelConnected() && agoraService.getAiModeStatus()) {
                Log.i(TAG, "🤖 Active AI call detected, starting AI agent service for background mode")
                
                val channelName = agoraService.getCurrentChannelName()
                val userId = "ai_user_${System.currentTimeMillis()}" // Generate unique ID for AI session
                
                val intent = Intent(context, AiAgentService::class.java).apply {
                    action = AiAgentService.ACTION_START_AI_AGENT
                    putExtra(AiAgentService.EXTRA_USER_ID, userId)
                    putExtra(AiAgentService.EXTRA_CHANNEL_NAME, channelName)
                    putExtra(AiAgentService.EXTRA_SESSION_START_TIME, System.currentTimeMillis())
                }
                
                context.startForegroundService(intent)
                Log.i(TAG, "✅ AI agent service started for background mode")
            } else {
                // Fallback: Check if there's already a saved AI agent session
                val sessionData = prefsUtil.getAiAgentSession()
                if (sessionData != null) {
                    Log.i(TAG, "🤖 Saved AI agent session found, ensuring foreground service is running")
                    
                    // Create intent to ensure foreground service is running
                    val intent = Intent(context, AiAgentService::class.java).apply {
                        action = AiAgentService.ACTION_START_AI_AGENT
                        putExtra(AiAgentService.EXTRA_USER_ID, sessionData.userId)
                        putExtra(AiAgentService.EXTRA_CHANNEL_NAME, sessionData.channelName)
                        putExtra(AiAgentService.EXTRA_SESSION_START_TIME, sessionData.startTime)
                    }
                    
                    // Start foreground service to keep app alive
                    context.startForegroundService(intent)
                    
                    Log.i(TAG, "✅ AI agent foreground service ensured for background operation")
                } else {
                    Log.d(TAG, "💡 No active AI call or session, AI agent service not needed")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking for AI call and starting service", e)
        }
    }
    
    /**
     * Public method to handle app coming to foreground (called from MainActivity)
     */
    fun onAppForegrounded() {
        try {
            Log.i(TAG, "🤖 App foregrounded - AI agent session can continue in app")
            
            // Update last updated timestamp to keep session fresh
            prefsUtil.updateLastUpdated()
            
            // Note: We keep the foreground service running even when app is in foreground
            // This ensures consistent behavior and notification presence
            // The service will only stop when AI agent session actually ends
            
            Log.d(TAG, "✅ App foreground state handled")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling app foregrounded", e)
        }
    }
}
