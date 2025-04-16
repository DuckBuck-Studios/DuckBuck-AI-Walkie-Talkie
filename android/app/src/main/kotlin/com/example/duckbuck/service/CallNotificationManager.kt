package com.example.duckbuck.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import com.example.duckbuck.MainActivity

/**
 * Manages call-related notifications, separating this concern from the ForegroundCallService.
 */
class CallNotificationManager(private val context: Context) {
    companion object {
        private const val TAG = "CallNotificationManager"
        const val NOTIFICATION_ID = 1338
        const val NOTIFICATION_CHANNEL_ID = "ongoing_call_service_channel"
        
        // Caller state data
        data class CallerInfo(
            val name: String,
            val avatarUrl: String?,
            val uid: String?,
            val duration: Int,
            val isAudioMuted: Boolean = false,
            val isCallEnded: Boolean = false,
            val remoteEnded: Boolean = false
        ) {
            fun getFormattedDuration(): String {
                val minutes = duration / 60
                val seconds = duration % 60
                return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
            }
        }
    }
    
    private var callerAvatarBitmap: Bitmap? = null
    private val handler = Handler(Looper.getMainLooper())
    
    /**
     * Creates the notification channel for call notifications (API 26+)
     */
    fun createNotificationChannel() {
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
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    /**
     * Builds a notification for an active call
     */
    fun buildActiveCallNotification(callerInfo: CallerInfo): NotificationCompat.Builder {
        // Create intent to launch call screen directly
        val intent = Intent(context, MainActivity::class.java).apply {
            // Add flags to clear task and create new
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            
            // Add data to navigate to call screen
            putExtra("navigate_to_call_screen", true)
            putExtra("sender_name", callerInfo.name)
            putExtra("sender_photo", callerInfo.avatarUrl)
            putExtra("sender_uid", callerInfo.uid)
            putExtra("from_notification", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val durationString = callerInfo.getFormattedDuration()
        
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("${callerInfo.name} is talking")
            .setContentText("$durationString")
            .setSmallIcon(android.R.drawable.ic_dialog_dialer)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle()
                .setBigContentTitle("${callerInfo.name} is talking")
                .bigText("$durationString"))
            // Only alert once to prevent constant sound notifications
            .setOnlyAlertOnce(true)
        
        // Set large icon if available
        if (callerAvatarBitmap != null) {
            notification.setLargeIcon(callerAvatarBitmap)
        }
        
        return notification
    }
    
    /**
     * Shows call ended notification
     */
    fun showCallEndedNotification(callerInfo: CallerInfo, persistent: Boolean = false) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Use caller's name if available, otherwise use "Unknown"
        val displayName = if (callerInfo.name.isNotEmpty()) callerInfo.name else "Unknown"
        
        // Determine appropriate message based on who ended the call
        val title = "Call ended"
        val message = if (callerInfo.remoteEnded) {
            "Call with $displayName ended" // Remote user ended
        } else {
            "Call with $displayName ended" // Local user ended
        }

        // Build notification that will persist in notification center
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_dialer)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            // Setting autoCancel to false for persistent notifications
            .setAutoCancel(!persistent)
            // For Android 8.0+, prevent notification timeout
            .setTimeoutAfter(if (persistent) 0 else 60000) // 0 means no timeout
            
        if (callerAvatarBitmap != null) {
            notification.setLargeIcon(callerAvatarBitmap)
        }
            
        notificationManager.notify(NOTIFICATION_ID, notification.build())
    }
    
    /**
     * Updates an existing notification
     */
    fun updateActiveCallNotification(callerInfo: CallerInfo) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildActiveCallNotification(callerInfo).build())
    }
    
    /**
     * Loads the caller avatar asynchronously and updates the notification when ready
     */
    fun loadCallerAvatar(callerInfo: CallerInfo, onAvatarLoaded: () -> Unit) {
        val avatarUrl = callerInfo.avatarUrl
        if (avatarUrl.isNullOrEmpty()) {
            Log.d(TAG, "No avatar URL provided")
            onAvatarLoaded()
            return
        }
        
        try {
            // Use Glide to load image
            Glide.with(context.applicationContext)
                .asBitmap()
                .load(avatarUrl)
                .circleCrop()
                .into(object : CustomTarget<Bitmap>() {
                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                        callerAvatarBitmap = resource
                        handler.post {
                            onAvatarLoaded()
                        }
                        Log.d(TAG, "Avatar loaded successfully")
                    }
                    
                    override fun onLoadFailed(errorDrawable: Drawable?) {
                        Log.d(TAG, "Failed to load avatar")
                        handler.post {
                            onAvatarLoaded()
                        }
                    }
                    
                    override fun onLoadCleared(placeholder: Drawable?) {
                        // Not used
                    }
                })
        } catch (e: Exception) {
            Log.e(TAG, "Error loading avatar: ${e.message}")
            onAvatarLoaded()
        }
    }
}