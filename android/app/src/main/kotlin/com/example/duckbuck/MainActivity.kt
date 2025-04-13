package com.example.duckbuck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.PowerManager
import android.content.Context
import android.os.Build
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.Notification
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodCall
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import com.example.duckbuck.service.ForegroundCallService
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.BinaryMessenger

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.duckbuck/background_call"
    private val NAVIGATION_CHANNEL = "com.example.duckbuck/navigation"
    private var wakeLock: PowerManager.WakeLock? = null
    private var isCallServiceRunning = false
    private var callDurationSeconds = 0
    private val handler = Handler(Looper.getMainLooper())
    private var durationRunnable: Runnable? = null
    private var pendingNotificationNavigation = false
    private var pendingCallData: Map<String, Any?>? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up the method channel for background call service
        setupBackgroundCallChannel(flutterEngine.dartExecutor.binaryMessenger)
        
        // Set up the navigation channel
        setupNavigationChannel(flutterEngine.dartExecutor.binaryMessenger)
        
        // Check if we were opened from notification
        handleNotificationIntent(intent)
    }
    
    private fun setupBackgroundCallChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    val callerName = call.argument<String>("callerName") ?: "Unknown"
                    val callerAvatar = call.argument<String>("callerAvatar")
                    val initialDurationSeconds = call.argument<Int>("initialDurationSeconds") ?: 0
                    val isAudioMuted = call.argument<Boolean>("isAudioMuted") ?: false
                    val senderUid = call.argument<String>("senderUid")
                    
                    Log.d(TAG, "Starting service with caller: $callerName, avatar: $callerAvatar")
                    startBackgroundService(callerName, callerAvatar, initialDurationSeconds, isAudioMuted, senderUid)
                    result.success(true)
                }
                "stopBackgroundService" -> {
                    stopBackgroundService()
                    result.success(null)
                }
                "updateCallAttributes" -> {
                    val isAudioMuted = call.argument<Boolean>("isAudioMuted")
                    val callerName = call.argument<String>("callerName")
                    val callerAvatar = call.argument<String>("callerAvatar")
                    val isCallEnded = call.argument<Boolean>("isCallEnded")
                    val senderUid = call.argument<String>("senderUid")
                    
                    updateCallAttributes(isAudioMuted, callerName, callerAvatar, isCallEnded, senderUid)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun setupNavigationChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPendingNavigation" -> {
                    if (pendingNotificationNavigation && pendingCallData != null) {
                        result.success(pendingCallData)
                        pendingNotificationNavigation = false
                        pendingCallData = null
                    } else {
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }
    
    private fun handleNotificationIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("navigate_to_call_screen", false) == true) {
            val senderName = intent.getStringExtra("sender_name")
            val senderPhoto = intent.getStringExtra("sender_photo")
            val senderUid = intent.getStringExtra("sender_uid")
            val fromNotification = intent.getBooleanExtra("from_notification", false)
            
            if (senderName != null && senderUid != null) {
                Log.d(TAG, "Handling notification navigation to call screen")
                
                // Create a map to pass to Flutter
                pendingCallData = mapOf(
                    "sender_name" to senderName,
                    "sender_photo" to senderPhoto,
                    "sender_uid" to senderUid,
                    "from_notification" to fromNotification
                )
                
                pendingNotificationNavigation = true
            }
        }
    }
    
    private fun startBackgroundService(
        callerName: String,
        callerAvatar: String?,
        initialDurationSeconds: Int,
        isAudioMuted: Boolean,
        senderUid: String?
    ) {
        if (isCallServiceRunning) {
            Log.d(TAG, "Service already running")
            return
        }
        
        // Create temporary wake lock until service starts
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "DuckBuck:CallWakeLock"
        )
        wakeLock?.acquire(30000L) // 30 seconds timeout for service to start
        
        // Store duration for timer updates
        callDurationSeconds = initialDurationSeconds
        
        // Start the foreground service
        val serviceIntent = Intent(this, ForegroundCallService::class.java).apply {
            action = ForegroundCallService.ACTION_START_SERVICE
            putExtra(ForegroundCallService.EXTRA_CALLER_NAME, callerName)
            putExtra(ForegroundCallService.EXTRA_CALLER_AVATAR, callerAvatar)
            putExtra(ForegroundCallService.EXTRA_CALL_DURATION, initialDurationSeconds)
            putExtra(ForegroundCallService.EXTRA_IS_MUTED, isAudioMuted)
            putExtra(ForegroundCallService.EXTRA_SENDER_UID, senderUid)
        }
        
        // Start service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        isCallServiceRunning = true
        Log.d(TAG, "Background service started with ${initialDurationSeconds}s initial duration")
        
        // Release initial wake lock after service is started
        handler.postDelayed({
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
        }, 5000)
    }
    
    private fun stopBackgroundService() {
        if (!isCallServiceRunning) {
            Log.d(TAG, "Service not running")
            return
        }
        
        // Stop the foreground service
        val serviceIntent = Intent(this, ForegroundCallService::class.java).apply {
            action = ForegroundCallService.ACTION_STOP_SERVICE
        }
        stopService(serviceIntent)
        
        isCallServiceRunning = false
        Log.d(TAG, "Background service stopped")
    }
    
    private fun updateCallAttributes(
        isAudioMuted: Boolean?,
        callerName: String?,
        callerAvatar: String?,
        isCallEnded: Boolean?,
        senderUid: String?
    ) {
        if (!isCallServiceRunning) return
        
        // Update service with new call information
        val serviceIntent = Intent(this, ForegroundCallService::class.java).apply {
            action = ForegroundCallService.ACTION_UPDATE_CALL_INFO
            
            if (isAudioMuted != null) {
                putExtra(ForegroundCallService.EXTRA_IS_MUTED, isAudioMuted)
            }
            
            if (callerName != null) {
                putExtra(ForegroundCallService.EXTRA_CALLER_NAME, callerName)
            }
            
            if (callerAvatar != null) {
                putExtra(ForegroundCallService.EXTRA_CALLER_AVATAR, callerAvatar)
            }
            
            if (senderUid != null) {
                putExtra(ForegroundCallService.EXTRA_SENDER_UID, senderUid)
            }
            
            if (isCallEnded != null) {
                putExtra(ForegroundCallService.EXTRA_CALL_ENDED, isCallEnded)
            }
        }
        
        // Update service
        startService(serviceIntent)
    }
    
    private fun formatDuration(durationSeconds: Int): String {
        val minutes = durationSeconds / 60
        val seconds = durationSeconds % 60
        return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Only release resources, don't stop service
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
} 