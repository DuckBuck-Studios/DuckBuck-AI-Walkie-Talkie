package com.duckbuck.app.services.aiagent

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.lifecycle.LifecycleService
import com.duckbuck.app.services.notification.NotificationService
import com.duckbuck.app.services.aiagent.utils.AiAgentPrefsUtil

/**
 * AiAgentService - Foreground service for handling ongoing AI agent conversations
 * Keeps the AI agent session alive when the app is backgrounded
 * Shows persistent notification: "DuckBuck AI Connected"
 */
class AiAgentService : Service() {
    
    companion object {
        private const val TAG = "AiAgentService"
        private const val SERVICE_ID = 3000
        
        // Service actions
        const val ACTION_START_AI_AGENT = "com.duckbuck.app.START_AI_AGENT"
        const val ACTION_STOP_AI_AGENT = "com.duckbuck.app.STOP_AI_AGENT"
        
        // Intent extras
        const val EXTRA_USER_ID = "user_id"
        const val EXTRA_CHANNEL_NAME = "channel_name"
        const val EXTRA_SESSION_START_TIME = "session_start_time"
    }
    
    private lateinit var notificationService: NotificationService
    private lateinit var prefsUtil: AiAgentPrefsUtil
    
    private var isServiceStarted = false
    private var currentUserId: String? = null
    private var currentChannelName: String? = null
    private var sessionStartTime: Long = 0
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🤖 AI Agent Service created")
        
        // Initialize services
        notificationService = NotificationService(this)
        prefsUtil = AiAgentPrefsUtil(this)
        
        Log.d(TAG, "✅ AI Agent Service initialized successfully")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "🤖 AI Agent Service onStartCommand called with action: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_AI_AGENT -> {
                handleStartAiAgent(intent)
            }
            ACTION_STOP_AI_AGENT -> {
                handleStopAiAgent()
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action received: ${intent?.action}")
            }
        }
        
        // Return START_NOT_STICKY so service doesn't restart automatically if killed
        // AI agent sessions should be explicitly managed
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        // This service doesn't support binding
        return null
    }
    
    override fun onDestroy() {
        Log.i(TAG, "🤖 AI Agent Service destroyed")
        
        try {
            // Clear notification
            notificationService.clearAiAgentNotification()
            
            // Clear session data
            prefsUtil.clearAiAgentSession()
            
            // Reset state
            isServiceStarted = false
            currentUserId = null
            currentChannelName = null
            sessionStartTime = 0
            
            Log.d(TAG, "✅ AI Agent Service cleanup completed")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during AI Agent Service cleanup", e)
        }
        
        super.onDestroy()
    }
    
    /**
     * Handle starting AI agent session
     */
    private fun handleStartAiAgent(intent: Intent) {
        try {
            // Extract session data from intent
            val userId = intent.getStringExtra(EXTRA_USER_ID)
            val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME)
            val startTime = intent.getLongExtra(EXTRA_SESSION_START_TIME, System.currentTimeMillis())
            
            if (userId.isNullOrEmpty() || channelName.isNullOrEmpty()) {
                Log.e(TAG, "❌ Missing required data for AI agent session. userId: $userId, channelName: $channelName")
                stopSelf()
                return
            }
            
            Log.i(TAG, "🤖 Starting AI agent session for user: $userId, channel: $channelName")
            
            // Store session data
            currentUserId = userId
            currentChannelName = channelName
            sessionStartTime = startTime
            
            // Save session to preferences
            prefsUtil.saveAiAgentSession(userId, channelName, startTime)
            
            // Start foreground service with notification
            startForegroundWithNotification()
            
            isServiceStarted = true
            
            Log.i(TAG, "✅ AI agent session started successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting AI agent session", e)
            stopSelf()
        }
    }
    
    /**
     * Handle stopping AI agent session
     */
    private fun handleStopAiAgent() {
        try {
            Log.i(TAG, "🤖 Stopping AI agent session")
            
            if (!isServiceStarted) {
                Log.w(TAG, "⚠️ AI agent session is not currently running")
                return
            }
            
            // Calculate session duration for logging
            val sessionDuration = if (sessionStartTime > 0) {
                (System.currentTimeMillis() - sessionStartTime) / 1000
            } else 0
            
            Log.i(TAG, "🤖 AI agent session ended. Duration: ${sessionDuration}s")
            
            // Stop the service (this will trigger onDestroy)
            stopSelf()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping AI agent session", e)
            stopSelf()
        }
    }
    
    /**
     * Start foreground service with AI agent notification
     */
    private fun startForegroundWithNotification() {
        try {
            Log.d(TAG, "🤖 Starting foreground service with AI agent notification")
            
            // Show the AI agent notification
            notificationService.showAiAgentNotification()
            
            // We need to create a notification for startForeground
            // Let's create a basic one and then update it with the full notification
            val notification = NotificationCompat.Builder(this, "duckbuck_ai_agent")
                .setSmallIcon(com.duckbuck.app.R.drawable.ic_notification)
                .setContentTitle("DuckBuck AI Connected")
                .setContentText("AI conversation in progress")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true)
                .build()
            
            // Start foreground service
            startForeground(SERVICE_ID, notification)
            
            Log.i(TAG, "✅ Foreground service started with AI agent notification")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting foreground service", e)
            throw e
        }
    }
    
    /**
     * Get current AI agent session info
     */
    fun getCurrentSessionInfo(): Map<String, Any?> {
        return mapOf(
            "isActive" to isServiceStarted,
            "userId" to currentUserId,
            "channelName" to currentChannelName,
            "startTime" to sessionStartTime,
            "duration" to if (sessionStartTime > 0) (System.currentTimeMillis() - sessionStartTime) / 1000 else 0
        )
    }
}
