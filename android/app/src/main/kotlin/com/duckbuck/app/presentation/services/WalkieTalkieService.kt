package com.duckbuck.app.presentation.services
import com.duckbuck.app.infrastructure.monitoring.AppLogger

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.PowerManager
import com.duckbuck.app.data.agora.AgoraCallManager
import com.duckbuck.app.data.agora.AgoraService
import com.duckbuck.app.data.local.CallStatePersistenceManager
import com.duckbuck.app.data.agora.AgoraServiceManager
import com.duckbuck.app.presentation.bridges.CallUITrigger
import com.duckbuck.app.domain.notification.CallNotificationManager
import com.duckbuck.app.infrastructure.audio.VolumeAcquireManager
import com.duckbuck.app.domain.call.ChannelOccupancyManager

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
        private const val EXTRA_CALLER_PHOTO = "caller_photo"
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
            username: String? = null,
            callerPhoto: String? = null
        ) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                putExtra(EXTRA_ACTION, ACTION_JOIN_CHANNEL)
                putExtra(EXTRA_CHANNEL_ID, channelId)
                putExtra(EXTRA_CHANNEL_NAME, channelName)
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_UID, uid)
                putExtra(EXTRA_USERNAME, username)
                putExtra(EXTRA_CALLER_PHOTO, callerPhoto)
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
    private lateinit var volumeAcquireManager: VolumeAcquireManager
    private lateinit var occupancyManager: ChannelOccupancyManager
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
        AppLogger.i(TAG, "🚀 WalkieTalkie Service starting up...")
        
        initializeComponents()
        acquireWakeLock()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        AppLogger.i(TAG, "📨 Service command received: ${intent?.getStringExtra(EXTRA_ACTION)}")
        
        val action = intent?.getStringExtra(EXTRA_ACTION)
        
        // Start as background service (no foreground notification)
        when (action) {
            ACTION_JOIN_CHANNEL -> {
                AppLogger.i(TAG, "🎯 Starting walkie-talkie service silently")
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
                val callerPhoto = intent.getStringExtra(EXTRA_CALLER_PHOTO)
                val speakerUid = intent.getIntExtra(EXTRA_SPEAKER_UID, 0)
                val speakerUsername = intent.getStringExtra(EXTRA_SPEAKER_USERNAME)
                
                if (channelId != null && channelName != null && token != null && uid != 0) {
                    // Store speaker info for leave notifications
                    if (speakerUid != 0 && speakerUsername != null) {
                        lastSpeakerUid = speakerUid
                        lastSpeakerUsername = speakerUsername
                        AppLogger.i(TAG, "📻 Stored speaker info: $speakerUsername (UID: $speakerUid)")
                    }
                    
                    joinWalkieTalkieChannel(channelId, channelName, token, uid, username, callerPhoto)
                } else {
                    AppLogger.e(TAG, "❌ Invalid channel join parameters")
                }
            }
            "store_speaker" -> {
                val speakerUid = intent.getIntExtra(EXTRA_SPEAKER_UID, 0)
                val speakerUsername = intent.getStringExtra(EXTRA_SPEAKER_USERNAME)
                
                if (speakerUid != 0 && speakerUsername != null) {
                    lastSpeakerUid = speakerUid
                    lastSpeakerUsername = speakerUsername
                    AppLogger.i(TAG, "📻 Updated speaker info: $speakerUsername (UID: $speakerUid)")
                }
            }
            ACTION_LEAVE_CHANNEL -> {
                leaveCurrentChannel()
            }
            ACTION_STOP_SERVICE -> {
                stopSelf()
            }
            else -> {
                AppLogger.w(TAG, "⚠️ Unknown action: $action")
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onDestroy() {
        AppLogger.i(TAG, "🛑 WalkieTalkie Service shutting down...")
        
        // Cleanup occupancy manager
        occupancyManager.cleanup()
        
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
            volumeAcquireManager = VolumeAcquireManager(this)
            occupancyManager = ChannelOccupancyManager()
            
            AppLogger.i(TAG, "✅ Service components initialized")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error initializing service components", e)
        }
    }
    
    /**
     * Join a walkie-talkie channel
     */
    private fun joinWalkieTalkieChannel(channelId: String, channelName: String, token: String, uid: Int, username: String?, callerPhoto: String? = null) {
        try {
            AppLogger.i(TAG, "📻 Joining walkie-talkie channel: $channelName (uid: $uid, username: $username, photo: ${if (callerPhoto != null) "present" else "none"})")
            
            // 🔊 VOLUME ACQUIRE: Set volume to 100% when joining via service
            // This ensures maximum volume regardless of how the channel was joined
            volumeAcquireManager.acquireMaximumVolume(
                mode = VolumeAcquireManager.Companion.VolumeAcquireMode.MEDIA_AND_VOICE_CALL
            )
            
            val volumeInfo = volumeAcquireManager.getCurrentVolumeInfo()
            AppLogger.i(TAG, "🔊 Volume acquired in service - $volumeInfo")
            
            // Leave any existing channel first
            if (isChannelActive) {
                leaveCurrentChannel()
            }
            
            // CRITICAL: Save call data first before joining (for killed state UI recovery)
            val callData = com.duckbuck.app.domain.messaging.FcmDataHandler.CallData(
                token = token,
                uid = uid,
                channelId = channelId,
                callName = channelName,
                // Use provided photo URL or get from existing data
                callerPhoto = callerPhoto ?: callStatePersistence.getCurrentCallData()?.callerPhoto,
                timestamp = System.currentTimeMillis() / 1000
            )
            callStatePersistence.saveIncomingCallData(callData)
            AppLogger.i(TAG, "💾 Saved call data to SharedPreferences for killed state recovery (photo URL: ${if (callData.callerPhoto != null) "present" else "none"})")
            
            // Store my own UID and username
            myUid = uid
            myUsername = username
            
            // Store username mapping for myself (the receiver/initiator)
            if (username != null) {
                uidToUsernameMap[uid] = username
                AppLogger.i(TAG, "✅ Stored username mapping: $uid -> $username")
            } else {
                // If no username provided, try to get current user's display name
                // This happens when receiver joins via FCM - we only get initiator's name
                val currentUserDisplayName = getCurrentUserDisplayName()
                if (currentUserDisplayName != null) {
                    uidToUsernameMap[uid] = currentUserDisplayName
                    myUsername = currentUserDisplayName
                    AppLogger.i(TAG, "✅ Stored current user's display name in mapping: $uid -> $currentUserDisplayName")
                } else {
                    AppLogger.w(TAG, "⚠️ No username available for UID: $uid")
                }
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
                
                // Mark as actively joined (after successful connection)
                callStatePersistence.markCallAsJoined(channelId)
                
                AppLogger.i(TAG, "✅ Successfully joined walkie-talkie channel: $channelName")
            } else {
                AppLogger.e(TAG, "❌ Failed to join walkie-talkie channel: $channelName")
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error joining walkie-talkie channel", e)
        }
    }
    
    /**
     * Leave current walkie-talkie channel
     */
    private fun leaveCurrentChannel() {
        try {
            if (isChannelActive && currentChannelId != null) {
                AppLogger.i(TAG, "📻 Leaving walkie-talkie channel: $currentChannelName")
                
                // Leave Agora channel
                agoraCallManager.leaveCall("Walkie-talkie channel disconnection")
                
                // Dismiss call UI and show disconnection notification with user's name
                CallUITrigger.dismissCallUI()
                notificationManager.showDisconnectionNotification(myUsername ?: "You")
                AppLogger.i(TAG, "� Dismissed UI and showed disconnection notification: ${myUsername ?: "You"} over")
                
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
                AppLogger.i(TAG, "✅ Left walkie-talkie channel - stopping service")
                stopSelf()
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error leaving walkie-talkie channel", e)
        }
    }
    
    /**
     * Leave current channel silently without triggering UI/notifications (for empty channels)
     */
    private fun leaveCurrentChannelSilently() {
        try {
            if (isChannelActive && currentChannelId != null) {
                AppLogger.i(TAG, "🤫 Leaving empty walkie-talkie channel silently: $currentChannelName")
                
                // Leave Agora channel without UI updates
                agoraCallManager.leaveCall("Empty walkie-talkie channel - leaving silently")
                
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
                
                // Stop the service completely without any notifications
                AppLogger.i(TAG, "🤫 Left empty channel silently - stopping service")
                stopSelf()
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error leaving walkie-talkie channel silently", e)
        }
    }
    
    /**
     * Get username for a given UID, with fallback to "User [UID]"
     */
    private fun getUsernameForUid(uid: Int): String {
        return uidToUsernameMap[uid] ?: "User $uid"
    }
    
    /**
     * Get current user's display name from SharedPreferences or Firebase Auth
     * This is used when the receiver joins but we only have initiator's info from FCM
     */
    private fun getCurrentUserDisplayName(): String? {
        return try {
            // Get from SharedPreferences (should be set by Flutter when user logs in)
            val prefs = getSharedPreferences("call_state_prefs", MODE_PRIVATE)
            val cachedName = prefs.getString("current_user_display_name", null)
            
            if (!cachedName.isNullOrBlank()) {
                AppLogger.d(TAG, "Got current user display name from cache: $cachedName")
                return cachedName
            }
            
            AppLogger.w(TAG, "Could not get current user display name from SharedPreferences")
            null
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error getting current user display name: ${e.message}")
            null
        }
    }
    
    /**
     * Create event listener for service-managed walkie-talkie events
     */
    private fun createServiceEventListener(channelId: String): AgoraService.AgoraEventListener {
        return object : AgoraService.AgoraEventListener {
            override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
                AppLogger.i(TAG, "✅ Service: Walkie-talkie channel joined: $channel (uid: $uid)")
                callStatePersistence.markCallAsJoined(channelId)
                
                // 👥 OCCUPANCY CHECK FOR WALKIE-TALKIE: Use walkie-talkie specific logic
                AppLogger.i(TAG, "🔍 Starting walkie-talkie occupancy check for channel: $channel")
                occupancyManager.checkWalkieTalkieOccupancy(
                    channelId = channel,
                    isInitiator = false, // For now, assume all FCM-triggered joins are listeners
                    onChannelOccupied = { userCount ->
                        AppLogger.i(TAG, "✅ Channel has $userCount users - proceeding with normal walkie-talkie flow")
                        
                        // 🚨 CRITICAL: Only show notification/UI after occupancy check passes
                        AppLogger.i(TAG, "📢 OCCUPANCY CHECK PASSED - Now showing notification/UI for walkie-talkie")
                        
                        // Show notification that someone is speaking in walkie-talkie
                        val speakerName = lastSpeakerUsername ?: "Someone"
                        val speakerPhotoUrl = callStatePersistence.getCurrentCallData()?.callerPhoto
                        
                        notificationManager.showSpeakingNotification(speakerName, speakerPhotoUrl)
                        AppLogger.i(TAG, "📢 Showing walkie-talkie speaking notification: $speakerName")
                        
                        // Trigger call UI for walkie-talkie calls with actual mute state and photo
                        val callerName = lastSpeakerUsername ?: "Walkie-Talkie Call"
                        
                        // Get caller photo from persisted call data
                        val callerPhoto = callStatePersistence.getCurrentCallData()?.callerPhoto
                        
                        // Get the actual mute state from AgoraService
                        val isMuted = AgoraServiceManager.getAgoraService()?.isMicrophoneMuted() ?: true
                        
                        CallUITrigger.showCallUI(callerName, callerPhoto, isMuted)
                        AppLogger.i(TAG, "🎯 Triggered call UI for walkie-talkie: $callerName (photo: ${if (callerPhoto.isNullOrEmpty()) "none" else "present"}, muted: $isMuted)")
                    },
                    onChannelEmpty = {
                        AppLogger.i(TAG, "🏃‍♂️ OCCUPANCY CHECK FAILED - Channel is empty, leaving silently without notifications/UI")
                        
                        // Leave channel silently without triggering notifications or UI
                        leaveCurrentChannelSilently()
                    }
                )
            }
            
            override fun onLeaveChannel() {
                AppLogger.i(TAG, "📻 Service: Left walkie-talkie channel: $channelId")
                
                // Dismiss call UI when leaving channel
                CallUITrigger.dismissCallUI()
                AppLogger.i(TAG, "🎯 Dismissed call UI for walkie-talkie leave")
                
                // Show disconnection notification with user's name
                notificationManager.showDisconnectionNotification(myUsername ?: "You")
                AppLogger.i(TAG, "� Showed disconnection notification: ${myUsername ?: "You"} over")
                
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
                AppLogger.i(TAG, "🛑 Left channel - stopping service")
                stopSelf()
            }
            
            override fun onUserJoined(uid: Int, elapsed: Int) {
                AppLogger.i(TAG, "👤 Service: User joined walkie-talkie: $uid")
                // Note: We don't have username info for users who join later
                // This would need to be provided via a separate mechanism
            }
            
            override fun onUserOffline(uid: Int, reason: Int) {
                AppLogger.i(TAG, "👋 Service: User left walkie-talkie: $uid (lastSpeakerUid: $lastSpeakerUid, myUid: $myUid)")
                
                // Clear any existing speaking notification first
                notificationManager.clearSpeakingNotification()
                AppLogger.i(TAG, "🧹 Cleared speaking notification before showing leave notification")
                
                // Only show "over" notification on receiver's phone, not on initiator's phone
                // Check if current user is the receiver (not the initiator who sent the call)
                val isCurrentUserInitiator = (lastSpeakerUid != 0 && lastSpeakerUid == myUid)
                
                if (!isCurrentUserInitiator) {
                    // Current user is the receiver - show the "over" notification with initiator's name
                    val initiatorName = if (lastSpeakerUsername != null) {
                        lastSpeakerUsername!!
                    } else {
                        // Fallback: try to get the best available username
                        if (uid != myUid) {
                            getUsernameForUid(uid)
                        } else {
                            // If self is leaving and we don't have initiator name, try to find the other user's name
                            val otherUserName = uidToUsernameMap.values.firstOrNull { it != myUsername }
                            otherUserName ?: "Call"
                        }
                    }
                    
                    AppLogger.i(TAG, "📻 Showing 'over' notification on receiver's phone: $initiatorName (leaving UID: $uid)")
                    notificationManager.showDisconnectionNotification(initiatorName)
                    AppLogger.i(TAG, "📢 Showing disconnection notification for: $initiatorName")
                } else {
                    AppLogger.i(TAG, "👤 Current user is initiator - not showing 'over' notification")
                }
                
                // Clear speaker info after showing the leave notification
                lastSpeakerUid = 0
                lastSpeakerUsername = null
                AppLogger.i(TAG, "🧹 Cleared speaker info after user left")
                
                // Remove from username mapping
                uidToUsernameMap.remove(uid)
            }
            
            override fun onMicrophoneToggled(isMuted: Boolean) {
                AppLogger.d(TAG, "🎤 Service: Walkie-talkie mic toggled: $isMuted (my UID: $myUid)")
                // Service notification updates removed - only showing speaking/over notifications
            }
            
            override fun onSpeakerToggled(isEnabled: Boolean) {
                AppLogger.d(TAG, "🔊 Service: Speaker toggled in walkie-talkie: $isEnabled")
            }
            
            override fun onError(errorCode: Int, errorMessage: String) {
                AppLogger.e(TAG, "❌ Service: Walkie-talkie error: $errorCode - $errorMessage")
            }
            
            override fun onAllUsersLeft() {
                AppLogger.i(TAG, "👥 Service: All users left walkie-talkie")
                
                // Stop the service when everyone leaves
                AppLogger.i(TAG, "🛑 All users left - stopping service")
                stopSelf()
            }
            
            override fun onChannelEmpty() {
                AppLogger.i(TAG, "🏠 Service: Walkie-talkie channel empty")
            }
            
            override fun onUserSpeaking(uid: Int, volume: Int, isSpeaking: Boolean) { 
                AppLogger.d(TAG, "🎤 Service: Agora detected user $uid speaking: $isSpeaking (volume: $volume)")
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
            AppLogger.d(TAG, "✅ Wake lock acquired")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error acquiring wake lock", e)
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
                    AppLogger.d(TAG, "✅ Wake lock released")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error releasing wake lock", e)
        }
    }
}