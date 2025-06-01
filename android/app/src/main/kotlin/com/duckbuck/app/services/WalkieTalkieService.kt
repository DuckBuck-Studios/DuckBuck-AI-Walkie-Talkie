package com.duckbuck.app.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
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
 * 5. Shows notifications when OTHER users speak (not self)
 */
class WalkieTalkieService : Service() {
    
    companion object {
        private const val TAG = "WalkieTalkieService"
        
        // Intent extras
        private const val EXTRA_ACTION = "action"
        private const val EXTRA_CHANNEL_ID = "channel_id"
        private const val EXTRA_CHANNEL_NAME = "channel_name"
        private const val EXTRA_TOKEN = "token"
        private const val EXTRA_UID = "uid"
        private const val EXTRA_USERNAME = "username"
        private const val EXTRA_SPEAKER_UID = "speaker_uid"
        private const val EXTRA_SPEAKER_USERNAME = "speaker_username"
        
        // Actions
        private const val ACTION_JOIN_CHANNEL = "join_channel"
        private const val ACTION_LEAVE_CHANNEL = "leave_channel"
        private const val ACTION_STOP_SERVICE = "stop_service"
        
        /**
         * Join a walkie-talkie channel through the service
         */
        fun joinChannel(
            context: Context,
            channelId: String,
            channelName: String,
            token: String,
            uid: Int,
            username: String? = null
        ) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, ACTION_JOIN_CHANNEL)
                putExtra(EXTRA_CHANNEL_ID, channelId)
                putExtra(EXTRA_CHANNEL_NAME, channelName)
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_UID, uid)
                putExtra(EXTRA_USERNAME, username)
            }
            context.startService(intent)
        }
        
        /**
         * Store speaker info for leave notifications (called from FCM)
         */
        fun storeSpeakerInfo(context: Context, speakerUid: Int, speakerUsername: String) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, "store_speaker")
                putExtra(EXTRA_SPEAKER_UID, speakerUid)
                putExtra(EXTRA_SPEAKER_USERNAME, speakerUsername)
            }
            context.startService(intent)
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
    private lateinit var notificationManager: CallNotificationManager
    private lateinit var callStatePersistence: CallStatePersistenceManager
    private lateinit var agoraCallManager: AgoraCallManager
    private var wakeLock: PowerManager.WakeLock? = null
    
    // Current channel state
    private var currentChannelId: String? = null
    private var currentChannelName: String? = null
    private var isChannelActive = false
    
    // UID-to-Username mapping for walkie-talkie participants
    private val uidToUsernameMap = mutableMapOf<Int, String>()
    private var myUid: Int = 0
    private var myUsername: String? = null
    
    // Track the most recent speaker from FCM (for leave notifications)
    private var lastSpeakerUid: Int = 0
    private var lastSpeakerUsername: String? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🚀 WalkieTalkie Service starting up...")
        
        initializeComponents()
        acquireWakeLock()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "📨 Service command received: ${intent?.getStringExtra(EXTRA_ACTION)}")
        
        val action = intent?.getStringExtra(EXTRA_ACTION)
        
        // Start as background service (no foreground notification)
        when (action) {
            ACTION_JOIN_CHANNEL -> {
                Log.i(TAG, "🎯 Starting walkie-talkie service silently")
            }
        }
        
        // Handle the specific action
        when (action) {
            ACTION_JOIN_CHANNEL -> {
                val channelId = intent.getStringExtra(EXTRA_CHANNEL_ID)
                val channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME)
                val token = intent.getStringExtra(EXTRA_TOKEN)
                val uid = intent.getIntExtra(EXTRA_UID, 0)  
                val username = intent.getStringExtra(EXTRA_USERNAME)
                val speakerUid = intent.getIntExtra(EXTRA_SPEAKER_UID, 0)
                val speakerUsername = intent.getStringExtra(EXTRA_SPEAKER_USERNAME)
                
                if (channelId != null && channelName != null && token != null && uid != 0) {
                    // Store speaker info for leave notifications
                    if (speakerUid != 0 && speakerUsername != null) {
                        lastSpeakerUid = speakerUid
                        lastSpeakerUsername = speakerUsername
                        Log.i(TAG, "📻 Stored speaker info: $speakerUsername (UID: $speakerUid)")
                    }
                    
                    joinWalkieTalkieChannel(channelId, channelName, token, uid, username)
                } else {
                    Log.e(TAG, "❌ Invalid channel join parameters")
                }
            }
            "store_speaker" -> {
                val speakerUid = intent.getIntExtra(EXTRA_SPEAKER_UID, 0)
                val speakerUsername = intent.getStringExtra(EXTRA_SPEAKER_USERNAME)
                
                if (speakerUid != 0 && speakerUsername != null) {
                    lastSpeakerUid = speakerUid
                    lastSpeakerUsername = speakerUsername
                    Log.i(TAG, "📻 Updated speaker info: $speakerUsername (UID: $speakerUid)")
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
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        Log.i(TAG, "🛑 WalkieTalkie Service shutting down...")
        
        leaveCurrentChannel()
        releaseWakeLock()
        
        super.onDestroy()
    }
    
    /**
     * Initialize service components
     */
    private fun initializeComponents() {
        try {
            notificationManager = CallNotificationManager(this)
            callStatePersistence = CallStatePersistenceManager(this)
            agoraCallManager = AgoraCallManager(this)
            
            Log.i(TAG, "✅ Service components initialized")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing service components", e)
        }
    }
    
    /**
     * Join a walkie-talkie channel
     */
    private fun joinWalkieTalkieChannel(channelId: String, channelName: String, token: String, uid: Int, username: String?) {
        try {
            Log.i(TAG, "📻 Joining walkie-talkie channel: $channelName (uid: $uid, username: $username)")
            
            // Leave any existing channel first
            if (isChannelActive) {
                leaveCurrentChannel()
            }
            
            // Store my own UID and username
            myUid = uid
            myUsername = username
            if (username != null) {
                uidToUsernameMap[uid] = username
                Log.i(TAG, "✅ Stored username mapping: $uid -> $username")
            }
            
            // Join the new channel
            val joined = agoraCallManager.joinCallOptimized(
                token = token,
                uid = uid,
                channelId = channelId,
                eventListener = createServiceEventListener(channelId)
            )
            
            if (joined) {
                currentChannelId = channelId
                currentChannelName = channelName
                isChannelActive = true
                
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
                
                // Clear state
                callStatePersistence.clearCallData()
                
                // Reset service state
                currentChannelId = null
                currentChannelName = null
                isChannelActive = false
                
                // Clear username mappings
                uidToUsernameMap.clear()
                myUid = 0
                myUsername = null
                
                // Clear speaker info
                lastSpeakerUid = 0
                lastSpeakerUsername = null
                
                // Stop the service completely instead of showing "Ready" notification
                Log.i(TAG, "✅ Left walkie-talkie channel - stopping service")
                stopSelf()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error leaving walkie-talkie channel", e)
        }
    }
    
    /**
     * Get username for a given UID, with fallback to "User [UID]"
     */
    private fun getUsernameForUid(uid: Int): String {
        return uidToUsernameMap[uid] ?: "User $uid"
    }
    
    /**
     * Create event listener for service-managed walkie-talkie events
     */
    private fun createServiceEventListener(channelId: String): AgoraService.AgoraEventListener {
        return object : AgoraService.AgoraEventListener {
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                Log.i(TAG, "✅ Service: Walkie-talkie channel joined: $channel (uid: $uid)")
                callStatePersistence.markCallAsJoined(channelId)
            }
            
            override fun onLeaveChannel() {
                Log.i(TAG, "📻 Service: Left walkie-talkie channel: $channelId")
                
                // Auto-cleanup state
                currentChannelId = null
                currentChannelName = null
                isChannelActive = false
                
                callStatePersistence.clearCallData()
                
                // Clear username mappings
                uidToUsernameMap.clear()
                myUid = 0
                myUsername = null
                
                // Stop the service completely
                Log.i(TAG, "🛑 Left channel - stopping service")
                stopSelf()
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                Log.i(TAG, "👤 Service: User joined walkie-talkie: $uid")
                // Note: We don't have username info for users who join later
                // This would need to be provided via a separate mechanism
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                Log.i(TAG, "👋 Service: User left walkie-talkie: $uid (lastSpeakerUid: $lastSpeakerUid)")
                
                // Only show disconnection notification for OTHER users (not self)
                if (uid != myUid) {
                    // Clear any existing speaking notification first
                    notificationManager.clearSpeakingNotification()
                    Log.i(TAG, "🧹 Cleared speaking notification before showing leave notification")
                    
                    // In walkie-talkie mode, prioritize the last speaker's username
                    // since FCM and Agora UIDs might differ but usually only one person speaks
                    val username = if (lastSpeakerUsername != null) {
                        val speakerName = lastSpeakerUsername!!
                        Log.i(TAG, "📻 Using stored speaker name: $speakerName for leaving user $uid")
                        speakerName
                    } else {
                        val fallbackName = getUsernameForUid(uid)
                        Log.i(TAG, "📻 Using fallback name: $fallbackName for leaving user $uid")
                        fallbackName
                    }
                    
                    notificationManager.showDisconnectionNotification(username)
                    Log.i(TAG, "📢 Showing disconnection notification for: $username")
                    
                    // Clear speaker info after showing the leave notification
                    lastSpeakerUid = 0
                    lastSpeakerUsername = null
                    Log.i(TAG, "🧹 Cleared speaker info after user left")
                }
                
                // Remove from username mapping
                uidToUsernameMap.remove(uid)
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                Log.d(TAG, "🎤 Service: Walkie-talkie mic toggled: $isMuted (my UID: $myUid)")
                // Service notification updates removed - only showing speaking/over notifications
            }
            
            override fun onVideoToggled(isEnabled: Boolean) {
                Log.d(TAG, "📹 Service: Video toggled in walkie-talkie: $isEnabled")
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                Log.e(TAG, "❌ Service: Walkie-talkie error: $errorCode - $errorMessage")
            }
            
            override fun onAllUsersLeft() {
                Log.i(TAG, "👥 Service: All users left walkie-talkie")
                
                // Stop the service when everyone leaves
                Log.i(TAG, "🛑 All users left - stopping service")
                stopSelf()
            }
            
            override fun onChannelEmpty() {
                Log.i(TAG, "🏠 Service: Walkie-talkie channel empty")
            }
            
            override fun onUserSpeaking(uid: Int, volume: Int, isSpeaking: Boolean) {
                // Speaking notifications are handled immediately in FCM orchestrator
                // This is just for logging/debugging Agora events
                Log.d(TAG, "🎤 Service: Agora detected user $uid speaking: $isSpeaking (volume: $volume)")
            }
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