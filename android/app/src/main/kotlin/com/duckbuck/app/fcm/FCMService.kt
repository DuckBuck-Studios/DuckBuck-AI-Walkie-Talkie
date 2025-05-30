package com.duckbuck.app.fcm

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.duckbuck.app.AgoraServiceHolder
import com.duckbuck.app.MainActivity
import com.duckbuck.app.R
import com.duckbuck.app.agora.AgoraService

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.net.URL

/**
 * Native FCM Service that handles ONLY data-only notifications
 * 
 * This service is designed to work alongside Flutter FCM handling by:
 * - Only processing messages that contain ONLY data (no notification field)
 * - Ignoring any messages with notification payloads (let Flutter handle those)
 * - Managing foreground service lifecycle based on app state changes during active calls
 */
class FCMService : FirebaseMessagingService(), DefaultLifecycleObserver {
    
    companion object {
        private const val TAG = "FCMService"
        private const val CALL_NOTIFICATION_CHANNEL_ID = "speaking_notification_channel"
        private const val CALL_NOTIFICATION_ID = 2001
        
        // SharedPreferences keys for persistent call data
        private const val CALL_PREFS_NAME = "active_call_data"
        private const val PREF_IS_IN_CALL = "is_in_active_call"
        private const val PREF_AGORA_TOKEN = "agora_token"
        private const val PREF_AGORA_UID = "agora_uid"
        private const val PREF_CHANNEL_ID = "agora_channel_id"
        private const val PREF_CALL_NAME = "caller_name"
        private const val PREF_CALLER_PHOTO = "caller_photo"
        private const val PREF_JOIN_TIMESTAMP = "join_timestamp"
    }

    private var agoraService: AgoraService? = null
    private var notificationManager: NotificationManager? = null
    private var isInActiveCall = false
    private var currentCallData: CallData? = null
    private lateinit var callPrefs: SharedPreferences
    
    // Track remote users in the channel
    private val remoteUsersInChannel = mutableSetOf<Int>()
    private var myUid: Int = -1
    
    data class CallData(
        val token: String,
        val uid: Int,
        val channelId: String,
        val callName: String,
        val callerPhoto: String?
    )

    override fun onCreate() {
        super<FirebaseMessagingService>.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        callPrefs = getSharedPreferences(CALL_PREFS_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()
        
        Log.i(TAG, "🚀 FCM Service created")
        
        // Register lifecycle observer to detect app backgrounding during calls
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)
        
        // Try to get AgoraService from the holder first (which should be initialized by MainActivity)
        agoraService = AgoraServiceHolder.getAgoraService()
        
        if (agoraService != null) {
            Log.i(TAG, "✅ Using existing AgoraService from MainActivity")
            agoraService?.setEventListener(agoraEventListener)
        } else {
            // If no shared instance exists, create a new one
            Log.w(TAG, "⚠️ No shared AgoraService found, initializing locally")
            agoraService = AgoraService(this).apply {
                val initResult = initializeEngine()
                if (initResult) {
                    Log.i(TAG, "✅ Agora RTC Engine initialized successfully in FCMService")
                    // Store in holder for future use
                    AgoraServiceHolder.setAgoraService(this)
                } else {
                    Log.e(TAG, "❌ Failed to initialize Agora RTC Engine in FCMService")
                }
                setEventListener(agoraEventListener)
            }
        }
        
        // Restore call state from SharedPreferences if exists
        restoreCallStateFromPreferences()
    }
    
    override fun onDestroy() {
        super<FirebaseMessagingService>.onDestroy()
        ProcessLifecycleOwner.get().lifecycle.removeObserver(this)
        
        // Clean up our event listener but don't destroy the engine since it might be used by MainActivity
        agoraService?.removeEventListener()
        // Don't destroy the Agora engine if it's the shared instance
        
        // Don't clear preferences on destroy - service might be restarted
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        Log.d(TAG, "Message received from: ${remoteMessage.from}")
        Log.d(TAG, "Message ID: ${remoteMessage.messageId}")
        Log.d(TAG, "Message data: ${remoteMessage.data}")
        
        // CRITICAL: Only handle data-only messages (no notification field)
        if (remoteMessage.notification != null) {
            Log.d(TAG, "Message contains notification field - ignoring (Flutter will handle)")
            return
        }
        
        // Only process if message contains data
        if (remoteMessage.data.isEmpty()) {
            Log.d(TAG, "Message contains no data - ignoring")
            return
        }
        
        Log.i(TAG, "Processing data-only message with data: ${remoteMessage.data}")
        
        // Check if this is an incoming call notification
        val agoraToken = remoteMessage.data["agora_token"]
        val agoraUid = remoteMessage.data["agora_uid"]?.toIntOrNull()
        val agoraChannelId = remoteMessage.data["agora_channelid"]
        val callName = remoteMessage.data["call_name"]
        val callerPhoto = remoteMessage.data["caller_photo"]
        
        if (agoraToken != null && agoraUid != null && agoraChannelId != null && callName != null) {
            Log.i(TAG, "Auto-join call notification received")
            handleAutoJoinCall(agoraToken, agoraUid, agoraChannelId, callName, callerPhoto)
        } else {
            // Other data-only messages are ignored
            Log.d(TAG, "Data-only message does not contain auto-join call parameters - ignoring")
        }
    }
    
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token received (handled by Flutter): ${token.take(10)}...")
        // Let Flutter handle token registration - don't interfere
    }
    
    /**
     * Handle auto-join call notifications - optimized for speed
     */
    private fun handleAutoJoinCall(token: String, uid: Int, channelId: String, callName: String, callerPhoto: String?) {
        Log.i(TAG, "=== AUTO-JOIN CALL (SPEED OPTIMIZED) ===")
        Log.i(TAG, "Channel: $channelId, Speaker: $callName")
        
        val appState = getAppState()
        Log.i(TAG, "App state: $appState")
        
        when (appState) {
            AppState.FOREGROUND -> {
                // App is in foreground - join call immediately, no foreground service needed YET
                joinCallImmediately(token, uid, channelId, callName, callerPhoto)
                // Store call data in case user backgrounds the app
                currentCallData = CallData(token, uid, channelId, callName, callerPhoto)
            }
            AppState.BACKGROUND -> {
                // App is in background - join call first for speed, then start service
                joinCallImmediately(token, uid, channelId, callName, callerPhoto)
                startForegroundServiceInBackground(token, uid, channelId, callName, callerPhoto)
                showSpeakingNotification(callName, callerPhoto, channelId)
                currentCallData = CallData(token, uid, channelId, callName, callerPhoto)
                // Store call data persistently for background state
                saveCallDataToPreferences(token, uid, channelId, callName, callerPhoto)
            }
            AppState.KILLED -> {
                // App is completely killed - need special handling
                handleKilledStateCall(token, uid, channelId, callName, callerPhoto)
            }
        }
    }
    
    /**
     * Handle call when app is in KILLED state - requires special approach
     */
    private fun handleKilledStateCall(token: String, uid: Int, channelId: String, callName: String, callerPhoto: String?) {
        Log.i(TAG, "💀 KILLED STATE: Handling call when app is completely killed")
        
        try {
            // 1. IMMEDIATELY start foreground service to prevent FCM service from being killed
            startForegroundServiceInBackground(token, uid, channelId, callName, callerPhoto)
            
            // 2. Show notification to bring user back to app
            showSpeakingNotification(callName, callerPhoto, channelId)
            
            // 3. Try to join call, but with more robust error handling since main app isn't running
            joinCallWithKilledStateHandling(token, uid, channelId, callName, callerPhoto)
            
            // 4. Store call data (though lifecycle observer won't work in killed state)
            currentCallData = CallData(token, uid, channelId, callName, callerPhoto)
            // Store call data persistently for killed state - CRITICAL for recovery
            saveCallDataToPreferences(token, uid, channelId, callName, callerPhoto)
            
            Log.i(TAG, "💀 KILLED STATE: Call handling initiated - user needs to open app to participate")
            
        } catch (e: Exception) {
            Log.e(TAG, "💀 KILLED STATE: Error handling killed state call", e)
            // Fallback: at least show notification so user knows someone is speaking
            showSpeakingNotification(callName, callerPhoto, channelId)
        }
    }
    
    /**
     * Join call with special handling for killed state
     */
    private fun joinCallWithKilledStateHandling(token: String, uid: Int, channelId: String, callName: String, callerPhoto: String?) {
        try {
            // First check for a shared instance from MainActivity or holder
            if (agoraService == null) {
                Log.w(TAG, "💀 KILLED STATE: AgoraService is null, checking for shared instance")
                agoraService = AgoraServiceHolder.getAgoraService()
                
                if (agoraService == null) {
                    Log.w(TAG, "💀 KILLED STATE: No shared instance, creating new AgoraService")
                    agoraService = AgoraService(this).apply {
                        val initResult = initializeEngine()
                        if (initResult) {
                            Log.i(TAG, "💀 KILLED STATE: AgoraService initialized successfully")
                            // Store in holder for potential future use
                            AgoraServiceHolder.setAgoraService(this)
                        } else {
                            Log.e(TAG, "💀 KILLED STATE: Failed to initialize AgoraService")
                            return@joinCallWithKilledStateHandling
                        }
                        setEventListener(agoraEventListener)
                    }
                } else {
                    Log.i(TAG, "💀 KILLED STATE: Using shared AgoraService instance")
                    agoraService?.setEventListener(agoraEventListener)
                }
            } else if (!agoraService!!.isEngineInitialized()) {
                Log.w(TAG, "💀 KILLED STATE: RTC Engine not initialized, attempting to reinitialize")
                val initResult = agoraService!!.initializeEngine()
                if (!initResult) {
                    Log.e(TAG, "💀 KILLED STATE: Failed to reinitialize RTC Engine")
                    return
                }
                Log.i(TAG, "💀 KILLED STATE: RTC Engine reinitialized successfully")
                
                // Add delay after initialization
                try {
                    Thread.sleep(300) // Give engine time to fully initialize
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                }
            }
            
            val joinResult = agoraService!!.joinChannel(channelId, token, uid)
            if (joinResult) {
                agoraService!!.turnMicrophoneOff()
                isInActiveCall = true
                myUid = uid // Store our UID
                Log.i(TAG, "💀✅ KILLED STATE: Successfully joined channel: $channelId (silent mode, UID: $uid)")
            } else {
                Log.e(TAG, "💀❌ KILLED STATE: Failed to join channel: $channelId")
                // In killed state, it's more important to notify user than to force join
            }
        } catch (e: Exception) {
            Log.e(TAG, "💀❌ KILLED STATE: Error joining call in killed state", e)
            // Don't crash - prioritize showing notification over joining call
        }
    }
    
    /**
     * Join Agora call immediately for maximum speed
     */
    private fun joinCallImmediately(token: String, uid: Int, channelId: String, callName: String, callerPhoto: String?) {
        try {
            // First check for a shared instance from MainActivity
            if (agoraService == null) {
                Log.w(TAG, "⚠️ FAST JOIN: AgoraService is null, checking for shared instance")
                agoraService = AgoraServiceHolder.getAgoraService()
                
                if (agoraService != null) {
                    Log.i(TAG, "✅ FAST JOIN: Obtained shared AgoraService instance")
                    // Set our event listener on the shared instance
                    agoraService?.setEventListener(agoraEventListener)
                } else {
                    Log.e(TAG, "❌ FAST JOIN: No shared AgoraService available, creating new instance")
                    // Create a new service as last resort
                    agoraService = AgoraService(this)
                }
            }
            
            // Double check we have a service now
            if (agoraService == null) {
                Log.e(TAG, "❌ FAST JOIN: Failed to obtain AgoraService instance")
                return
            }
            
            // Ensure RTC engine is initialized before joining
            if (!agoraService!!.isEngineInitialized()) {
                Log.w(TAG, "⚠️ FAST JOIN: RTC Engine not initialized, attempting to reinitialize")
                
                // First try getting a fresh instance from the holder
                val holderInstance = AgoraServiceHolder.getAgoraService()
                if (holderInstance != null && holderInstance.isEngineInitialized()) {
                    Log.i(TAG, "✅ FAST JOIN: Found initialized Agora instance from holder")
                    agoraService = holderInstance
                    agoraService?.setEventListener(agoraEventListener)
                } else {
                    // Need to re-initialize this instance
                    val initResult = agoraService!!.initializeEngine()
                    if (!initResult) {
                        Log.e(TAG, "❌ FAST JOIN: Failed to reinitialize RTC Engine")
                        return
                    }
                    Log.i(TAG, "✅ FAST JOIN: RTC Engine reinitialized successfully")
                    
                    // Important: Make sure the event handler is registered
                    agoraService?.setEventListener(agoraEventListener)
                    
                    // Brief delay to ensure the engine is fully ready before joining
                    try {
                        Thread.sleep(300) 
                    } catch (e: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
                
                // Double-check that engine is initialized
                if (!agoraService!!.isEngineInitialized()) {
                    Log.e(TAG, "❌ FAST JOIN: Engine not properly initialized after delay")
                    
                    // Try a completely different approach - create a new instance with new configurations
                    Log.w(TAG, "⚠️ FAST JOIN: Using direct RtcEngine creation as fallback")
                    
                    try {
                        // First make sure to clean up any existing instances
                        agoraService?.destroy()
                        
                        // Direct RtcEngine creation bypassing our service wrapper
                        val config = io.agora.rtc2.RtcEngineConfig()
                        config.mContext = applicationContext
                        config.mAppId = "3983e52a08424b7da5e79be4c9dfae0f" // Same APP_ID as in AgoraService
                        config.mEventHandler = object : io.agora.rtc2.IRtcEngineEventHandler() {
                            // Minimal handler implementation
                        }
                        
                        // Create engine directly
                        val directEngine = io.agora.rtc2.RtcEngine.create(config)
                        
                        if (directEngine != null) {
                            Log.i(TAG, "✅ FAST JOIN: Created direct RtcEngine instance successfully")
                            
                            // Configure the direct engine
                            directEngine.enableAudio()
                            directEngine.setAudioProfile(
                                io.agora.rtc2.Constants.AUDIO_PROFILE_DEFAULT,
                                io.agora.rtc2.Constants.AUDIO_SCENARIO_CHATROOM
                            )
                            
                            // Now recreate our service with this engine
                            agoraService = AgoraService(applicationContext)
                            val resetSuccess = agoraService!!.initializeEngine()
                            
                            if (resetSuccess) {
                                Log.i(TAG, "✅ FAST JOIN: Service recreated with new engine")
                                agoraService!!.setEventListener(agoraEventListener)
                                AgoraServiceHolder.setAgoraService(agoraService!!)
                            } else {
                                Log.e(TAG, "❌ FAST JOIN: Failed to reinitialize service with direct engine")
                                return
                            }
                        } else {
                            Log.e(TAG, "❌ FAST JOIN: Direct engine creation failed")
                            return
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ FAST JOIN: Error during Agora service reset", e)
                        return
                    }
                }
            }
            
            // Prepare for joining by ensuring microphone will be muted
            // Do this before joining because it's more reliable
            agoraService!!.turnMicrophoneOff()
            
            // Join the Agora channel IMMEDIATELY for speed
            Log.i(TAG, "🔗 FAST JOIN: Joining channel: $channelId with UID: $uid")
            val joinResult = agoraService!!.joinChannel(channelId, token, uid)
            
            if (joinResult) {
                isInActiveCall = true
                myUid = uid // Store our UID
                Log.i(TAG, "✅ FAST JOIN: Successfully joined channel: $channelId")
                
                // Double-check the microphone is muted
                agoraService!!.turnMicrophoneOff()
                Log.i(TAG, "✅ FAST JOIN: Successfully joined channel: $channelId with muted mic (UID: $uid)")
            } else {
                Log.e(TAG, "❌ FAST JOIN: Failed to join channel: $channelId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ FAST JOIN: Error joining call immediately", e)
        }
    }
    
    /**
     * Public method to manually leave channel (can be called from Flutter)
     */
    fun leaveChannelManually() {
        Log.i(TAG, "📱 MANUAL LEAVE: User requested to leave channel")
        leaveChannelAndCleanup("User manually left")
    }
    
    /**
     * Public method to check if currently in a call
     */
    fun isCurrentlyInCall(): Boolean {
        return isInActiveCall
    }
    
    /**
     * Public method to get current call data
     */
    fun getCurrentCallData(): CallData? {
        return currentCallData ?: getSavedCallData()
    }
    
    /**
     * Save call data to SharedPreferences for persistence across service restarts
     */
    private fun saveCallDataToPreferences(token: String, uid: Int, channelId: String, callName: String, callerPhoto: String?) {
        try {
            callPrefs.edit().apply {
                putBoolean(PREF_IS_IN_CALL, true)
                putString(PREF_AGORA_TOKEN, token)
                putInt(PREF_AGORA_UID, uid)
                putString(PREF_CHANNEL_ID, channelId)
                putString(PREF_CALL_NAME, callName)
                putString(PREF_CALLER_PHOTO, callerPhoto ?: "")
                putLong(PREF_JOIN_TIMESTAMP, System.currentTimeMillis())
                apply()
            }
            Log.i(TAG, "💾 Call data saved to SharedPreferences: $callName in $channelId")
        } catch (e: Exception) {
            Log.e(TAG, "💾❌ Error saving call data to preferences", e)
        }
    }
    
    /**
     * Restore call state from SharedPreferences if exists
     */
    private fun restoreCallStateFromPreferences() {
        try {
            val isInCall = callPrefs.getBoolean(PREF_IS_IN_CALL, false)
            if (isInCall) {
                val token = callPrefs.getString(PREF_AGORA_TOKEN, null)
                val uid = callPrefs.getInt(PREF_AGORA_UID, -1)
                val channelId = callPrefs.getString(PREF_CHANNEL_ID, null)
                val callName = callPrefs.getString(PREF_CALL_NAME, null)
                val callerPhoto = callPrefs.getString(PREF_CALLER_PHOTO, null)?.takeIf { it.isNotEmpty() }
                val joinTimestamp = callPrefs.getLong(PREF_JOIN_TIMESTAMP, 0)
                
                // Check if call data is valid and not too old (e.g., more than 30 minutes)
                val callAge = System.currentTimeMillis() - joinTimestamp
                val maxCallAge = 30 * 60 * 1000L // 30 minutes
                
                if (token != null && uid != -1 && channelId != null && callName != null && callAge < maxCallAge) {
                    Log.i(TAG, "🔄 Restoring call state from preferences: $callName in $channelId")
                    currentCallData = CallData(token, uid, channelId, callName, callerPhoto)
                    isInActiveCall = true
                    
                    // Try to rejoin the call if possible
                    val appState = getAppState()
                    if (appState != AppState.FOREGROUND) {
                        // Only auto-rejoin if app is not in foreground
                        Log.i(TAG, "🔄 Attempting to rejoin call from restored state")
                        joinCallImmediately(token, uid, channelId, callName, callerPhoto)
                        startForegroundServiceInBackground(token, uid, channelId, callName, callerPhoto)
                    }
                } else {
                    Log.i(TAG, "🔄 Call data in preferences is invalid or too old, clearing")
                    clearCallDataFromPreferences()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "🔄❌ Error restoring call state from preferences", e)
            clearCallDataFromPreferences()
        }
    }
    
    /**
     * Clear call data from SharedPreferences
     */
    private fun clearCallDataFromPreferences() {
        try {
            callPrefs.edit().clear().apply()
            Log.i(TAG, "🗑️ Call data cleared from SharedPreferences")
        } catch (e: Exception) {
            Log.e(TAG, "🗑️❌ Error clearing call data from preferences", e)
        }
    }
    
    /**
     * Get saved call data from SharedPreferences
     */
    private fun getSavedCallData(): CallData? {
        return try {
            val isInCall = callPrefs.getBoolean(PREF_IS_IN_CALL, false)
            if (isInCall) {
                val token = callPrefs.getString(PREF_AGORA_TOKEN, null)
                val uid = callPrefs.getInt(PREF_AGORA_UID, -1)
                val channelId = callPrefs.getString(PREF_CHANNEL_ID, null)
                val callName = callPrefs.getString(PREF_CALL_NAME, null)
                val callerPhoto = callPrefs.getString(PREF_CALLER_PHOTO, null)?.takeIf { it.isNotEmpty() }
                
                if (token != null && uid != -1 && channelId != null && callName != null) {
                    CallData(token, uid, channelId, callName, callerPhoto)
                } else null
            } else null
        } catch (e: Exception) {
            Log.e(TAG, "Error getting saved call data", e)
            null
        }
    }
    
    /**
     * Start this service as foreground service for call management
     */
    @Suppress("UNUSED_PARAMETER")
    private fun startForegroundServiceInBackground(token: String, uid: Int, channelId: String, callName: String, callerPhoto: String?) {
        try {
            // Start this FCM service as a foreground service for call management
            val notification = createCallForegroundNotification(callName, channelId, callerPhoto)
            startForeground(CALL_NOTIFICATION_ID, notification)
            
            Log.i(TAG, "📱 FCM Service started as foreground service for call management")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error starting FCM service as foreground service", e)
        }
    }
    
    /**
     * Create notification for foreground service
     */
    private fun createCallForegroundNotification(callName: String, channelId: String, callerPhoto: String?): android.app.Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("auto_joined_call", true)
            putExtra("channel_id", channelId)
            putExtra("speaker_name", callName)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notificationBuilder = NotificationCompat.Builder(this, CALL_NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Active Call: $callName")
            .setContentText("Tap to return to call")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
        
        // Load caller photo if available
        if (!callerPhoto.isNullOrEmpty()) {
            try {
                CoroutineScope(Dispatchers.IO).launch {
                    val bitmap = loadImageFromUrl(callerPhoto)
                    bitmap?.let {
                        notificationBuilder.setLargeIcon(it)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading caller photo for foreground notification", e)
            }
        }
        
        return notificationBuilder.build()
    }
    
    /**
     * Show speaking notification
     */
    private fun showSpeakingNotification(callName: String, callerPhoto: String?, channelId: String) {
        val appState = getAppState()
        val isKilledState = appState == AppState.KILLED
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("auto_joined_call", true)
            putExtra("channel_id", channelId)
            putExtra("speaker_name", callName)
            if (isKilledState) {
                putExtra("from_killed_state", true)
            }
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notificationBuilder = NotificationCompat.Builder(this, CALL_NOTIFICATION_CHANNEL_ID)
            .setContentTitle(if (isKilledState) "📞 $callName is calling" else "$callName is speaking")
            .setContentText(if (isKilledState) "Tap to join the call" else "Tap to join the conversation")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, isKilledState) // Full screen for killed state
        
        if (isKilledState) {
            // More prominent notification for killed state
            notificationBuilder
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVibrate(longArrayOf(0, 250, 250, 250))
        }
        
        // Load caller photo if available
        if (!callerPhoto.isNullOrEmpty()) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val bitmap = loadImageFromUrl(callerPhoto)
                    bitmap?.let {
                        notificationBuilder.setLargeIcon(it)
                        notificationManager?.notify(CALL_NOTIFICATION_ID, notificationBuilder.build())
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error loading caller photo", e)
                    notificationManager?.notify(CALL_NOTIFICATION_ID, notificationBuilder.build())
                }
            }
        } else {
            notificationManager?.notify(CALL_NOTIFICATION_ID, notificationBuilder.build())
        }
    }
    
    /**
     * Load image from URL
     */
    private suspend fun loadImageFromUrl(url: String): Bitmap? {
        return try {
            val connection = URL(url).openConnection()
            connection.doInput = true
            connection.connect()
            val inputStream = connection.getInputStream()
            BitmapFactory.decodeStream(inputStream)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading image from URL: $url", e)
            null
        }
    }
    
    /**
     * Get current app state
     */
    private fun getAppState(): AppState {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningProcesses = activityManager.runningAppProcesses
        
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
    
    /**
     * Create notification channel for speaking notifications
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CALL_NOTIFICATION_CHANNEL_ID,
                "Speaking Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when someone is speaking"
                enableVibration(true)
                setSound(null, null) // Use default notification sound
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    /**
     * Leave channel and perform cleanup
     */
    private fun leaveChannelAndCleanup(reason: String) {
        Log.i(TAG, "🚪 LEAVING CHANNEL: $reason")
        
        try {
            // Leave Agora channel
            agoraService?.leaveChannel()
            
            // Perform complete cleanup
            performCompleteCallCleanup(reason)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during channel leave", e)
            // Still perform cleanup even if leave fails
            performCompleteCallCleanup("Error during leave: ${e.message}")
        }
    }
    
    /**
     * Perform complete call cleanup - works in all app states
     */
    private fun performCompleteCallCleanup(reason: String) {
        Log.i(TAG, "🧹 COMPLETE CLEANUP: $reason")
        
        try {
            // 1. Reset local state
            isInActiveCall = false
            currentCallData = null
            remoteUsersInChannel.clear()
            myUid = -1
            
            // 2. Clear SharedPreferences
            clearCallDataFromPreferences()
            
            // 3. Cancel any ongoing notifications
            notificationManager?.cancel(CALL_NOTIFICATION_ID)
            
            // 4. Stop foreground service if it's running
            stopForegroundService()
            
            Log.i(TAG, "✅ CLEANUP COMPLETE: All call data and services cleaned up")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error during cleanup", e)
        }
    }
    
    /**
     * Stop foreground service
     */
    private fun stopForegroundService() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            Log.i(TAG, "🛑 FCM Service stopped foreground mode")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping foreground service", e)
        }
    }
    
    /**
     * Agora event listener - handles automatic leave when others leave
     */
    private val agoraEventListener = object : AgoraService.AgoraEventListener {
        override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
            Log.d(TAG, "Successfully joined Agora channel: $channel with UID: $uid")
            myUid = uid
            // Clear remote users list on fresh join
            remoteUsersInChannel.clear()
        }
        
        override fun onLeaveChannel() {
            Log.d(TAG, "Left Agora channel")
            // Complete cleanup when we leave channel
            performCompleteCallCleanup("User left channel")
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            Log.d(TAG, "🟢 Remote user joined: $uid")
            remoteUsersInChannel.add(uid)
            Log.d(TAG, "📊 Active users in channel: ${remoteUsersInChannel.size + 1} (including self)")
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "🔴 Remote user offline: $uid (reason: $reason)")
            remoteUsersInChannel.remove(uid)
            
            val remainingUsers = remoteUsersInChannel.size
            Log.d(TAG, "📊 Remaining users in channel: $remainingUsers (excluding self)")
            
            // If no other users left in channel, leave automatically
            if (remainingUsers == 0) {
                Log.i(TAG, "🚪 AUTO-LEAVE: All other users left the channel, leaving automatically")
                leaveChannelAndCleanup("All other users left")
            } else {
                Log.d(TAG, "👥 Still $remainingUsers users in channel, staying connected")
            }
        }
        
        override fun onMicrophoneToggled(isMuted: Boolean) {
            Log.d(TAG, "🎤 Microphone toggled: ${if (isMuted) "muted" else "unmuted"}")
        }
        
        override fun onVideoToggled(isEnabled: Boolean) {
            Log.d(TAG, "📹 Video toggled: ${if (isEnabled) "enabled" else "disabled"}")
        }
        
        override fun onError(errorCode: Int, errorMessage: String) {
            Log.e(TAG, "❌ Agora error: $errorMessage ($errorCode)")
            // On error, perform complete cleanup
            performCompleteCallCleanup("Agora error: $errorMessage")
        }
        
        override fun onAllUsersLeft() {
            Log.i(TAG, "👋 onAllUsersLeft: All remote users have left the channel")
            leaveChannelAndCleanup("Auto-leave: All users left")
        }
        
        override fun onChannelEmpty() {
            Log.i(TAG, "🏞️ onChannelEmpty: Channel is now empty")
            // This is a backup implementation in case onAllUsersLeft doesn't trigger properly
            leaveChannelAndCleanup("Auto-leave: Channel empty")
        }
    }
    
    // Lifecycle observer methods to handle app state changes during active calls
    override fun onStop(owner: LifecycleOwner) {
        super<DefaultLifecycleObserver>.onStop(owner)
        // App went to background - if in active call, start foreground service
        if (isInActiveCall && currentCallData != null) {
            Log.i(TAG, "🔄 App backgrounded during active call - starting foreground service")
            val callData = currentCallData!!
            startForegroundServiceInBackground(
                callData.token, 
                callData.uid, 
                callData.channelId, 
                callData.callName, 
                callData.callerPhoto
            )
        }
    }
    
    override fun onStart(owner: LifecycleOwner) {
        super<DefaultLifecycleObserver>.onStart(owner)
        // App came to foreground - we could optionally stop foreground service here
        // but it's safer to let it continue running until call ends
        if (isInActiveCall) {
            Log.i(TAG, "🔄 App returned to foreground during active call")
        }
    }
     
    enum class AppState{
        FOREGROUND,
        BACKGROUND,
        KILLED

    }
    
}
