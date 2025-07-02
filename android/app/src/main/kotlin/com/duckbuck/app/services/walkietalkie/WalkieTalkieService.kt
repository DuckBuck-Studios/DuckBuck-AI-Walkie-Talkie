package com.duckbuck.app.services.walkietalkie

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.duckbuck.app.MainActivity
import com.duckbuck.app.R
import com.duckbuck.app.services.agora.AgoraService
import com.duckbuck.app.services.notification.NotificationService
import com.duckbuck.app.services.walkietalkie.utils.TimestampValidator
import com.duckbuck.app.services.walkietalkie.utils.WalkieTalkiePrefsUtil

/**
 * WalkieTalkieService - Foreground Service for handling walkie-talkie operations
 * Processes FCM data-only notifications and maintains Agora channel connections
 * Works in all app states: killed, foreground, background
 */
class WalkieTalkieService : Service(), AgoraService.ChannelParticipantListener, AgoraService.ChannelLifecycleListener {
    
    companion object {
        private const val TAG = "WalkieTalkieService"
        private const val FOREGROUND_SERVICE_ID = 3000
        private const val CHANNEL_ID = "walkie_talkie_service"
        private const val CHANNEL_NAME = "Walkie-Talkie Service"
        
        // Intent actions
        const val ACTION_START_CALL = "START_CALL"
        const val ACTION_STOP_CALL = "STOP_CALL"
        
        // Intent extras for FCM data
        const val EXTRA_FCM_DATA = "fcm_data"
        
        // Call failure reasons
        private const val REASON_TIMESTAMP_EXPIRED = "timestamp_expired"
        private const val REASON_ALREADY_IN_CALL = "already_in_call"
        private const val REASON_CHANNEL_EMPTY = "channel_empty"
        private const val REASON_JOIN_FAILED = "join_failed"
        private const val REASON_USER_LEFT = "user_left"
        private const val REASON_EVERYONE_LEFT = "everyone_left"
        
        // Timing constants
        private const val AUTO_LEAVE_DELAY_MS = 2000L
        
        // FCM data field names
        private const val FCM_FIELD_TIMESTAMP = "timestamp"
        private const val FCM_FIELD_TYPE = "type"
        private const val FCM_FIELD_TIMESTAMP_ISO = "timestampISO"
        private const val FCM_FIELD_SERVER_TIMESTAMP = "serverTimestamp"
        private const val FCM_FIELD_PRIORITY = "priority"
        private const val FCM_FIELD_CALL_NAME = "call_name"
        private const val FCM_FIELD_CALLER_PHOTO = "caller_photo"
        private const val FCM_FIELD_AGORA_CHANNEL_ID = "agora_channelid"
        private const val FCM_FIELD_AGORA_TOKEN = "agora_token"
        private const val FCM_FIELD_AGORA_UID = "agora_uid"
        
        /**
         * Start the walkie-talkie service with FCM data
         */
        fun startWithFCMData(context: Context, fcmData: Map<String, String>) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                action = ACTION_START_CALL
                putExtra(EXTRA_FCM_DATA, HashMap(fcmData))
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            
            Log.i(TAG, "🚀 Starting WalkieTalkieService with FCM data")
        }
        
        /**
         * Stop the walkie-talkie service
         */
        fun stopService(context: Context) {
            val intent = Intent(context, WalkieTalkieService::class.java).apply {
                action = ACTION_STOP_CALL
            }
            context.startService(intent)
            Log.i(TAG, "🛑 Stopping WalkieTalkieService")
        }
    }
    
    private val timestampValidator = TimestampValidator()
    private lateinit var agoraService: AgoraService
    private lateinit var notificationService: NotificationService
    
    // Track current channel and participants for initial empty check
    private var currentChannelId: String? = null
    private val initialParticipants = mutableSetOf<Int>()
    private var hasCheckedInitialEmpty = false
    
    // Track caller information for notification
    private var currentCallerName: String? = null
    private var currentCallerPhoto: String? = null
    
    // Store call data temporarily until call is confirmed successful
    private var pendingCallData: PendingCallData? = null
    
    data class PendingCallData(
        val channelId: String,
        val callerName: String,
        val callerPhoto: String?,
        val agoraToken: String?,
        val agoraUid: String?
    )
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🔧 WalkieTalkieService onCreate")
        
        // Initialize services
        agoraService = AgoraService.getInstance(this)
        notificationService = NotificationService(this)
        
        // Create notification channel for foreground service
        createForegroundServiceChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "🎯 WalkieTalkieService onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START_CALL -> {
                val fcmData = intent.getSerializableExtra(EXTRA_FCM_DATA) as? HashMap<String, String>
                if (fcmData != null) {
                    startForegroundService()
                    handleNotificationData(fcmData)
                } else {
                    Log.e(TAG, "❌ No FCM data provided")
                    stopSelf()
                }
            }
            ACTION_STOP_CALL -> {
                stopCallAndService()
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent?.action}")
                stopSelf()
            }
        }
        
        // Return START_NOT_STICKY so service doesn't restart if killed
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "💀 WalkieTalkieService onDestroy")
        
        // Clean up resources
        leaveChannel()
        agoraService.clearChannelParticipantListener()
        agoraService.clearChannelLifecycleListener()
    }
    
    /**
     * Create notification channel for the foreground service
     */
    private fun createForegroundServiceChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Handles ongoing walkie-talkie calls"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "✅ Foreground service notification channel created")
        }
    }
    
    /**
     * Start the service in foreground mode
     */
    private fun startForegroundService() {
        val notification = createForegroundServiceNotification()
        startForeground(FOREGROUND_SERVICE_ID, notification)
        Log.i(TAG, "🚀 Started as foreground service")
    }
    
    /**
     * Create foreground service notification
     */
    private fun createForegroundServiceNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_call_notification)
            .setContentTitle("Walkie-Talkie Service")
            .setContentText("Handling incoming call...")
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
    
    /**
     * Stop the call and service
     */
    private fun stopCallAndService() {
        Log.i(TAG, "🛑 Stopping call and service")
        leaveChannel()
        stopForeground(true)
        stopSelf()
    }
    
    /**
     * Handle notification data from FCM data-only notifications
     * Processes all walkie-talkie related data based on the payload
     */
    fun handleNotificationData(data: Map<String, String>) {
        try {
            Log.i(TAG, "📻 Processing walkie-talkie notification data")
            Log.d(TAG, "📻 Data: $data")
            
            // Extract timestamp and validate first
            val timestamp = data[FCM_FIELD_TIMESTAMP]
            
            // Validate timestamp - reject if older than 25 seconds
            if (!timestampValidator.isTimestampValid(timestamp)) {
                Log.w(TAG, "🚫 Rejecting notification - timestamp validation failed")
                Log.d(TAG, "🚫 Timestamp difference: ${timestampValidator.getTimestampDifference(timestamp)}")
                
                // Clear SharedPreferences - call failed due to old timestamp
                WalkieTalkiePrefsUtil.clearCallFailed(this, REASON_TIMESTAMP_EXPIRED)
                
                return // Exit early - don't process expired notification
            }
            
            Log.i(TAG, "✅ Timestamp validation passed - processing notification")
            
            // Check if user is already connected to a channel
            if (agoraService.isChannelConnected()) {
                val currentChannel = agoraService.getCurrentChannelName()
                Log.w(TAG, "🚫 Rejecting new call invite - user already connected to channel: $currentChannel")
                Log.d(TAG, "🚫 Cannot interrupt ongoing call with new invite")
                
                // Clear SharedPreferences - call failed due to already in call
                WalkieTalkiePrefsUtil.clearCallFailed(this, REASON_ALREADY_IN_CALL)
                
                return // Exit early - don't interrupt ongoing call
            }
            
            Log.i(TAG, "✅ No active channel connection - proceeding with invite")
            
            // Extract all the data fields that backend sends
            val type = data[FCM_FIELD_TYPE] // "data_only"
            val priority = data[FCM_FIELD_PRIORITY] // "high"
            // Invite-specific data (if present)
            val callName = data[FCM_FIELD_CALL_NAME]
            val callerPhoto = data[FCM_FIELD_CALLER_PHOTO]
            val agoraChannelId = data[FCM_FIELD_AGORA_CHANNEL_ID]
            val agoraToken = data[FCM_FIELD_AGORA_TOKEN]
            val agoraUid = data[FCM_FIELD_AGORA_UID]
            
            Log.d(TAG, "📻 Type: $type, Priority: $priority")
            Log.d(TAG, "📻 Timestamp: $timestamp")
            
            // Check if this is an invite notification
            if (callName != null && callerPhoto != null && agoraChannelId != null) {
                Log.i(TAG, "📞 Processing invite data")
                Log.d(TAG, "📞 Caller: $callName")
                Log.d(TAG, "📞 Channel: $agoraChannelId")
                Log.d(TAG, "📞 Agora Token: ${if (agoraToken != null) "Present" else "Not provided"}")
                Log.d(TAG, "📞 Agora UID: $agoraUid")
                
                // Handle invite and join channel
                handleInviteAndJoinChannel(agoraChannelId, agoraToken, agoraUid, callName, callerPhoto)
            } else {
                Log.i(TAG, "📊 Processing other walkie-talkie data")
                // Handle other walkie-talkie data types here if needed in the future
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing walkie-talkie notification data", e)
        }
    }
    
    /**
     * Handle invite and join Agora channel
     * Works for all app states: foreground, background, killed
     */
    private fun handleInviteAndJoinChannel(channelId: String, token: String?, uidString: String?, callerName: String, callerPhoto: String?) {
        try {
            val uid = uidString?.toIntOrNull() ?: 0
            
            Log.i(TAG, "🎯 Joining Agora channel for invite")
            Log.d(TAG, "🎯 Channel: $channelId, UID: $uid")
            
            // Initialize Agora engine
            if (!agoraService.initializeEngine()) {
                Log.e(TAG, "❌ Failed to initialize Agora engine")
                return
            }
            
            // Set this service as the participant listener
            agoraService.setChannelParticipantListener(this)
            
            // Set this service as the lifecycle listener
            agoraService.setChannelLifecycleListener(this)
            
            // Set speakerphone enabled for walkie-talkie experience
            agoraService.setSpeakerphoneEnabled(true)
            
            // Set this service as the participant listener for empty channel detection
            agoraService.setChannelParticipantListener(this)
            currentChannelId = channelId
            currentCallerName = callerName
            currentCallerPhoto = callerPhoto
            initialParticipants.clear()
            hasCheckedInitialEmpty = false
            
            // Join channel in muted state
            val joinSuccess = agoraService.joinChannel(token, channelId, uid, joinMuted = true)
            
            if (joinSuccess) {
                Log.i(TAG, "✅ Agora channel join initiated successfully")
                Log.i(TAG, "🔇 Joined in muted state with speakerphone enabled")
                Log.i(TAG, "📋 Instant empty check + WhatsApp-like auto-leave enabled")
                
                // Store call data temporarily - will save to SharedPreferences only if call succeeds
                pendingCallData = PendingCallData(channelId, callerName, callerPhoto, token, uidString)
                Log.d(TAG, "📋 Stored pending call data - performing instant empty check")
                
                // Perform instant empty channel check
                scheduleInitialEmptyChannelCheck()
            } else {
                Log.e(TAG, "❌ Failed to join Agora channel")
                currentChannelId = null
                currentCallerName = null
                currentCallerPhoto = null
                
                // Clear pending call data since join failed
                pendingCallData = null
                Log.d(TAG, "🧹 Cleared pending call data - join failed")
                
                // Clear ongoing call notification (in case it was shown)
                notificationService.clearOngoingCallNotification()
                
                // Clear SharedPreferences - call failed to join
                WalkieTalkiePrefsUtil.clearCallFailed(this, REASON_JOIN_FAILED)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 Error joining Agora channel", e)
        }
    }
    
    /**
     * Perform initial empty channel check immediately after joining
     */
    private fun scheduleInitialEmptyChannelCheck() {
        if (!hasCheckedInitialEmpty && currentChannelId != null) {
            checkInitialChannelEmpty()
        }
        Log.d(TAG, "⚡ Performing instant initial empty channel check")
    }
    
    /**
     * Check if channel is empty initially after joining
     */
    private fun checkInitialChannelEmpty() {
        hasCheckedInitialEmpty = true
        Log.d(TAG, "🔍 Initial channel empty check")
        Log.d(TAG, "🔍 Participants detected: ${initialParticipants.size}")
        
        if (initialParticipants.isEmpty()) {
            Log.w(TAG, "🚪 Channel is empty initially - leaving immediately")
            
            // Clear ongoing call notification (in case it was shown)
            notificationService.clearOngoingCallNotification()
            
            // Clear pending call data since call failed
            pendingCallData = null
            Log.d(TAG, "🧹 Cleared pending call data - channel was empty")
            
            // Clear SharedPreferences - call failed due to empty channel
            WalkieTalkiePrefsUtil.clearCallFailed(this, REASON_CHANNEL_EMPTY)
            
            leaveChannel()
        } else {
            Log.i(TAG, "👥 Channel has ${initialParticipants.size} participants - staying connected")
            Log.i(TAG, "📋 Will auto-leave if all users leave later")
            
            // Call is now successfully connected - save to SharedPreferences
            pendingCallData?.let { callData ->
                Log.i(TAG, "✅ Call confirmed successful - saving to SharedPreferences")
                WalkieTalkiePrefsUtil.saveActiveCall(
                    this, 
                    callData.channelId, 
                    callData.callerName, 
                    callData.callerPhoto, 
                    callData.agoraToken, 
                    callData.agoraUid
                )
                
                // Now show ongoing call notification
                Log.i(TAG, "📞 Showing ongoing call notification")
                notificationService.showOngoingCallNotification(callData.callerName, callData.callerPhoto)
                
                // Clear pending data as it's now saved
                pendingCallData = null
            } ?: run {
                Log.e(TAG, "❌ No pending call data available!")
            }
        }
    }
    
    /**
     * Leave the current channel
     */
    private fun leaveChannel() {
        try {
            Log.i(TAG, "🚪 Leaving channel: $currentChannelId")
            
            // Clear ongoing call notification
            notificationService.clearOngoingCallNotification()
            
            // Clear SharedPreferences - call ended (local user or others)
            WalkieTalkiePrefsUtil.clearCallEnded(this, REASON_USER_LEFT)
            
            val leaveSuccess = agoraService.leaveChannel()
            if (leaveSuccess) {
                Log.i(TAG, "✅ Successfully left channel")
            } else {
                Log.w(TAG, "⚠️ Failed to leave channel cleanly")
            }
            
            // Reset state
            currentChannelId = null
            currentCallerName = null
            currentCallerPhoto = null
            pendingCallData = null
            initialParticipants.clear()
            hasCheckedInitialEmpty = false
            
            // Stop the foreground service
            stopCallAndService()
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 Error leaving channel", e)
        }
    }
    
    /**
     * Called when a user joins the channel (callback from AgoraService)
     */
    override fun onUserJoined(uid: Int) {
        Log.d(TAG, "👤 User joined channel: $uid")
        
        // Track for initial empty check
        if (!hasCheckedInitialEmpty) {
            initialParticipants.add(uid)
            Log.d(TAG, "📋 Added to initial participants: $uid (Total: ${initialParticipants.size})")
        }
        
        // AgoraService handles the ongoing auto-leave logic
    }
    
    /**
     * Called when a user leaves the channel (callback from AgoraService)
     */
    override fun onUserLeft(uid: Int) {
        Log.d(TAG, "👋 User left channel: $uid")
        
        // Remove from initial participants if still checking
        if (!hasCheckedInitialEmpty) {
            initialParticipants.remove(uid)
            Log.d(TAG, "📋 Removed from initial participants: $uid (Remaining: ${initialParticipants.size})")
        }
        
        // AgoraService handles the WhatsApp-like auto-leave logic during the call
    }
    
    /**
     * Called when the channel is left (callback from AgoraService)
     */
    override fun onChannelLeft(reason: String) {
        Log.d(TAG, "🚪 Channel left with reason: $reason")
        
        // Clear ongoing call notification when auto-leave happens
        notificationService.clearOngoingCallNotification()
        
        // Reset caller information and pending data
        currentCallerName = null
        currentCallerPhoto = null
        pendingCallData = null
    }
}
