package com.example.duckbuck.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import com.example.duckbuck.MainActivity
import java.net.URL
import java.util.Timer
import java.util.TimerTask
import java.util.concurrent.Executors

class ForegroundCallService : Service() {
    companion object {
        private const val TAG = "ForegroundCallService"
        private const val NOTIFICATION_ID = 1338
        private const val NOTIFICATION_CHANNEL_ID = "ongoing_call_service_channel"
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
        
        // Call state persistence
        private const val PREFS_NAME = "CallServicePrefs"
        private const val KEY_CALL_ACTIVE = "call_active"
        private const val KEY_CALLER_NAME = "caller_name"
        private const val KEY_CALLER_AVATAR = "caller_avatar"
        private const val KEY_CALL_DURATION = "call_duration"
        private const val KEY_CALL_MUTED = "call_muted"
        
        /**
         * Store call state in SharedPreferences
         */
        fun saveCallState(
            context: Context, 
            isActive: Boolean, 
            callerName: String?, 
            callerAvatar: String?,
            callDuration: Int,
            isAudioMuted: Boolean = false
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean(KEY_CALL_ACTIVE, isActive)
                putString(KEY_CALLER_NAME, callerName ?: "Unknown")
                putString(KEY_CALLER_AVATAR, callerAvatar)
                putInt(KEY_CALL_DURATION, callDuration)
                putBoolean(KEY_CALL_MUTED, isAudioMuted)
                apply()
            }
            
            Log.d(TAG, "Saved call state: active=$isActive, caller=$callerName, avatar=${callerAvatar != null}, duration=$callDuration")
        }
        
        /**
         * Clear call state when call ends
         */
        fun clearCallState(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putBoolean(KEY_CALL_ACTIVE, false)
                apply()
            }
            Log.d(TAG, "Cleared call active state")
        }
    }
    
    private var wakeLock: PowerManager.WakeLock? = null
    private var callerName: String = "Unknown"
    private var callerAvatar: String? = null
    private var senderUid: String? = null
    private var callDuration: Int = 0
    private var isAudioMuted: Boolean = false
    private var isCallEnded: Boolean = false
    private var callerAvatarBitmap: Bitmap? = null
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var durationTimer: Timer? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")
        
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
                
                // Load avatar image if URL is provided
                loadCallerAvatar()
                
                startForeground()
                acquireWakeLock()
                
                // Start call duration timer inside the service
                startDurationTimer()
                
                // Save call state for persistence
                saveCallState(
                    this, 
                    true, 
                    callerName, 
                    callerAvatar,
                    callDuration,
                    isAudioMuted
                )
                
                Log.d(TAG, "Service started for call with $callerName, avatar: $callerAvatar")
            }
            ACTION_STOP_SERVICE -> {
                // Stop duration timer
                stopDurationTimer()
                
                // Clear saved state
                clearCallState(this)
                
                stopSelf()
            }
            ACTION_UPDATE_CALL_INFO -> {
                val nameChanged = intent.hasExtra(EXTRA_CALLER_NAME)
                val avatarChanged = intent.hasExtra(EXTRA_CALLER_AVATAR)
                
                intent.getStringExtra(EXTRA_CALLER_NAME)?.let { callerName = it }
                intent.getStringExtra(EXTRA_CALLER_AVATAR)?.let { 
                    callerAvatar = it
                    // Reload avatar if URL changed
                    if (avatarChanged) {
                        loadCallerAvatar()
                    }
                }
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
                        // Stop the timer
                        stopDurationTimer()
                        
                        // Show call ended notification and stop service after delay
                        showCallEndedNotification()
                        handler.postDelayed({ stopSelf() }, 3000) // Show for 3 seconds
                        return START_NOT_STICKY
                    }
                }
                
                // Update notification with new information
                updateNotification(false)
                
                // Update saved state
                saveCallState(
                    this, 
                    true, 
                    callerName, 
                    callerAvatar,
                    callDuration,
                    isAudioMuted
                )
                
                Log.d(TAG, "Call info updated - caller: $callerName, duration: $callDuration, muted: $isAudioMuted")
            }
            ACTION_END_CALL -> {
                // When user ends call from notification
                isCallEnded = true
                
                // Stop the timer
                stopDurationTimer()
                
                showCallEndedNotification()
                
                // Clear saved state
                clearCallState(this)
                
                // Stop service after showing end notification
                handler.postDelayed({ stopSelf() }, 3000) // Show for 3 seconds
                return START_NOT_STICKY
            }
        }
        
        // Restart if killed
        return START_STICKY
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
                    updateNotification(false)
                }
                
                // Only log every minute to reduce spam
                if (callDuration % 60 == 0 && callDuration > 0) {
                    Log.d(TAG, "Call duration: ${formatDuration(callDuration)}")
                }
            }
        }, 1000, 1000) // Update every second
    }
    
    private fun stopDurationTimer() {
        durationTimer?.cancel()
        durationTimer = null
    }
    
    private fun loadCallerAvatar() {
        val avatarUrl = callerAvatar
        if (avatarUrl.isNullOrEmpty()) {
            Log.d(TAG, "No avatar URL provided")
            updateNotification(true)
            return
        }
        
        try {
            // Use Glide to load image
            Glide.with(applicationContext)
                .asBitmap()
                .load(avatarUrl)
                .circleCrop()
                .into(object : CustomTarget<Bitmap>() {
                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                        callerAvatarBitmap = resource
                        updateNotification(true)
                        Log.d(TAG, "Avatar loaded successfully")
                    }
                    
                    override fun onLoadFailed(errorDrawable: Drawable?) {
                        Log.d(TAG, "Failed to load avatar")
                        updateNotification(true)
                    }
                    
                    override fun onLoadCleared(placeholder: Drawable?) {
                        // Not used
                    }
                })
        } catch (e: Exception) {
            Log.e(TAG, "Error loading avatar: ${e.message}")
            updateNotification(true)
        }
    }
    
    private fun startForeground() {
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(true).build())
    }
    
    private fun updateNotification(firstTime: Boolean) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildNotification(firstTime).build())
    }
    
    private fun showCallEndedNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Call ended")
            .setContentText("Call with $callerName ended 👋")
            .setSmallIcon(android.R.drawable.ic_dialog_dialer)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            
        if (callerAvatarBitmap != null) {
            notification.setLargeIcon(callerAvatarBitmap)
        }
            
        notificationManager.notify(NOTIFICATION_ID, notification.build())
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Ongoing Call Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Shows when a call is active in background"
                setShowBadge(true)
                enableLights(true)
                enableVibration(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun buildNotification(firstTime: Boolean): NotificationCompat.Builder {
        // Create intent to launch call screen directly
        val intent = Intent(this, MainActivity::class.java).apply {
            // Add flags to clear task and create new
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            
            // Add data to navigate to call screen
            putExtra("navigate_to_call_screen", true)
            putExtra("sender_name", callerName)
            putExtra("sender_photo", callerAvatar)
            putExtra("sender_uid", senderUid)
            putExtra("from_notification", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val durationString = formatDuration(callDuration)
        
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("$callerName is talking")
            .setContentText("$durationString")
            .setSmallIcon(android.R.drawable.ic_dialog_dialer)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle("$callerName is talking")
                .bigText("$durationString\n\nOpen app to end call"))
            // Only alert once to prevent constant sound notifications
            .setOnlyAlertOnce(true)
        
        // Set large icon if available
        if (callerAvatarBitmap != null) {
            notification.setLargeIcon(callerAvatarBitmap)
        }
        
        return notification
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
    
    private fun formatDuration(durationSeconds: Int): String {
        val minutes = durationSeconds / 60
        val seconds = durationSeconds % 60
        return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopDurationTimer()
        releaseWakeLock()
        executor.shutdown()
        Log.d(TAG, "Service destroyed")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
} 