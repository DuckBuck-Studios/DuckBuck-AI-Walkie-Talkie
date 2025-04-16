package com.example.duckbuck.service

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import java.util.Timer
import java.util.TimerTask

/**
 * A foreground service that manages ongoing calls in the background.
 * This service maintains the call state and updates the UI and notifications.
 */
class ForegroundCallService : Service() {
    companion object {
        private const val TAG = "ForegroundCallService"
        private const val WAKELOCK_TAG = "DuckBuck:ForegroundCallWakeLock"
        
        // Intent actions
        const val ACTION_START_SERVICE = "com.example.duckbuck.START_CALL_SERVICE"
        const val ACTION_STOP_SERVICE = "com.example.duckbuck.STOP_CALL_SERVICE"
        const val ACTION_UPDATE_CALL_INFO = "com.example.duckbuck.UPDATE_CALL_INFO"
        const val ACTION_END_CALL = "com.example.duckbuck.END_CALL"
        
        // Intent extras
        const val EXTRA_CALLER_NAME = "caller_name"
        const val EXTRA_CALLER_AVATAR = "caller_avatar"
        const val EXTRA_CALL_DURATION = "call_duration"
        const val EXTRA_IS_MUTED = "is_muted"
        const val EXTRA_CALL_ENDED = "call_ended"
        const val EXTRA_SENDER_UID = "sender_uid"
    }
    
    private lateinit var notificationManager: CallNotificationManager
    private lateinit var callStateManager: CallStateManager
    private var wakeLock: PowerManager.WakeLock? = null
    private var callerName: String = "Unknown"
    private var callerAvatar: String? = null
    private var senderUid: String? = null
    private var callDuration: Int = 0
    private var isAudioMuted: Boolean = false
    private var isCallEnded: Boolean = false
    private val handler = Handler(Looper.getMainLooper())
    private var durationTimer: Timer? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
        // Initialize managers
        notificationManager = CallNotificationManager(this)
        callStateManager = CallStateManager(this)
        
        // Create wake lock
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKELOCK_TAG
        ).apply {
            setReferenceCounted(false)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when(intent?.action) {
            ACTION_START_SERVICE -> {
                callerName = intent.getStringExtra(EXTRA_CALLER_NAME) ?: "Unknown"
                callerAvatar = intent.getStringExtra(EXTRA_CALLER_AVATAR)
                senderUid = intent.getStringExtra(EXTRA_SENDER_UID)
                callDuration = intent.getIntExtra(EXTRA_CALL_DURATION, 0)
                isAudioMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, false)
                isCallEnded = false
                
                // Start foreground service with notification
                startForegroundWithNotification()
                
                // Acquire wake lock to keep service running
                acquireWakeLock()
                
                // Start call duration timer
                startDurationTimer()
                
                // Save call state for persistence
                callStateManager.saveCallState(
                    isActive = true, 
                    callerName = callerName, 
                    callerAvatar = callerAvatar,
                    callDuration = callDuration,
                    senderUid = senderUid,
                    isAudioMuted = isAudioMuted
                )
                
                Log.d(TAG, "Service started for call with $callerName, avatar: $callerAvatar")
            }
            
            ACTION_STOP_SERVICE -> {
                // Stop duration timer
                stopDurationTimer()
                
                // Clear saved state
                callStateManager.clearCallState()
                
                stopSelf()
            }
            
            ACTION_UPDATE_CALL_INFO -> {
                val avatarChanged = intent.hasExtra(EXTRA_CALLER_AVATAR)
                
                intent.getStringExtra(EXTRA_CALLER_NAME)?.let { callerName = it }
                intent.getStringExtra(EXTRA_CALLER_AVATAR)?.let { callerAvatar = it }
                intent.getStringExtra(EXTRA_SENDER_UID)?.let { senderUid = it }
                
                // Only update call duration if explicitly provided
                if (intent.hasExtra(EXTRA_CALL_DURATION)) {
                    callDuration = intent.getIntExtra(EXTRA_CALL_DURATION, callDuration)
                }
                
                if (intent.hasExtra(EXTRA_IS_MUTED)) {
                    isAudioMuted = intent.getBooleanExtra(EXTRA_IS_MUTED, false)
                }
                
                // Check if call ended
                if (intent.hasExtra(EXTRA_CALL_ENDED)) {
                    isCallEnded = intent.getBooleanExtra(EXTRA_CALL_ENDED, false)
                    
                    if (isCallEnded) {
                        Log.d(TAG, "Call ended flag received, showing notification")
                        // Get remote ended flag if provided
                        val remoteEnded = intent.getBooleanExtra("remoteEnded", false)
                        Log.d(TAG, "Remote ended: $remoteEnded, caller name: $callerName")
                        
                        // Stop the timer
                        stopDurationTimer()
                        
                        // Show call ended notification that persists in notification center
                        showCallEndedNotification(remoteEnded = remoteEnded, persistent = true)
                        
                        // Stop foreground service without removing the notification
                        stopForeground(STOP_FOREGROUND_DETACH)
                        stopSelf()
                        return START_NOT_STICKY
                    }
                }

                // Create caller info object
                val callerInfo = CallNotificationManager.Companion.CallerInfo(
                    name = callerName,
                    avatarUrl = callerAvatar,
                    uid = senderUid,
                    duration = callDuration,
                    isAudioMuted = isAudioMuted
                )
                
                // If avatar changed, reload it
                if (avatarChanged) {
                    notificationManager.loadCallerAvatar(callerInfo) {
                        notificationManager.updateActiveCallNotification(callerInfo)
                    }
                } else {
                    // Just update the notification with current info
                    notificationManager.updateActiveCallNotification(callerInfo)
                }
                
                // Update saved state
                callStateManager.saveCallState(
                    isActive = true, 
                    callerName = callerName, 
                    callerAvatar = callerAvatar,
                    callDuration = callDuration,
                    senderUid = senderUid,
                    isAudioMuted = isAudioMuted
                )
                
                Log.d(TAG, "Call info updated - caller: $callerName, duration: $callDuration, muted: $isAudioMuted")
            }
            
            ACTION_END_CALL -> {
                // When user ends call from notification
                isCallEnded = true
                Log.d(TAG, "End call action received")
                
                // Stop the timer
                stopDurationTimer()
                
                // Show call ended notification with correct caller name
                // This will stay in notification center
                showCallEndedNotification(remoteEnded = false, persistent = true)
                
                // Clear saved state
                callStateManager.clearCallState()
                
                // Stop service without removing the notification
                stopForeground(STOP_FOREGROUND_DETACH)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        
        // Restart if killed
        return START_STICKY
    }
    
    private fun startForegroundWithNotification() {
        // Create notification channel
        notificationManager.createNotificationChannel()
        
        // Create caller info object
        val callerInfo = CallNotificationManager.Companion.CallerInfo(
            name = callerName,
            avatarUrl = callerAvatar,
            uid = senderUid,
            duration = callDuration,
            isAudioMuted = isAudioMuted
        )
        
        // Start as foreground service with initial notification
        startForeground(
            CallNotificationManager.NOTIFICATION_ID,
            notificationManager.buildActiveCallNotification(callerInfo).build()
        )
        
        // Load avatar after starting foreground to avoid ANR
        notificationManager.loadCallerAvatar(callerInfo) {
            notificationManager.updateActiveCallNotification(callerInfo)
        }
    }
    
    private fun showCallEndedNotification(remoteEnded: Boolean = false, persistent: Boolean = false) {
        // Create caller info object with ended state
        val callerInfo = CallNotificationManager.Companion.CallerInfo(
            name = callerName,
            avatarUrl = callerAvatar,
            uid = senderUid,
            duration = callDuration,
            isAudioMuted = isAudioMuted,
            isCallEnded = true,
            remoteEnded = remoteEnded
        )
        
        // Show the call ended notification (will persist in notification center)
        notificationManager.showCallEndedNotification(callerInfo, persistent)
    }
    
    private fun startDurationTimer() {
        // Cancel any existing timer
        stopDurationTimer()
        
        // Create a new timer to update call duration
        durationTimer = Timer()
        durationTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                // Increment call duration
                callDuration++
                
                // Update notification on the main thread
                handler.post {
                    val callerInfo = CallNotificationManager.Companion.CallerInfo(
                        name = callerName,
                        avatarUrl = callerAvatar,
                        uid = senderUid,
                        duration = callDuration,
                        isAudioMuted = isAudioMuted
                    )
                    notificationManager.updateActiveCallNotification(callerInfo)
                }
                
                // Update state every minute
                if (callDuration % 60 == 0 && callDuration > 0) {
                    callStateManager.saveCallState(
                        isActive = true,
                        callerName = callerName,
                        callerAvatar = callerAvatar,
                        callDuration = callDuration,
                        senderUid = senderUid,
                        isAudioMuted = isAudioMuted
                    )
                    Log.d(TAG, "Call duration: ${callDuration / 60} minutes")
                }
            }
        }, 1000, 1000) // Update every second
    }
    
    private fun stopDurationTimer() {
        durationTimer?.cancel()
        durationTimer = null
    }
    
    private fun acquireWakeLock() {
        wakeLock?.let {
            if (!it.isHeld) {
                it.acquire(3 * 60 * 60 * 1000L) // 3 hours max
                Log.d(TAG, "WakeLock acquired")
            }
        }
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.d(TAG, "WakeLock released")
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopDurationTimer()
        releaseWakeLock()
        Log.d(TAG, "Service destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}