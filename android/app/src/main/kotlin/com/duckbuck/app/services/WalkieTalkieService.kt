package com.duckbuck.app.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.duckbuck.app.MainActivity
import com.duckbuck.app.agora.AgoraCallManager
import com.duckbuck.app.agora.AgoraService
import com.duckbuck.app.callstate.CallStatePersistenceManager
import com.duckbuck.app.notifications.CallNotificationManager

/**
 * Persistent Walkie-Talkie Foreground Service
 * 
 * This service ensures:
 * 1. Persistent walkie-talkie connection even when app is backgrounded
 * 2. Prevents Android from killing the app during active walkie-talkie sessions
 * 3. Maintains wake lock for reliable connectivity
 * 4. Provides ongoing notification showing walkie-talkie status
 */
class WalkieTalkieService : Service() {
    
    companion object {
        private const val TAG = "WalkieTalkieService"
        private const val FOREGROUND_SERVICE_ID = 2001
        private const val CHANNEL_ID = "walkie_talkie_persistent_service"
        private const val NOTIFICATION_ID = 1002
        
        // Intent extras
        private const val EXTRA_ACTION = "action"
        private const val EXTRA_CHANNEL_ID = "channel_id"
        private const val EXTRA_CHANNEL_NAME = "channel_name"
        private const val EXTRA_TOKEN = "token"
        private const val EXTRA_UID = "uid"
        
        // Actions
        private const val ACTION_START_SERVICE = "start_service"
        private const val ACTION_JOIN_CHANNEL = "join_channel"
        private const val ACTION_LEAVE_CHANNEL = "leave_channel"
        private const val ACTION_STOP_SERVICE = "stop_service"
        
        /**
         * Start the persistent walkie-talkie service
         */
        fun startService(context: Context) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, ACTION_START_SERVICE)
            }
            context.startForegroundService(intent)
        }
        
        /**
         * Join a walkie-talkie channel through the service
         */
        fun joinChannel(
            context: Context,
            channelId: String,
            channelName: String,
            token: String,
            uid: Int
        ) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, ACTION_JOIN_CHANNEL)
                putExtra(EXTRA_CHANNEL_ID, channelId)
                putExtra(EXTRA_CHANNEL_NAME, channelName)
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_UID, uid)
            }
            context.startForegroundService(intent)
        }
        
        /**
         * Leave current walkie-talkie channel
         */
        fun leaveChannel(context: Context) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, ACTION_LEAVE_CHANNEL)
            }
            context.startService(intent)
        }
        
        /**
         * Stop the persistent walkie-talkie service
         */
        fun stopService(context: Context) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, ACTION_STOP_SERVICE)
            }
            context.startService(intent)
        }
    }
    
    // Service components
    private lateinit var notificationManager: NotificationManager
    private lateinit var callNotificationManager: CallNotificationManager
    private lateinit var callStatePersistence: CallStatePersistenceManager
    private lateinit var agoraCallManager: AgoraCallManager
    private var wakeLock: PowerManager.WakeLock? = null
    
    // Current channel state
    private var currentChannelId: String? = null
    private var currentChannelName: String? = null
    private var isChannelActive = false
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🚀 WalkieTalkie Service starting up...")
        
        initializeComponents()
        createNotificationChannel()
        acquireWakeLock()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "📨 Service command received: ${intent?.getStringExtra(EXTRA_ACTION)}")
        
        val action = intent?.getStringExtra(EXTRA_ACTION)
        
        // CRITICAL: Start foreground service immediately for any action that uses startForegroundService()
        // This prevents the ForegroundServiceDidNotStartInTimeException
        when (action) {
            ACTION_START_SERVICE, ACTION_JOIN_CHANNEL, null -> {
                // These actions are called via startForegroundService(), so we must call startForeground() immediately
                startForegroundService()
            }
        }
        
        // Then handle the specific action
        when (action) {
            ACTION_START_SERVICE -> {
                // Already started foreground service above
                Log.i(TAG, "✅ Walkie-talkie service started and ready")
            }
            ACTION_JOIN_CHANNEL -> {
                val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID)
                val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME)
                val token = intent.getStringExtra(EXTRA_TOKEN)
                val uid = intent.getIntExtra(EXTRA_UID, 0)
                
                if (channelId != null && channelName != null && token != null && uid != 0) {
                    joinWalkieTalkieChannel(channelId, channelName, token, uid)
                } else {
                    Log.e(TAG, "❌ Invalid channel join parameters")
                }
            }
            ACTION_LEAVE_CHANNEL -> {
                leaveCurrentChannel()
            }
            ACTION_STOP_SERVICE -> {
                stopSelf()
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: $action")
            }
        }
        
        // Return START_STICKY to ensure service restarts if killed
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        // This service doesn't support binding
        return null
    }
    
    override fun onDestroy() {
        Log.i(TAG, "🛑 WalkieTalkie Service shutting down...")
        
        // Leave any active channel
        leaveCurrentChannel()
        
        // Release wake lock
        releaseWakeLock()
        
        super.onDestroy()
    }
    
    /**
     * Initialize service components
     */
    private fun initializeComponents() {
        try {
            notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            callNotificationManager = CallNotificationManager(this)
            callStatePersistence = CallStatePersistenceManager(this)
            agoraCallManager = AgoraCallManager(this)
            
            Log.i(TAG, "✅ Service components initialized")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing service components", e)
        }
    }
    
    /**
     * Start the foreground service with persistent notification
     */
    private fun startForegroundService() {
        try {
            val notification = createServiceNotification(
                title = "📻 Walkie-Talkie Ready",
                content = "Ready to receive walkie-talkie calls"
            )
            
            startForeground(FOREGROUND_SERVICE_ID, notification)
            Log.i(TAG, "✅ Foreground service started")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting foreground service", e)
        }
    }
    
    /**
     * Join a walkie-talkie channel
     */
    private fun joinWalkieTalkieChannel(channelId: String, channelName: String, token: String, uid: Int) {
        try {
            Log.i(TAG, "📻 Joining walkie-talkie channel: $channelName")
            
            // Leave any existing channel first
            if (isChannelActive) {
                leaveCurrentChannel()
            }
            
            // Join the new channel
            val joined = agoraCallManager.joinCallOptimized(
                token = token,
                uid = uid,
                channelId = channelId,
                eventListener = createServiceEventListener(channelId, channelName)
            )
            
            if (joined) {
                currentChannelId = channelId
                currentChannelName = channelName
                isChannelActive = true
                
                // Update service notification
                updateServiceNotification(
                    title = "📻 Connected to $channelName",
                    content = "Walkie-talkie active • Tap to open app"
                )
                
                // Show channel joined notification
                callNotificationManager.showChannelJoinedNotification(channelName, "You")
                
                // Persist the state
                callStatePersistence.markCallAsJoined(channelId)
                
                Log.i(TAG, "✅ Successfully joined walkie-talkie channel: $channelName")
            } else {
                Log.e(TAG, "❌ Failed to join walkie-talkie channel: $channelName")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error joining walkie-talkie channel", e)
        }
    }
    
    /**
     * Leave current walkie-talkie channel
     */
    private fun leaveCurrentChannel() {
        try {
            if (isChannelActive && currentChannelId != null) {
                Log.i(TAG, "📻 Leaving walkie-talkie channel: $currentChannelName")
                
                // Leave Agora channel
                agoraCallManager.leaveCall("Walkie-talkie channel disconnection")
                
                // Show disconnection notification
                currentChannelName?.let { channelName ->
                    callNotificationManager.showDisconnectionNotification(channelName)
                }
                
                // Clear state
                callStatePersistence.clearCallData()
                
                // Reset service state
                currentChannelId = null
                currentChannelName = null
                isChannelActive = false
                
                // Update service notification
                updateServiceNotification(
                    title = "📻 Walkie-Talkie Ready",
                    content = "Ready to receive walkie-talkie calls"
                )
                
                Log.i(TAG, "✅ Left walkie-talkie channel")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error leaving walkie-talkie channel", e)
        }
    }
    
    /**
     * Create event listener for service-managed walkie-talkie events
     */
    private fun createServiceEventListener(channelId: String, channelName: String): AgoraService.AgoraEventListener {
        return object : AgoraService.AgoraEventListener {
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                Log.i(TAG, "✅ Service: Walkie-talkie channel joined: $channel")
                callStatePersistence.markCallAsJoined(channelId)
            }
            
            override fun onLeaveChannel() {
                Log.i(TAG, "📻 Service: Left walkie-talkie channel: $channelId")
                
                // Auto-cleanup state
                currentChannelId = null
                currentChannelName = null
                isChannelActive = false
                
                callStatePersistence.clearCallData()
                callNotificationManager.showDisconnectionNotification(channelName)
                
                // Update service notification
                updateServiceNotification(
                    title = "📻 Walkie-Talkie Ready",
                    content = "Ready to receive walkie-talkie calls"
                )
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                Log.i(TAG, "👤 Service: User joined walkie-talkie: $uid")
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                Log.i(TAG, "👋 Service: User left walkie-talkie: $uid")
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                Log.d(TAG, "🎤 Service: Walkie-talkie mic toggled: $isMuted")
                
                // Update speaking notifications
                if (!isMuted && currentChannelName != null) {
                    callNotificationManager.showSpeakingNotification("You", currentChannelName!!)
                    
                    // Update service notification to show speaking
                    updateServiceNotification(
                        title = "🗣️ Speaking in $currentChannelName",
                        content = "You are currently speaking • Tap to open app"
                    )
                } else if (currentChannelName != null) {
                    // Update service notification back to connected
                    updateServiceNotification(
                        title = "📻 Connected to $currentChannelName",
                        content = "Walkie-talkie active • Tap to open app"
                    )
                }
            }
            
            override fun onVideoToggled(isEnabled: Boolean) {
                Log.d(TAG, "📹 Service: Video toggled in walkie-talkie: $isEnabled")
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                Log.e(TAG, "❌ Service: Walkie-talkie error: $errorCode - $errorMessage")
            }
            
            override fun onAllUsersLeft() {
                Log.i(TAG, "👥 Service: All users left walkie-talkie")
                
                if (currentChannelName != null) {
                    callNotificationManager.showDisconnectionNotification(currentChannelName!!)
                }
                
                // Keep service running and ready for next call
                updateServiceNotification(
                    title = "📻 Walkie-Talkie Ready",
                    content = "Ready to receive walkie-talkie calls"
                )
            }
            
            override fun onChannelEmpty() {
                Log.i(TAG, "🏠 Service: Walkie-talkie channel empty")
            }
        }
    }
    
    /**
     * Create notification channel for the service
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Walkie-Talkie Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent walkie-talkie connection service"
                enableVibration(false)
                setShowBadge(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Service notification channel created")
        }
    }
    
    /**
     * Create service notification
     */
    private fun createServiceNotification(title: String, content: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }
    
    /**
     * Update the service notification
     */
    private fun updateServiceNotification(title: String, content: String) {
        try {
            val notification = createServiceNotification(title, content)
            notificationManager.notify(FOREGROUND_SERVICE_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating service notification", e)
        }
    }
    
    /**
     * Acquire wake lock to ensure reliable connectivity
     */
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "DuckBuck::WalkieTalkieService"
            )
            wakeLock?.acquire(10 * 60 * 1000L /*10 minutes*/)
            Log.d(TAG, "✅ Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error acquiring wake lock", e)
        }
    }
    
    /**
     * Release wake lock
     */
    private fun releaseWakeLock() {
        try {
            wakeLock?.let { lock ->
                if (lock.isHeld) {
                    lock.release()
                    Log.d(TAG, "✅ Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error releasing wake lock", e)
        }
    }
}
