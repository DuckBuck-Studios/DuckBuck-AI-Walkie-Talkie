package com.example.duckbuck

import android.content.Intent
import android.os.Build
import android.util.Log
import android.app.KeyguardManager
import android.content.Context
import android.os.PowerManager
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import kotlin.concurrent.thread
import android.app.AlarmManager
import android.app.PendingIntent
import java.util.Timer
import java.util.TimerTask

class DuckBuckFirebaseMessagingService : FirebaseMessagingService() {
    companion object {
        private const val TAG = "DuckBuckFCM"
        private const val TYPE_ROOM_INVITATION = "roomInvitation"
        private var rtcEngine: RtcEngine? = null
        
        // Track if we're already connected to avoid multiple connections
        private var isConnectedToChannel = false
        
        // For persistent connection
        private var lastChannelName: String? = null
        private var lastToken: String? = null
        private var lastUid: Int = 0
        private var connectionTimer: Timer? = null
        
        // Flag to track if foreground service is running
        private var isForegroundServiceRunning = false
    }

    private lateinit var logger: AppLogger
    private var wakeLock: PowerManager.WakeLock? = null
    
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onError(err: Int) {
            Log.e(TAG, "Agora onError: $err")
            logger.logEvent("AgoraEvent", "Agora error", mapOf("error" to err))
            
            // Try to recover from certain errors
            if (err == 101 || // Channel join failed
                err == 109 || // Token expired 
                err == 110 || // Token invalid
                err == 8 || // General timeout
                err == 1 || // General error
                err == 2) { // Invalid argument
                
                logger.logEvent("AgoraEvent", "Recoverable error, attempting to rejoin")
                
                if (lastToken != null && lastChannelName != null && lastUid > 0) {
                    // Wait a moment before rejoining
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            connectToAgoraChannel(lastChannelName!!, lastToken!!, lastUid)
                        }
                    }, 2000)
                }
            }
        }

        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            Log.d(TAG, "Agora onJoinChannelSuccess: $channel, uid: $uid")
            isConnectedToChannel = true
            
            logger.logEvent("AgoraEvent", "Joined channel successfully", 
                mapOf("channel" to (channel ?: "Unknown"), "uid" to uid, "elapsed" to elapsed))
            
            // Save connection details for potential reconnection
            lastChannelName = channel
            lastUid = uid
            
            // Ensure the foreground service stays running with enhanced parameters
            val serviceIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                putExtra("channelName", channel ?: "Unknown")
                putExtra("token", lastToken)
                putExtra("uid", uid)
                putExtra("isConnected", true)
                putExtra("senderUid", "")  // Add reasonable default
                
                // Add flags to make sure intent is delivered
                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            }
            
            // Try to start the service with multiple approaches
            try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
                }
                isForegroundServiceRunning = true
                logger.logEvent("AgoraEvent", "Started foreground service after join success")
            } catch (e: Exception) {
                logger.logEvent("AgoraEvent", "Error starting foreground service", 
                    mapOf("error" to e.message.toString()))
                
                // As a backup, schedule the service to start via AlarmManager
                try {
                    logger.logEvent("AgoraEvent", "Scheduling service start via AlarmManager")
                    val pendingIntent = PendingIntent.getService(
                        applicationContext,
                        100,
                        serviceIntent,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                        else PendingIntent.FLAG_UPDATE_CURRENT
                    )
                    
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            System.currentTimeMillis() + 500,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExact(
                            AlarmManager.RTC_WAKEUP,
                            System.currentTimeMillis() + 500,
                            pendingIntent
                        )
                    }
                } catch (e2: Exception) {
                    logger.logEvent("AgoraEvent", "Error scheduling service via AlarmManager", 
                        mapOf("error" to e2.message.toString()))
                }
            }
            
            // Start a connection monitoring timer
            connectionTimer?.cancel()
            connectionTimer = Timer()
            connectionTimer?.scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    // Check if service is running, and restart if needed
                    if (!isServiceRunning(AgoraForegroundService::class.java) && isConnectedToChannel) {
                        logger.logEvent("AgoraEvent", "Foreground service not running, restarting")
                        
                        val restartIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                            putExtra("channelName", lastChannelName)
                            putExtra("token", lastToken)
                            putExtra("uid", lastUid)
                            putExtra("isConnected", true)
                            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                        }
                        
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(restartIntent)
                            } else {
                                startService(restartIntent)
                            }
                            isForegroundServiceRunning = true
                            logger.logEvent("AgoraEvent", "Restarted foreground service")
                        } catch (e: Exception) {
                            logger.logEvent("AgoraEvent", "Failed to restart service", 
                                mapOf("error" to e.message.toString()))
                        }
                    }
                    
                    // Keep Agora engine active in this service too
                    if (isConnectedToChannel && rtcEngine != null) {
                        try {
                            rtcEngine?.adjustRecordingSignalVolume(95 + (Math.random() * 10).toInt())
                            rtcEngine?.enableAudioVolumeIndication(500, 3, false)
                            rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                            rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                            logger.logEvent("AgoraEvent", "Sent keepalive from FCM service")
                        } catch (e: Exception) {
                            logger.logEvent("AgoraEvent", "Error sending keepalive", 
                                mapOf("error" to e.message.toString()))
                        }
                    }
                }
            }, 2000, 2000) // Check every 2 seconds
        }

        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "Agora onUserOffline: $uid, reason: $reason")
            logger.logEvent("AgoraEvent", "User offline", mapOf("uid" to uid, "reason" to reason))
        }

        override fun onConnectionStateChanged(state: Int, reason: Int) {
            Log.d(TAG, "Agora onConnectionStateChanged: state=$state, reason=$reason")
            logger.logEvent("AgoraEvent", "Connection state changed", 
                mapOf("state" to state, "reason" to reason))
            
            // Handle specific reconnection cases
            if (state == Constants.CONNECTION_STATE_DISCONNECTED || 
                state == Constants.CONNECTION_STATE_FAILED) {
                
                isConnectedToChannel = false
                logger.logEvent("AgoraEvent", "Disconnected, will attempt to reconnect")
                
                // Schedule reconnection
                if (lastToken != null && lastChannelName != null && lastUid > 0) {
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            // Try to reconnect
                            connectToAgoraChannel(lastChannelName!!, lastToken!!, lastUid)
                            logger.logEvent("AgoraEvent", "Scheduled reconnection attempt")
                            
                            // Also make sure service is running
                            if (!isForegroundServiceRunning) {
                                logger.logEvent("AgoraEvent", "Restarting foreground service during reconnection")
                                startForegroundServiceWithRetry()
                            }
                        }
                    }, 1000) // Reconnect after 1 second
                }
            } else if (state == Constants.CONNECTION_STATE_CONNECTED) {
                isConnectedToChannel = true
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        logger = AppLogger.getInstance(applicationContext)
        logger.startNewSession("FCMService_Created")
        logger.logEvent("LifeCycle", "Firebase Messaging Service created")
        Log.d(TAG, "DuckBuckFirebaseMessagingService created")
        
        // If we have saved connection params, ensure connection is maintained
        if (lastToken != null && lastChannelName != null && lastUid > 0 && !isConnectedToChannel) {
            logger.logEvent("LifeCycle", "Restoring previous connection on service create")
            thread {
                connectToAgoraChannel(lastChannelName!!, lastToken!!, lastUid)
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        logger.logEvent("TokenUpdate", "New FCM token received", mapOf("token_length" to token.length))
        Log.d(TAG, "New FCM token: $token")
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "Received message: ${remoteMessage.data}")
        
        logger.logEvent("FCM", "Received message", mapOf(
            "data" to remoteMessage.data.toString(),
            "notification" to (remoteMessage.notification?.title ?: "null"),
            "from" to (remoteMessage.from ?: "unknown"),
            "messageId" to (remoteMessage.messageId ?: "unknown")
        ))

        // Only handle messages when the app is killed (not in foreground or background)
        val isKilled = isAppKilled()
        val isRoomInvitation = isRoomInvitationNotification(remoteMessage)
        
        logger.logEvent("FCM", "Message evaluation", mapOf(
            "isAppKilled" to isKilled,
            "isRoomInvitation" to isRoomInvitation
        ))
        
        if (isKilled && isRoomInvitation) {
            logger.logEvent("FCM", "App is in killed state, handling notification natively")
            
            // Wake lock device - acquire early and hold
            logger.logEvent("FCM", "Acquiring wake lock")
            acquireWakeLock()
            
            // Handle the invitation
            logger.logEvent("FCM", "Handling room invitation")
            handleRoomInvitationNotification(remoteMessage)
        } else {
            logger.logEvent("FCM", "App is in foreground/background, letting Flutter handle notification")
            // Let the Flutter implementation handle it
        }
    }
    
    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            // Create wake lock that will keep the CPU running
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or 
                PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                PowerManager.ON_AFTER_RELEASE,
                "DuckBuck:FCMWakeLock"
            )
            
            // Don't let the wake lock count down with references
            wakeLock?.setReferenceCounted(false)
            
            // Acquire for 5 minutes - service should take over before this expires
            wakeLock?.acquire(5 * 60 * 1000L)
            
            logger.logEvent("WakeDevice", "Acquired enhanced FCM wake lock for 5 minutes")
            
            // Also wake the screen for visibility
            wakeScreen(powerManager)
            
        } catch (e: Exception) {
            logger.logEvent("WakeDevice", "Error acquiring wake lock", 
                mapOf("error" to e.message.toString()))
        }
    }
    
    private fun wakeScreen(powerManager: PowerManager) {
        try {
            // Try to wake the screen if it's off
            if (!powerManager.isInteractive) {
                val screenWakeLock = powerManager.newWakeLock(
                    PowerManager.FULL_WAKE_LOCK or 
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                    PowerManager.ON_AFTER_RELEASE,
                    "DuckBuck:ScreenWakeLock"
                )
                
                screenWakeLock.acquire(10000L) // 10 seconds
                
                // If the keyguard is on, try to disable it 
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                val isLocked = keyguardManager.isKeyguardLocked
                logger.logEvent("WakeDevice", "Keyguard status", mapOf("isLocked" to isLocked))
                
                if (isLocked) {
                    // Start the main activity to bring it to the foreground
                    logger.logEvent("WakeDevice", "Device is locked, attempting to start main activity")
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    intent?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        }
                        startActivity(this)
                        logger.logEvent("WakeDevice", "Started main activity with special flags")
                    }
                }
                
                // Release the screen wake lock
                if (screenWakeLock.isHeld) {
                    screenWakeLock.release()
                }
            }
        } catch (e: Exception) {
            logger.logEvent("WakeDevice", "Error waking screen", 
                mapOf("error" to e.message.toString()))
        }
    }

    private fun isAppKilled(): Boolean {
        // This is a heuristic based on whether the main activity is running
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val packageName = packageName
        
        val runningProcesses = activityManager.runningAppProcesses
        logger.logEvent("AppState", "Checking if app is killed", mapOf(
            "runningProcessCount" to (runningProcesses?.size ?: 0),
            "packageName" to packageName
        ))
        
        // Get list of running processes
        if (runningProcesses == null) {
            logger.logEvent("AppState", "No running processes found, considering app killed")
            return true
        }
        
        // Check if our process is in foreground or background
        for (processInfo in runningProcesses) {
            if (processInfo.processName == packageName) {
                val importance = processInfo.importance
                logger.logEvent("AppState", "Found process", mapOf(
                    "processName" to processInfo.processName,
                    "importance" to importance
                ))
                
                // IMPORTANCE_FOREGROUND = 100, IMPORTANCE_BACKGROUND = 400
                // If not in foreground or visible background, consider it "killed"
                val isKilled = importance > 200 // Greater than IMPORTANCE_VISIBLE (200)
                logger.logEvent("AppState", "App state evaluation", mapOf("isKilled" to isKilled))
                return isKilled
            }
        }
        
        // If our process is not found, it's likely killed
        logger.logEvent("AppState", "Process not found, considering app killed")
        return true
    }

    private fun isRoomInvitationNotification(remoteMessage: RemoteMessage): Boolean {
        val type = remoteMessage.data["type"]
        val isInvitation = type == TYPE_ROOM_INVITATION
        logger.logEvent("FCMType", "Checking notification type", 
            mapOf("type" to (type ?: "null"), "isRoomInvitation" to isInvitation))
        return isInvitation
    }

    private fun handleRoomInvitationNotification(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val channelName = data["agora_channel"]
        val token = data["agora_token"] ?: ""
        val uidString = data["agora_uid"]
        val uid = uidString?.toIntOrNull() ?: 0
        val channelId = data["channel_id"] ?: ""
        val senderUid = data["sender_uid"] ?: ""
        val timestamp = data["timestamp"] ?: ""

        logger.logEvent("RoomInvitation", "Handling room invitation", mapOf(
            "channelName" to (channelName ?: "null"),
            "tokenLength" to token.length,
            "uid" to uid,
            "channelId" to channelId,
            "senderUid" to senderUid,
            "timestamp" to timestamp
        ))

        // Validate required data
        if (channelName == null) {
            logger.logEvent("RoomInvitation", "Missing channel name, cannot proceed")
            return
        }
        
        // Save values for potential reconnection
        lastChannelName = channelName
        lastToken = token
        lastUid = uid

        logger.logEvent("RoomInvitation", "Starting foreground service")
        
        // Start foreground service first to ensure visibility to user
        val serviceIntent = Intent(this, AgoraForegroundService::class.java).apply {
            putExtra("channelName", channelName)
            putExtra("senderUid", senderUid)
            putExtra("uid", uid)
            putExtra("token", token)
            
            // Add flags to make sure intent is delivered
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }

        // Start service with retry mechanism
        startForegroundServiceWithRetry(serviceIntent)

        // Initialize and connect to Agora in a background thread
        logger.logEvent("RoomInvitation", "Initiating Agora channel connection in thread")
        thread {
            connectToAgoraChannel(channelName, token, uid)
            
            // Schedule periodic checks to make sure service stays running
            scheduleServiceChecks(channelName, token, uid)
        }
    }
    
    private fun startForegroundServiceWithRetry(intent: Intent? = null) {
        val serviceIntent = intent ?: Intent(this, AgoraForegroundService::class.java).apply {
            putExtra("channelName", lastChannelName)
            putExtra("token", lastToken)
            putExtra("uid", lastUid)
            putExtra("isConnected", isConnectedToChannel)
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }
        
        // Try to start service
        try {
            logger.logEvent("Service", "Attempting to start foreground service")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(this, serviceIntent)
            } else {
                startService(serviceIntent)
            }
            logger.logEvent("Service", "Service started successfully")
            isForegroundServiceRunning = true
        } catch (e: Exception) {
            logger.logEvent("Service", "Failed to start service directly, trying AlarmManager", 
                mapOf("error" to e.message.toString()))
            
            // As a backup, use AlarmManager to start the service shortly
            try {
                logger.logEvent("Service", "Scheduling service start via AlarmManager")
                val pendingIntent = PendingIntent.getService(
                    this,
                    100,
                    serviceIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else PendingIntent.FLAG_UPDATE_CURRENT
                )
                
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 500,
                        pendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 500,
                        pendingIntent
                    )
                }
                
                // Also try with a delay as a second backup
                val backupPendingIntent = PendingIntent.getService(
                    this,
                    101,
                    serviceIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    else PendingIntent.FLAG_UPDATE_CURRENT
                )
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 2000,
                        backupPendingIntent
                    )
                }
                
                logger.logEvent("Service", "Service start scheduled via AlarmManager")
            } catch (e2: Exception) {
                logger.logEvent("Service", "Failed even with AlarmManager", 
                    mapOf("error" to e2.message.toString()))
            }
        }
    }
    
    private fun scheduleServiceChecks(channelName: String, token: String, uid: Int) {
        Timer().scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                // Check if the service is running
                val isRunning = isServiceRunning(AgoraForegroundService::class.java)
                logger.logEvent("ServiceCheck", "Checking if service is running", 
                    mapOf("isRunning" to isRunning))
                
                if (!isRunning && isConnectedToChannel) {
                    logger.logEvent("ServiceCheck", "Service not running, restarting")
                    
                    // Service isn't running, restart it
                    val restartIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                        putExtra("channelName", channelName)
                        putExtra("token", token)
                        putExtra("uid", uid)
                        putExtra("isConnected", isConnectedToChannel)
                        addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                    }
                    
                    startForegroundServiceWithRetry(restartIntent)
                }
                
                // Ensure Agora is still active
                if (isConnectedToChannel && rtcEngine != null) {
                    try {
                        // Keep the engine active
                        rtcEngine?.muteLocalAudioStream(false)
                        rtcEngine?.adjustRecordingSignalVolume(100)
                        rtcEngine?.enableAudioVolumeIndication(500, 3, false)
                        logger.logEvent("ServiceCheck", "Sent activity to RTC engine")
                    } catch (e: Exception) {
                        logger.logEvent("ServiceCheck", "Error keeping RTC engine active", 
                            mapOf("error" to e.message.toString()))
                        
                        // If we can't communicate with the engine, try to reconnect
                        if (channelName == lastChannelName && token == lastToken && uid == lastUid) {
                            logger.logEvent("ServiceCheck", "Attempting to reconnect to channel")
                            connectToAgoraChannel(channelName, token, uid)
                        }
                    }
                }
            }
        }, 5000, 10000) // Check every 10 seconds, starting 5 seconds after initial connection
    }
    
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        
        @Suppress("DEPRECATION") // This remains the most reliable way to check
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun connectToAgoraChannel(channelName: String, token: String, uid: Int) {
        try {
            logger.logEvent("AgoraConnect", "Beginning connection process", mapOf(
                "channelName" to channelName,
                "tokenLength" to token.length,
                "uid" to uid
            ))
            
            // Save connection params for potential reconnection
            lastChannelName = channelName
            lastToken = token
            lastUid = uid
            
            // If already connected to the correct channel, don't reconnect
            if (isConnectedToChannel && rtcEngine != null && lastChannelName == channelName) {
                logger.logEvent("AgoraConnect", "Already connected to this channel, refreshing connection")
                try {
                    // Still refresh the connection parameters
                    rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                    rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                    rtcEngine?.setParameters("{\"rtc.enable_connect_always\": true}")
                    rtcEngine?.setParameters("{\"rtc.enable_session_resume\": true}")
                    
                    // Ensure audio is enabled
                    rtcEngine?.enableAudio()
                    rtcEngine?.muteLocalAudioStream(false)
                    
                    // Make sure the foreground service is running with current parameters
                    startForegroundServiceWithRetry()
                    
                return
                } catch (e: Exception) {
                    logger.logEvent("AgoraConnect", "Error refreshing connection, will reconnect", 
                        mapOf("error" to e.message.toString()))
                    // Continue to full reconnection
                }
            }
            
            // Initialize Agora engine if not already initialized
            if (rtcEngine == null) {
                logger.logEvent("AgoraConnect", "Initializing Agora RTC Engine")
                try {
                    val appId = applicationContext.resources.getString(R.string.agora_app_id)
                    logger.logEvent("AgoraConnect", "Got appId", mapOf(
                        "appIdLength" to appId.length,
                        "appIdStartsWith" to (if (appId.length > 4) appId.substring(0, 4) else appId)
                    ))
                    
                    rtcEngine = RtcEngine.create(applicationContext, appId, rtcEventHandler)
                    logger.logEvent("AgoraConnect", "RTC Engine created successfully")
                    
                    // Configure as audio call
                    rtcEngine?.setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
                    rtcEngine?.enableAudio()
                    rtcEngine?.setEnableSpeakerphone(false)
                    logger.logEvent("AgoraConnect", "RTC Engine configured for audio call")
                    
                    // Set parameters for robust background operation
                    rtcEngine?.setParameters("{\"rtc.room_leave.when_queue_empty\": false}")
                    rtcEngine?.setParameters("{\"rtc.queue_blocked_mode\": 0}")
                    rtcEngine?.setParameters("{\"rtc.enable_accelerate_connection\": true}")
                    rtcEngine?.setParameters("{\"rtc.no_disconnect_when_network_broken\": true}")
                    rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                    rtcEngine?.setParameters("{\"rtc.forced_connection\": true}")
                    rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                    rtcEngine?.setParameters("{\"rtc.audio.keep_send_audioframe_when_silence\": true}")
                    rtcEngine?.setParameters("{\"rtc.enable_connect_always\": true}")
                    rtcEngine?.setParameters("{\"rtc.enable_session_resume\": true}")
                    rtcEngine?.setParameters("{\"rtc.retry_connection_limit\": 30}")
                    rtcEngine?.setParameters("{\"rtc.drop_timeout\": 30000}")
                    rtcEngine?.setParameters("{\"rtc.connection.recovery_timeout\": 30000}")
                    rtcEngine?.setParameters("{\"rtc.engine.force_high_perf\": true}")
                    rtcEngine?.setParameters("{\"che.audio.prevent_bluetooth_off\": true}")
                    
                    // Optimize audio for call quality while minimizing bandwidth
                    rtcEngine?.setParameters("{\"che.audio.enable.aec\": false}")
                    rtcEngine?.setParameters("{\"che.audio.enable.agc\": true}")
                    rtcEngine?.setParameters("{\"che.audio.enable.ns\": false}")
                    rtcEngine?.setParameters("{\"che.audio.enable.hq_apm_mode\": 0}")
                    rtcEngine?.setParameters("{\"che.audio.frame_duration\": 20}")
                    rtcEngine?.setParameters("{\"che.audio.lowlatency\": 1}")
                    
                    // Set a higher priority for Agora
                    rtcEngine?.setParameters("{\"rtc.use_high_priority_task\": true}")
                    
                    logger.logEvent("AgoraConnect", "RTC Engine configured with enhanced parameters")
                } catch (e: Exception) {
                    logger.logEvent("AgoraConnect", "Error initializing Agora engine", 
                        mapOf("error" to e.message.toString(), "stackTrace" to e.stackTraceToString()))
                    throw e
                }
            }

            logger.logEvent("AgoraConnect", "Joining Agora channel", mapOf(
                "channelName" to channelName,
                "uid" to uid,
                "tokenLength" to token.length
            ))
            
            // Set audio parameters for good audio quality with low bandwidth
            rtcEngine?.setAudioProfile(
                Constants.AUDIO_PROFILE_SPEECH_STANDARD,
                Constants.AUDIO_SCENARIO_CHATROOM
            )
            
            // Join the channel with backup server enabled
            rtcEngine?.setParameters("{\"rtc.connection.backup_server_enable\": true}")
            val result = rtcEngine?.joinChannel(token, channelName, null, uid)
            logger.logEvent("AgoraConnect", "Join channel result", mapOf("result" to (result ?: -999)))
            
        } catch (e: Exception) {
            logger.logEvent("AgoraConnect", "Error connecting to Agora channel", 
                mapOf("error" to e.message.toString(), "stackTrace" to e.stackTraceToString()))
            Log.e(TAG, "Error connecting to Agora channel: ${e.message}", e)
            
            // Schedule a retry after a delay
            Timer().schedule(object : TimerTask() {
                override fun run() {
                    logger.logEvent("AgoraConnect", "Retrying connection after failure")
                    try {
                        // Try to clean up rtcEngine first
                        rtcEngine?.leaveChannel()
                        RtcEngine.destroy()
                        rtcEngine = null
                        
                        // Then reconnect from scratch
                        connectToAgoraChannel(channelName, token, uid)
                    } catch (e2: Exception) {
                        logger.logEvent("AgoraConnect", "Retry also failed", 
                            mapOf("error" to e2.message.toString()))
                    }
                }
            }, 3000) // Wait 3 seconds before retry
        }
    }

    override fun onDestroy() {
        logger.logEvent("LifeCycle", "Firebase Messaging Service being destroyed, trying to persist connection")
        
        // Release wake lock if held
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        
        // Try to keep the connection alive
        if (isConnectedToChannel && lastToken != null && lastChannelName != null && lastUid > 0) {
            logger.logEvent("LifeCycle", "Trying to ensure connection persists through service destroy")
            
            // Start the foreground service with our connection details
            val serviceIntent = Intent(this, AgoraForegroundService::class.java).apply {
                putExtra("channelName", lastChannelName)
                putExtra("token", lastToken)
                putExtra("uid", lastUid)
                putExtra("isConnected", true)
                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            }
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } catch (e: Exception) {
                logger.logEvent("LifeCycle", "Error starting service on destroy", 
                    mapOf("error" to e.message.toString()))
            }
        }
        
        Log.d(TAG, "DuckBuckFirebaseMessagingService onDestroy called")
        super.onDestroy()
    }
    
    // Helper to get log file path for Flutter access
    fun getLogFilePath(): String {
        return AppLogger.getInstance(applicationContext).getLogFilePath()
    }
} 