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

    private var wakeLock: PowerManager.WakeLock? = null
    
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onError(err: Int) {
            Log.e(TAG, "Agora onError: $err")
            Log.e(TAG, "Agora error: $err")
            
            // Try to recover from certain errors
            if (err == 101 || // Channel join failed
                err == 109 || // Token expired 
                err == 110 || // Token invalid
                err == 8 || // General timeout
                err == 1 || // General error
                err == 2) { // Invalid argument
                
                Log.d(TAG, "Recoverable error, attempting to rejoin")
                
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
            
            Log.d(TAG, "Joined channel successfully: channel=${channel ?: "Unknown"}, uid=$uid, elapsed=$elapsed")
            
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
                Log.d(TAG, "Started foreground service after join success")
            } catch (e: Exception) {
                Log.e(TAG, "Error starting foreground service: ${e.message}", e)
                
                // As a backup, schedule the service to start via AlarmManager
                try {
                    Log.d(TAG, "Scheduling service start via AlarmManager")
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
                    Log.e(TAG, "Error scheduling service via AlarmManager: ${e2.message}", e2)
                }
            }
            
            // Start a connection monitoring timer
            connectionTimer?.cancel()
            connectionTimer = Timer()
            connectionTimer?.scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    // Check if service is running, and restart if needed
                    if (!isServiceRunning(AgoraForegroundService::class.java) && isConnectedToChannel) {
                        Log.d(TAG, "Foreground service not running, restarting")
                        
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
                            Log.d(TAG, "Restarted foreground service")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to restart service: ${e.message}", e)
                        }
                    }
                    
                    // Keep Agora engine active in this service too
                    if (isConnectedToChannel && rtcEngine != null) {
                        try {
                            rtcEngine?.adjustRecordingSignalVolume(95 + (Math.random() * 10).toInt())
                            rtcEngine?.enableAudioVolumeIndication(500, 3, false)
                            rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                            rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                            Log.d(TAG, "Sent keepalive from FCM service")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error sending keepalive: ${e.message}", e)
                        }
                    }
                }
            }, 2000, 2000) // Check every 2 seconds
        }

        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "Agora onUserOffline: $uid, reason: $reason")
            Log.d(TAG, "User offline: uid=$uid, reason=$reason")
        }

        override fun onConnectionStateChanged(state: Int, reason: Int) {
            Log.d(TAG, "Agora onConnectionStateChanged: state=$state, reason=$reason")
            Log.d(TAG, "Connection state changed: state=$state, reason=$reason")
            
            // Handle specific reconnection cases
            if (state == Constants.CONNECTION_STATE_DISCONNECTED || 
                state == Constants.CONNECTION_STATE_FAILED) {
                
                isConnectedToChannel = false
                Log.d(TAG, "Disconnected, will attempt to reconnect")
                
                // Schedule reconnection
                if (lastToken != null && lastChannelName != null && lastUid > 0) {
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            // Try to reconnect
                            connectToAgoraChannel(lastChannelName!!, lastToken!!, lastUid)
                            Log.d(TAG, "Scheduled reconnection attempt")
                            
                            // Also make sure service is running
                            if (!isForegroundServiceRunning) {
                                Log.d(TAG, "Restarting foreground service during reconnection")
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
        Log.d(TAG, "DuckBuckFirebaseMessagingService created")
        
        // If we have saved connection params, ensure connection is maintained
        if (lastToken != null && lastChannelName != null && lastUid > 0 && !isConnectedToChannel) {
            Log.d(TAG, "Restoring previous connection on service create")
            thread {
                connectToAgoraChannel(lastChannelName!!, lastToken!!, lastUid)
            }
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token received: ${token.length} chars")
        Log.d(TAG, "New FCM token: $token")
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "Received message: ${remoteMessage.data}")
        
        Log.d(TAG, "Received FCM message: ${remoteMessage.messageId}, data: ${remoteMessage.data}")
        
        // Wake up the device to handle this notification
        acquireWakeLock()
        
        try {
            val messageData = remoteMessage.data
            val messageType = messageData["type"]
            
            Log.d(TAG, "Processing message of type: $messageType")
            
            when (messageType) {
                TYPE_ROOM_INVITATION -> {
                    handleRoomInvitation(messageData)
                }
                "directMessage" -> {
                    // Handle direct messages
                    Log.d(TAG, "Direct message received: ${messageData["messageContent"]}")
                }
                "systemNotification" -> {
                    // Handle system notifications
                    Log.d(TAG, "System notification: ${messageData["message"]}")
                }
                else -> {
                    // Handle other message types
                    Log.d(TAG, "Unknown message type: $messageType")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing FCM message: ${e.message}", e)
        } finally {
            releaseWakeLock()
        }
    }
    
    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "DuckBuck:FCMWakeLock"
                )
                wakeLock?.acquire(10 * 60 * 1000L) // 10 minutes max
                Log.d(TAG, "Wake lock acquired")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock: ${e.message}", e)
        }
    }
    
    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
                Log.d(TAG, "Wake lock released")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}", e)
        }
    }
    
    private fun handleRoomInvitation(data: Map<String, String>) {
        Log.d(TAG, "Processing room invitation")
        
        // Get invitation details
        val roomId = data["roomId"] ?: ""
        val channelName = data["channelName"] ?: ""
        val agoraToken = data["agoraToken"] ?: ""
        val uid = data["uid"]?.toIntOrNull() ?: 0
        val senderUid = data["senderUid"] ?: ""
        val senderName = data["senderName"] ?: "Unknown"
        
        Log.d(TAG, "Room invitation details: roomId=$roomId, channelName=$channelName, tokenLength=${agoraToken.length}, uid=$uid, sender=$senderName")
        
        // Validate essential data
        if (channelName.isEmpty() || agoraToken.isEmpty() || uid <= 0) {
            Log.e(TAG, "Invalid room invitation data")
            return
        }
        
        // Store token for potential reconnection
        lastToken = agoraToken
        
        // Connect to the Agora channel
        thread {
            connectToAgoraChannel(channelName, agoraToken, uid)
        }
        
        // Start the foreground service to keep the connection alive
        try {
            val serviceIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                putExtra("channelName", channelName)
                putExtra("senderUid", senderUid)
                putExtra("token", agoraToken)
                putExtra("uid", uid)
                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            
            isForegroundServiceRunning = true
            Log.d(TAG, "Started foreground service for room invitation")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service: ${e.message}", e)
            startForegroundServiceWithRetry()
        }
        
        // Also try to wake up the app UI
        wakeUpApp(roomId, channelName, senderName)
    }
    
    private fun connectToAgoraChannel(channelName: String, token: String, uid: Int) {
        try {
            // Don't reconnect if already connected to this channel
            if (isConnectedToChannel && lastChannelName == channelName) {
                Log.d(TAG, "Already connected to channel: $channelName")
                return
            }
            
            Log.d(TAG, "Initializing Agora connection")
            
            // Initialize Agora SDK if not already initialized
            if (rtcEngine == null) {
                Log.d(TAG, "Creating RTC engine")
                
                // Get app ID from resources
                val appId = applicationContext.resources.getString(R.string.agora_app_id)
                Log.d(TAG, "Agora app ID length: ${appId.length}")
                
                rtcEngine = RtcEngine.create(applicationContext, appId, rtcEventHandler)
                
                // Configure audio settings for call
                rtcEngine?.apply {
                    enableAudio()
                    disableVideo()
                    setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
                    setAudioProfile(Constants.AUDIO_PROFILE_DEFAULT, Constants.AUDIO_SCENARIO_CHATROOM)
                    
                    // Optimize for reliability
                    setParameters("{\"rtc.enable_keep_alive_webrtc\": true}")
                    setParameters("{\"rtc.use_high_priority_task\": true}")
                    setParameters("{\"che.audio.keep_audiosession\": true}")
                    setParameters("{\"rtc.audio.force_bluetooth_a2dp\": true}")
                    setParameters("{\"rtc.audio.keep_send_audioframe_when_silence\": true}")
                    setParameters("{\"rtc.low_audio_delay_latency\": true}")
                    setParameters("{\"rtc.enable_connect_always\": true}")
                    
                    // Recommended for VoIP calls
                    adjustPlaybackSignalVolume(150) // Boost volume slightly
                }
                
                Log.d(TAG, "RTC engine created successfully")
            }
            
            // Store this channel info for potential reconnection
            lastChannelName = channelName
            lastToken = token
            lastUid = uid
            
            // Join the channel
            Log.d(TAG, "Joining Agora channel: $channelName with uid $uid")
            val result = rtcEngine?.joinChannel(token, channelName, null, uid)
            Log.d(TAG, "Join channel result: $result")
            
            // Schedule regular keep-alive
            startKeepAliveTimer()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to Agora channel: ${e.message}", e)
        }
    }
    
    private fun startKeepAliveTimer() {
        try {
            // Cancel any existing timer
            connectionTimer?.cancel()
            
            // Create new timer for keepalive
            connectionTimer = Timer()
            connectionTimer?.scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    if (isConnectedToChannel && rtcEngine != null) {
                        try {
                            // Simple operations to maintain the connection
                            rtcEngine?.adjustRecordingSignalVolume(100)
                            Log.d(TAG, "Keeping connection alive")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in keep-alive: ${e.message}", e)
                        }
                    }
                }
            }, 5000, 5000) // Every 5 seconds
            
            Log.d(TAG, "Keep-alive timer started")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting keep-alive timer: ${e.message}", e)
        }
    }
    
    private fun wakeUpApp(roomId: String, channelName: String, senderName: String) {
        try {
            Log.d(TAG, "Attempting to wake up app UI")
            
            // Check if device is locked
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            val isDeviceLocked = keyguardManager.isKeyguardLocked
            
            // Create intent to launch main activity
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("roomId", roomId)
                putExtra("channelName", channelName)
                putExtra("senderName", senderName)
                putExtra("fromNotification", true)
            }
            
            // Only try to directly start activity if device is not locked
            if (!isDeviceLocked && launchIntent != null) {
                startActivity(launchIntent)
                Log.d(TAG, "Started main activity")
            } else {
                Log.d(TAG, "Device locked or no launch intent, can't directly start activity")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error waking up app: ${e.message}", e)
        }
    }
    
    private fun startForegroundServiceWithRetry() {
        try {
            Log.d(TAG, "Trying backup method to start foreground service")
            
            if (lastToken != null && lastChannelName != null && lastUid > 0) {
                val serviceIntent = Intent(applicationContext, AgoraForegroundService::class.java).apply {
                    putExtra("channelName", lastChannelName)
                    putExtra("token", lastToken)
                    putExtra("uid", lastUid)
                    putExtra("isConnected", isConnectedToChannel)
                    addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                }
                
                // Try using AlarmManager as fallback
                val pendingIntent = PendingIntent.getService(
                    applicationContext,
                    101,
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
                
                Log.d(TAG, "Service start scheduled via AlarmManager")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule service start: ${e.message}", e)
        }
    }
    
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        try {
            val intent = Intent(applicationContext, serviceClass)
            val pendingIntent = PendingIntent.getService(
                applicationContext,
                0,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
                else PendingIntent.FLAG_NO_CREATE
            )
            
            // If the pending intent is null, the service is not running
            return pendingIntent != null
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if service is running: ${e.message}", e)
            return false
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "FCM service being destroyed")
        
        releaseWakeLock()
        connectionTimer?.cancel()
        
        Log.d(TAG, "FCM service destroyed")
    }
} 