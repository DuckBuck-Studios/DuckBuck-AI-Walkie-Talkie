package com.example.duckbuck
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
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import java.util.Timer
import java.util.TimerTask

class AgoraForegroundService : Service() {
    companion object {
        private const val TAG = "AgoraForegroundService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "AgoraServiceChannel"
        private const val CHANNEL_NAME = "Agora Service Channel"
        
        // Ensure RtcEngine is shared across components
        private var rtcEngine: RtcEngine? = null
        private var isConnected = false
    }
    
    private lateinit var logger: AppLogger
    private var wakeLock: PowerManager.WakeLock? = null
    private var cpuWakeLock: PowerManager.WakeLock? = null
    private var channelName: String? = null
    private var token: String? = null
    private var uid: Int = 0
    private var keepAliveTimer: Timer? = null
    private var heartbeatTimer: Timer? = null
    private var reconnectAttempts = 0
    private val MAX_RECONNECT_ATTEMPTS = 20
    private var lastKeepAliveTime = System.currentTimeMillis()
    
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            Log.d(TAG, "Service: onJoinChannelSuccess - $channel, uid: $uid")
            isConnected = true
            logger.logEvent("ServiceAgoraEvent", "Join channel success", 
                mapOf("channel" to (channel ?: ""), "uid" to uid, "elapsed" to elapsed))
            updateNotification()
            
            // Start keep-alive mechanism
            startKeepAlive()
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            Log.d(TAG, "Service: onUserJoined - $uid")
            logger.logEvent("ServiceAgoraEvent", "User joined", 
                mapOf("uid" to uid, "elapsed" to elapsed))
            updateNotification()
        }
        
        override fun onConnectionStateChanged(state: Int, reason: Int) {
            Log.d(TAG, "Service: onConnectionStateChanged - state: $state, reason: $reason")
            logger.logEvent("ServiceAgoraEvent", "Connection state changed", 
                mapOf("state" to state, "reason" to reason))
            
            // Handle specific case: disconnect with reason "changed by client" (15)
            if (state == Constants.CONNECTION_STATE_DISCONNECTED && reason == 15) {
                logger.logEvent("ServiceAgoraEvent", "Detected Android system disconnecting client, preventing...")
                
                // Re-acquire wake lock immediately
                if (wakeLock?.isHeld != true) {
                    acquireWakeLock()
                }
                
                // Force immediate reconnection without leaving channel first
                if (token != null && channelName != null && uid > 0) {
                    rtcEngine?.let {
                        // Keep the connection active with a direct operation
                        it.muteLocalAudioStream(false)
                        it.adjustRecordingSignalVolume(100)
                    }
                    
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            rtcEngine?.joinChannel(token, channelName, null, uid)
                            logger.logEvent("ServiceAgoraEvent", "Force rejoined after system disconnect")
                        }
                    }, 500) // Faster reconnect (500ms vs 2000ms)
                }
                return
            }
            
            // Handle other disconnection cases
            if (state == Constants.CONNECTION_STATE_DISCONNECTED || 
                state == Constants.CONNECTION_STATE_FAILED) {
                logger.logEvent("ServiceAgoraEvent", "Connection lost, attempting to reconnect")
                
                // Check if we should try to rejoin
                if (token != null && channelName != null && uid > 0) {
                    rtcEngine?.leaveChannel()
                    // Wait a moment before rejoining
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            rtcEngine?.joinChannel(token, channelName, null, uid)
                            logger.logEvent("ServiceAgoraEvent", "Attempted to rejoin channel")
                        }
                    }, 2000)
                }
            }
        }
        
        override fun onError(err: Int) {
            logger.logEvent("ServiceAgoraEvent", "Error occurred", mapOf("errorCode" to err))
            
            // Try to recover from certain errors
            if (err == 101 || // Channel join failed
                err == 109 || // Token expired 
                err == 110 || // Token invalid
                err == 8 || // General timeout
                err == 1 || // General error
                err == 2) { // Invalid argument
                logger.logEvent("ServiceAgoraEvent", "Recoverable error, attempting to rejoin")
                
                if (token != null && channelName != null && uid > 0) {
                    rtcEngine?.leaveChannel()
                    
                    // Wait a moment before rejoining
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            rtcEngine?.joinChannel(token, channelName, null, uid)
                            logger.logEvent("ServiceAgoraEvent", "Attempted to rejoin after error")
                        }
                    }, 2000)
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        logger = AppLogger.getInstance(applicationContext)
        logger.startNewSession("ForegroundService_Created")
        logger.logEvent("Service", "Agora Foreground Service created")
        Log.d(TAG, "Agora Foreground Service created")
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Agora Foreground Service started")
        logger.logEvent("Service", "Foreground service started with intent", 
            mapOf("intent" to (intent?.extras.toString() ?: "null")))
        
        // Get parameters from intent
        channelName = intent?.getStringExtra("channelName") ?: "Voice Call"
        val senderUid = intent?.getStringExtra("senderUid") ?: ""
        token = intent?.getStringExtra("token")
        uid = intent?.getIntExtra("uid", 0) ?: 0
        val isAlreadyConnected = intent?.getBooleanExtra("isConnected", false) ?: false
        
        logger.logEvent("Service", "Parameters extracted from intent", mapOf(
            "channelName" to channelName.toString(),
            "senderUid" to senderUid,
            "tokenLength" to (token?.length ?: 0),
            "uid" to uid,
            "isAlreadyConnected" to isAlreadyConnected
        ))
        
        if (isAlreadyConnected) {
            isConnected = true
            logger.logEvent("Service", "Service marked as connected based on intent")
        }
        
        // Create notification and start foreground service
        val notification = createNotification(channelName ?: "", senderUid)
        
        // Use the appropriate foreground service type for Android 12+
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                logger.logEvent("Service", "Starting foreground service with media playback type")
                startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                logger.logEvent("Service", "Starting regular foreground service")
                startForeground(NOTIFICATION_ID, notification)
            }
            logger.logEvent("Service", "Successfully started as foreground service")
        } catch (e: Exception) {
            logger.logEvent("Service", "Error starting foreground service", 
                mapOf("error" to e.message.toString()))
        }
        
        // Initialize Agora if needed and token is provided
        if (!isConnected && token != null && uid > 0) {
            logger.logEvent("Service", "Initializing Agora connection from service")
            initializeAndConnectAgora()
        } else {
            logger.logEvent("Service", "Not initializing Agora connection", mapOf(
                "isConnected" to isConnected,
                "hasToken" to (token != null),
                "uid" to uid
            ))
        }
        
        // Set up heartbeat to keep the service alive
        startHeartbeat()
        
        // Return sticky to ensure service restarts if killed
        return START_STICKY
    }
    
    private fun startHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = Timer()
        heartbeatTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                logger.logEvent("Service", "Heartbeat pulse", mapOf("isConnected" to isConnected))
                
                // Re-acquire wake lock if it was released
                if (wakeLock?.isHeld != true) {
                    acquireWakeLock()
                }
                
                // Actively check connection status and restore if needed
                if (isConnected && rtcEngine != null) {
                    // Check if we need to send a ping to maintain connection
                    rtcEngine?.let { engine ->
                        try {
                            // Perform minimal operation on RTC engine to keep it active
                            engine.adjustRecordingSignalVolume(100)
                            engine.enableAudioVolumeIndication(1000, 3, false)
                        } catch (e: Exception) {
                            logger.logEvent("Service", "Error during heartbeat ping", 
                                mapOf("error" to e.message.toString()))
                        }
                    }
                }
                
                // Update notification to keep service in foreground
                updateNotification()
            }
        }, 5000, 5000) // Every 5 seconds (increased from 15)
    }
    
    private fun startKeepAlive() {
        keepAliveTimer?.cancel()
        keepAliveTimer = Timer()
        keepAliveTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                // Keep Agora connection active by sending operations in sequence
                rtcEngine?.let {
                    try {
                        // More aggressive keep-alive with multiple operations
                        it.enableAudioVolumeIndication(1000, 3, false)
                        it.muteLocalAudioStream(false)
                        it.adjustRecordingSignalVolume(100)
                        
                        // Vary signal volume slightly to ensure real traffic
                        val randomVolume = 95 + (Math.random() * 10).toInt()
                        it.adjustRecordingSignalVolume(randomVolume)
                        
                        // Additional operations to create network activity
                        it.setAudioProfile(Constants.AUDIO_PROFILE_DEFAULT, Constants.AUDIO_SCENARIO_GAME_STREAMING)
                        
                        // Reset connection parameters periodically to prevent timeout
                        it.setParameters("{\"rtc.no_disconnect_when_network_broken\": true}")
                        it.setParameters("{\"rtc.use_persistent_connection\": true}")
                        it.setParameters("{\"rtc.forced_connection\": true}")
                        it.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                        it.setParameters("{\"rtc.audio.keep_send_audioframe_when_silence\": true}")
                        it.setParameters("{\"rtc.enable_connect_always\": true}")
                        
                        // Record last successful keep-alive time
                        lastKeepAliveTime = System.currentTimeMillis()
                        reconnectAttempts = 0 // Reset reconnect attempts counter on success
                        
                        logger.logEvent("KeepAlive", "Sent keep-alive pulse to Agora", 
                            mapOf("volume" to randomVolume))
                    } catch (e: Exception) {
                        logger.logEvent("KeepAlive", "Error in keep-alive", 
                            mapOf("error" to e.message.toString()))
                        
                        // If keep-alive fails, try to re-establish connection with backoff
                        if (isConnected && token != null && channelName != null && uid > 0) {
                            reconnectAttempts++
                            
                            if (reconnectAttempts <= MAX_RECONNECT_ATTEMPTS) {
                                try {
                                    // Allow increasing backoff for repeated attempts
                                    val backoffTime = Math.min(reconnectAttempts * 500, 5000).toLong()
                                    
                                    Timer().schedule(object : TimerTask() {
                                        override fun run() {
                                            try {
                                                // First, attempt to refresh the engine state
                                                it.muteLocalAudioStream(false)
                                                it.adjustRecordingSignalVolume(100)
                                                Thread.sleep(100)
                                                
                                                // Then rejoin the channel
                                                it.leaveChannel()
                                                Thread.sleep(200)
                                                it.joinChannel(token, channelName, null, uid)
                                                logger.logEvent("KeepAlive", "Re-joined channel after keep-alive failure",
                                                    mapOf("attempt" to reconnectAttempts, "backoff" to backoffTime))
                                            } catch (e2: Exception) {
                                                logger.logEvent("KeepAlive", "Failed to rejoin on attempt $reconnectAttempts", 
                                                    mapOf("error" to e2.message.toString()))
                                                
                                                // If multiple rejoin attempts fail, try to reinitialize Agora
                                                if (reconnectAttempts >= 5 && reconnectAttempts % 5 == 0) {
                                                    logger.logEvent("KeepAlive", "Multiple rejoin failures, reinitializing Agora")
                                                    initializeAndConnectAgora()
                                                }
                                            }
                                        }
                                    }, backoffTime)
                                } catch (e2: Exception) {
                                    logger.logEvent("KeepAlive", "Critical error scheduling rejoin", 
                                        mapOf("error" to e2.message.toString()))
                                }
                            } else {
                                // After max attempts, try more drastic measures
                                logger.logEvent("KeepAlive", "Reached max reconnect attempts, forcing service restart")
                                restartService()
                                reconnectAttempts = 0 // Reset counter
                            }
                        }
                    }
                }
            }
        }, 2000, 2000) // Every 2 seconds (increased from 3)
    }
    
    private fun initializeAndConnectAgora() {
        try {
            logger.logEvent("ServiceAgora", "Beginning Agora initialization")
            
            // Use existing engine if available, or create a new one
            if (rtcEngine == null) {
                logger.logEvent("ServiceAgora", "Creating new RTC engine")
                
                val appId = applicationContext.resources.getString(R.string.agora_app_id)
                logger.logEvent("ServiceAgora", "Got app ID", mapOf(
                    "appIdLength" to appId.length,
                    "appIdStartsWith" to (if (appId.length > 4) appId.substring(0, 4) else appId)
                ))
                
                rtcEngine = RtcEngine.create(applicationContext, appId, rtcEventHandler)
                logger.logEvent("ServiceAgora", "RTC engine created successfully")
                
                // Configure as audio call
                rtcEngine?.setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
                rtcEngine?.enableAudio()
                
                // ENHANCED PARAMETERS: Optimize for background operation
                // Prevent connection from being dropped in background
                rtcEngine?.setParameters("{\"rtc.room_leave.when_queue_empty\": false}")
                rtcEngine?.setParameters("{\"rtc.queue_blocked_mode\": 0}")
                rtcEngine?.setParameters("{\"rtc.enable_accelerate_connection\": true}")
                
                // Critical parameters to prevent Android from dropping the connection
                rtcEngine?.setParameters("{\"rtc.no_disconnect_when_network_broken\": true}")
                rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                rtcEngine?.setParameters("{\"rtc.forced_connection\": true}")
                rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")  // More frequent keepalive
                rtcEngine?.setParameters("{\"rtc.audio.keep_send_audioframe_when_silence\": true}")
                rtcEngine?.setParameters("{\"rtc.enable_connect_always\": true}")
                
                // New parameters for better persistence
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
                rtcEngine?.setParameters("{\"che.audio.enable.hq_apm_mode\": 0}") // Basic audio processing
                rtcEngine?.setParameters("{\"che.audio.frame_duration\": 20}")
                rtcEngine?.setParameters("{\"che.audio.lowlatency\": 1}")
                
                // Disable video to reduce resource usage
                rtcEngine?.disableVideo()
                
                // Set a higher priority for Agora
                rtcEngine?.setParameters("{\"rtc.use_high_priority_task\": true}")
                
                logger.logEvent("ServiceAgora", "RTC engine configured with enhanced parameters")
            } else {
                logger.logEvent("ServiceAgora", "Using existing RTC engine")
                
                // Refresh parameters even for existing engine
                rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                rtcEngine?.setParameters("{\"rtc.enable_session_resume\": true}")
                rtcEngine?.setParameters("{\"rtc.retry_connection_limit\": 30}")
            }
            
            // Join channel with optimized options
            logger.logEvent("ServiceAgora", "Joining channel", mapOf(
                "channelName" to (channelName ?: ""),
                "uid" to uid,
                "tokenLength" to (token?.length ?: 0)
            ))
            
            // Set audio parameters for low bandwidth usage
            rtcEngine?.setAudioProfile(
                Constants.AUDIO_PROFILE_SPEECH_STANDARD,
                Constants.AUDIO_SCENARIO_CHATROOM
            )
            
            // Join channel with specific connection optimization
            rtcEngine?.setParameters("{\"rtc.connection.backup_server_enable\": true}")
            val result = rtcEngine?.joinChannel(token, channelName, null, uid)
            logger.logEvent("ServiceAgora", "Join channel result", mapOf("result" to (result ?: -999)))
            
            // Reset reconnect attempts counter
            reconnectAttempts = 0
            
        } catch (e: Exception) {
            logger.logEvent("ServiceAgora", "Error initializing Agora", 
                mapOf("error" to e.message.toString(), "stackTrace" to e.stackTraceToString()))
            Log.e(TAG, "Error initializing Agora: ${e.message}", e)
        }
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            if (cpuWakeLock?.isHeld == true) {
                cpuWakeLock?.release()
            }
            
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            // Use a combination of wake locks for maximum effectiveness
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "DuckBuck:AgoraServiceWakeLock"
            )
            
            // Add CPU wake lock to prevent deep sleep
            cpuWakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "DuckBuck:AgoraCpuWakeLock"
            )
            
            logger.logEvent("Service", "Acquiring multiple enhanced wake locks")
            
            // Acquire indefinitely to prevent Android from releasing
            wakeLock?.setReferenceCounted(false)
            wakeLock?.acquire()
            
            cpuWakeLock?.setReferenceCounted(false)
            cpuWakeLock?.acquire(10*60*1000L) // 10 minutes, will be refreshed
            
            logger.logEvent("Service", "Enhanced wake locks acquired")
            
            // Schedule periodic wake lock refreshes at a higher frequency
            Timer().scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    try {
                        // Release and reacquire to refresh the wake locks
                        synchronized(this@AgoraForegroundService) {
                            if (cpuWakeLock?.isHeld == true) {
                                cpuWakeLock?.release()
                            }
                            
                            // Create a fresh CPU wake lock with new timestamp
                            cpuWakeLock = powerManager.newWakeLock(
                                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                                "DuckBuck:AgoraCpuWakeLock-refresh-${System.currentTimeMillis()}"
                            )
                            cpuWakeLock?.setReferenceCounted(false)
                            cpuWakeLock?.acquire(10*60*1000L)
                            
                            // Check if regular wakeLock is still held
                            if (wakeLock?.isHeld != true) {
                                wakeLock = powerManager.newWakeLock(
                                    PowerManager.PARTIAL_WAKE_LOCK,
                                    "DuckBuck:AgoraServiceWakeLock-refresh-${System.currentTimeMillis()}"
                                )
                                wakeLock?.setReferenceCounted(false)
                                wakeLock?.acquire()
                            }
                            
                            logger.logEvent("Service", "All wake locks refreshed")
                            
                            // Also check if we need to restart the service - this helps with Android's service lifetime limits
                            val timeSinceLastKeepAlive = System.currentTimeMillis() - lastKeepAliveTime
                            if (timeSinceLastKeepAlive > 60000) { // 1 minute
                                logger.logEvent("Service", "Service may be stalling, forcing activity")
                                updateNotification() // Refresh notification
                                
                                // Force Agora activity
                                rtcEngine?.let {
                                    try {
                                        it.adjustRecordingSignalVolume(95 + (Math.random() * 10).toInt())
                                        it.enableAudioVolumeIndication(500, 3, false)
                                    } catch (e: Exception) {
                                        logger.logEvent("Service", "Error forcing activity", 
                                            mapOf("error" to e.message.toString()))
                                    }
                                }
                                
                                // If no keepAlive for too long, consider restarting service
                                if (timeSinceLastKeepAlive > 180000) { // 3 minutes
                                    logger.logEvent("Service", "Long time without activity, forcing service restart")
                                    restartService()
                                }
                            }
                        }
                    } catch (e: Exception) {
                        logger.logEvent("Service", "Error refreshing wake locks", 
                            mapOf("error" to e.message.toString()))
                    }
                }
            }, 15 * 1000, 15 * 1000) // Every 15 seconds (was 30 minutes)
            
        } catch (e: Exception) {
            logger.logEvent("Service", "Error acquiring wake locks", 
                mapOf("error" to e.message.toString()))
            Log.e(TAG, "Error acquiring wake locks: ${e.message}", e)
        }
    }

    private fun restartService() {
        try {
            // Save the current state
            val currentChannelName = channelName
            val currentToken = token
            val currentUid = uid
            
            // Create intent with current state
            val restartIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                putExtra("channelName", currentChannelName)
                putExtra("token", currentToken)
                putExtra("uid", currentUid)
                putExtra("isConnected", isConnected)
                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            }
            
            // Stop and start the service
            stopSelf()
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
            
            logger.logEvent("Service", "Service manually restarted for persistence")
        } catch (e: Exception) {
            logger.logEvent("Service", "Failed to restart service", 
                mapOf("error" to e.message.toString()))
        }
    }

    private fun updateNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notification = createNotification(channelName ?: "", "")
            notificationManager.notify(NOTIFICATION_ID, notification)
            logger.logEvent("Service", "Notification updated with connected status")
        } catch (e: Exception) {
            logger.logEvent("Service", "Error updating notification", 
                mapOf("error" to e.message.toString()))
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        logger.logEvent("Service", "Foreground service being destroyed")
        
        // Stop the timers
        keepAliveTimer?.cancel()
        heartbeatTimer?.cancel()
        
        // Release wake lock
        if (wakeLock?.isHeld == true) {
            logger.logEvent("Service", "Releasing wake lock")
            try {
                wakeLock?.release()
            } catch (e: Exception) {
                logger.logEvent("Service", "Error releasing wake lock", 
                    mapOf("error" to e.message.toString()))
            }
        }
        
        logger.logEvent("Service", "Service destroyed")
        Log.d(TAG, "Agora Foreground Service destroyed")
        
        // Restart the service if we were connected
        if (isConnected && token != null && channelName != null) {
            logger.logEvent("Service", "Service was connected, attempting restart")
            try {
                val restartIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                    putExtra("channelName", channelName)
                    putExtra("token", token)
                    putExtra("uid", uid)
                    putExtra("isConnected", true)
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(restartIntent)
                } else {
                    startService(restartIntent)
                }
                logger.logEvent("Service", "Service restart requested")
            } catch (e: Exception) {
                logger.logEvent("Service", "Failed to restart service", 
                    mapOf("error" to e.message.toString()))
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            logger.logEvent("Service", "Creating notification channel")
            
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH // Change to HIGH to make sure it gets user attention
            ).apply {
                description = "Keeps audio call running in background"
                setSound(null, null)
                setShowBadge(true)
                enableLights(true)
                enableVibration(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            logger.logEvent("Service", "Notification channel created")
        }
    }

    private fun createNotification(channelName: String, senderUid: String): Notification {
        try {
            logger.logEvent("Service", "Creating notification", mapOf(
                "channelName" to channelName,
                "senderUid" to senderUid,
                "isConnected" to isConnected
            ))
            
            // Create an intent to open the app when notification is tapped
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                packageManager.getLaunchIntentForPackage(packageName),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            // Create title and content based on available information
            val title = if (isConnected) "Active Call" else "Incoming Voice Call"
            val content = if (senderUid.isNotEmpty()) {
                "Call from user $senderUid in channel $channelName"
            } else if (isConnected) {
                "Connected to channel $channelName"
            } else {
                "Connecting to channel $channelName..."
            }

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(content)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setPriority(NotificationCompat.PRIORITY_HIGH) // Set to HIGH for immediate user attention
                .setCategory(NotificationCompat.CATEGORY_CALL) // Set category to CALL
                .setOngoing(true)
                .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
                .build()
                
            logger.logEvent("Service", "Notification created", mapOf(
                "title" to title,
                "content" to content
            ))
            
            return notification
        } catch (e: Exception) {
            logger.logEvent("Service", "Error creating notification", 
                mapOf("error" to e.message.toString()))
            
            // Fallback notification in case of error
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("DuckBuck Audio Call")
                .setContentText("Audio Call Service")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .build()
        }
    }
    
    // This ensures the service restarts if it's killed
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        logger.logEvent("Service", "onTaskRemoved called, scheduling aggressive restart")
        
        // Request restart if service is killed
        if (isConnected) {
            try {
                // Create a robust restart intent with all necessary information
                val restartServiceIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                    putExtra("channelName", channelName)
                    putExtra("token", token)
                    putExtra("uid", uid)
                    putExtra("isConnected", true)
                    // Add flags to ensure intent is processed with high priority
                    addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                
                // Use multiple restart mechanisms for redundancy
                
                // 1. AlarmManager (most reliable for quick restarts)
                val pendingIntentFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                
                val restartServicePendingIntent = PendingIntent.getService(
                    applicationContext, 1, restartServiceIntent, pendingIntentFlag
                )
                
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                
                // Set multiple alarms at different times for redundancy
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    // First quick restart
                    alarmManager.setExactAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 100, // 100ms (faster restart)
                        restartServicePendingIntent
                    )
                    
                    // Second restart as backup
                    val backupPendingIntent = PendingIntent.getService(
                        applicationContext, 2, restartServiceIntent, pendingIntentFlag
                    )
                    alarmManager.setExactAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 1000, // 1 second backup
                        backupPendingIntent
                    )
                    
                    // Third restart as final backup
                    val finalBackupPendingIntent = PendingIntent.getService(
                        applicationContext, 3, restartServiceIntent, pendingIntentFlag
                    )
                    alarmManager.setExactAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 3000, // 3 second final backup
                        finalBackupPendingIntent
                    )
                } else {
                    alarmManager.setExact(
                        android.app.AlarmManager.RTC_WAKEUP,
                        System.currentTimeMillis() + 100,
                        restartServicePendingIntent
                    )
                }
                
                // 2. Also try direct service start as backup
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(restartServiceIntent)
                    } else {
                        startService(restartServiceIntent)
                    }
                } catch (e: Exception) {
                    logger.logEvent("Service", "Direct restart attempt failed, relying on AlarmManager", 
                        mapOf("error" to e.message.toString()))
                }
                
                // 3. Try to keep the process alive a bit longer
                Thread {
                    try {
                        // Keep the thread alive for a moment
                        for (i in 1..20) {
                            Thread.sleep(100)
                            // Perform some CPU work to keep process alive
                            var result = 0.0
                            for (j in 1..1000) {
                                result += Math.sin(j.toDouble())
                            }
                            if (i % 5 == 0) {
                                Log.d(TAG, "Keeping service alive: $i/20")
                            }
                        }
                    } catch (e: Exception) {
                        // Ignore interruptions
                    }
                }.start()
                
                logger.logEvent("Service", "Scheduled triple redundant service restart mechanisms")
            } catch (e: Exception) {
                logger.logEvent("Service", "Failed to schedule restart", 
                    mapOf("error" to e.message.toString()))
            }
        }
    }
}