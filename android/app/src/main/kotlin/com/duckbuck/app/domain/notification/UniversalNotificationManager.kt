package com.duckbuck.app.domain.notification

import android.app.NotificationChannel
import android.app.NotificationManager as AndroidNotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import com.duckbuck.app.MainActivity
import com.duckbuck.app.R
import com.duckbuck.app.infrastructure.monitoring.AppLogger
import java.net.URL

/**
 * Universal Notification Manager
 * Handles ALL notification types: walkie-talkie, regular notifications, system alerts
 */
class UniversalNotificationManager(private val context: Context) {
    
    companion object {
        private const val TAG = "UniversalNotificationMgr"
        
        // Notification Channels
        private const val WALKIE_TALKIE_CHANNEL_ID = "walkie_talkie_channel"
        private const val GENERAL_NOTIFICATION_CHANNEL_ID = "general_notification_channel"
        private const val SYSTEM_ALERT_CHANNEL_ID = "system_alert_channel"
        
        // Notification IDs
        private const val WALKIE_SPEAKING_NOTIFICATION_ID = 3001
        private const val WALKIE_DISCONNECTION_NOTIFICATION_ID = 3002
        private const val GENERAL_NOTIFICATION_ID = 4001
        
        // Intent extras
        private const val EXTRA_NOTIFICATION_TYPE = "notification_type"
        private const val EXTRA_NOTIFICATION_DATA = "notification_data"
    }
    
    private val notificationManager: AndroidNotificationManager? = 
        context.getSystemService(Context.NOTIFICATION_SERVICE) as? AndroidNotificationManager
    
    init {
        createNotificationChannels()
    }
    
    /**
     * Create notification channels for different types
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                // Walkie-Talkie Channel (High Priority)
                NotificationChannel(
                    WALKIE_TALKIE_CHANNEL_ID,
                    "Walkie-Talkie",
                    AndroidNotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Walkie-talkie speaking and connection notifications"
                    enableLights(true)
                    enableVibration(true)
                    setShowBadge(true)
                },
                
                // General Notifications (Normal Priority)
                NotificationChannel(
                    GENERAL_NOTIFICATION_CHANNEL_ID,
                    "General Notifications",
                    AndroidNotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "General app notifications and updates"
                    enableLights(true)
                    enableVibration(true)
                    setShowBadge(true)
                },
                
                // System Alerts (High Priority)
                NotificationChannel(
                    SYSTEM_ALERT_CHANNEL_ID,
                    "System Alerts",
                    AndroidNotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Important system notifications and alerts"
                    enableLights(true)
                    enableVibration(true)
                    setShowBadge(true)
                }
            )
            
            channels.forEach { channel ->
                notificationManager?.createNotificationChannel(channel)
                AppLogger.d(TAG, "✅ Created notification channel: ${channel.id}")
            }
        }
    }
    
    /**
     * Show walkie-talkie speaking notification
     */
    fun showWalkieTalkieSpeaking(speakerName: String, speakerPhotoUrl: String? = null) {
        try {
            AppLogger.i(TAG, "📢 Showing walkie-talkie speaking notification: $speakerName")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra(EXTRA_NOTIFICATION_TYPE, "walkie_talkie_speaking")
                putExtra(EXTRA_NOTIFICATION_DATA, speakerName)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                WALKIE_SPEAKING_NOTIFICATION_ID,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val builder = NotificationCompat.Builder(context, WALKIE_TALKIE_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle("$speakerName is speaking")
                .setContentText("Tap to join walkie-talkie")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setAutoCancel(false)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .setColor(context.getColor(R.color.colorPrimary))
            
            // Load profile photo if provided
            if (!speakerPhotoUrl.isNullOrBlank()) {
                loadProfilePhotoAsync(speakerPhotoUrl) { bitmap ->
                    if (bitmap != null) {
                        builder.setLargeIcon(bitmap)
                        AppLogger.d(TAG, "✅ Updated notification with profile photo for: $speakerName")
                    }
                    notificationManager?.notify(WALKIE_SPEAKING_NOTIFICATION_ID, builder.build())
                }
            } else {
                notificationManager?.notify(WALKIE_SPEAKING_NOTIFICATION_ID, builder.build())
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error showing walkie-talkie speaking notification", e)
        }
    }
    
    /**
     * Show general notification (for regular FCM messages)
     */
    fun showGeneralNotification(
        title: String,
        message: String,
        imageUrl: String? = null,
        clickAction: String? = null,
        extraData: Map<String, String>? = null
    ) {
        try {
            AppLogger.i(TAG, "📢 Showing general notification: $title")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra(EXTRA_NOTIFICATION_TYPE, "general")
                putExtra(EXTRA_NOTIFICATION_DATA, title)
                
                // Add click action if provided
                clickAction?.let { putExtra("click_action", it) }
                
                // Add extra data if provided
                extraData?.forEach { (key, value) ->
                    putExtra("extra_$key", value)
                }
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                GENERAL_NOTIFICATION_ID,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val builder = NotificationCompat.Builder(context, GENERAL_NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setColor(context.getColor(R.color.colorPrimary))
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            
            // Load image if provided
            if (!imageUrl.isNullOrBlank()) {
                loadImageAsync(imageUrl) { bitmap ->
                    if (bitmap != null) {
                        builder.setLargeIcon(bitmap)
                        builder.setStyle(
                            NotificationCompat.BigPictureStyle()
                                .bigPicture(bitmap)
                                .setBigContentTitle(title)
                                .setSummaryText(message)
                        )
                        AppLogger.d(TAG, "✅ Updated notification with image")
                    }
                    notificationManager?.notify(GENERAL_NOTIFICATION_ID, builder.build())
                }
            } else {
                notificationManager?.notify(GENERAL_NOTIFICATION_ID, builder.build())
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error showing general notification", e)
        }
    }
    
    /**
     * Show system alert notification (high priority)
     */
    fun showSystemAlert(title: String, message: String, actionRequired: Boolean = false) {
        try {
            AppLogger.i(TAG, "🚨 Showing system alert: $title")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra(EXTRA_NOTIFICATION_TYPE, "system_alert")
                putExtra(EXTRA_NOTIFICATION_DATA, title)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                GENERAL_NOTIFICATION_ID + 1,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val builder = NotificationCompat.Builder(context, SYSTEM_ALERT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(title)
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setAutoCancel(!actionRequired)
                .setOngoing(actionRequired)
                .setContentIntent(pendingIntent)
                .setColor(context.getColor(android.R.color.holo_orange_dark))
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            
            notificationManager?.notify(GENERAL_NOTIFICATION_ID + 1, builder.build())
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error showing system alert", e)
        }
    }
    
    /**
     * Dismiss walkie-talkie speaking notification
     */
    fun dismissWalkieTalkieSpeaking() {
        try {
            notificationManager?.cancel(WALKIE_SPEAKING_NOTIFICATION_ID)
            AppLogger.d(TAG, "✅ Dismissed walkie-talkie speaking notification")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error dismissing walkie-talkie notification", e)
        }
    }
    
    /**
     * Dismiss general notification
     */
    fun dismissGeneralNotification() {
        try {
            notificationManager?.cancel(GENERAL_NOTIFICATION_ID)
            AppLogger.d(TAG, "✅ Dismissed general notification")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error dismissing general notification", e)
        }
    }
    
    /**
     * Load profile photo asynchronously
     */
    private fun loadProfilePhotoAsync(photoUrl: String, callback: (Bitmap?) -> Unit) {
        Thread {
            try {
                AppLogger.d(TAG, "Loading profile photo from: $photoUrl")
                val url = URL(photoUrl)
                val bitmap = BitmapFactory.decodeStream(url.openConnection().getInputStream())
                
                if (bitmap != null) {
                    // Create circular bitmap
                    val circularBitmap = createCircularBitmap(bitmap)
                    AppLogger.d(TAG, "✅ Successfully loaded bitmap (${bitmap.width}x${bitmap.height}), creating circular version")
                    callback(circularBitmap)
                } else {
                    AppLogger.w(TAG, "⚠️ Failed to decode bitmap from URL")
                    callback(null)
                }
                
            } catch (e: Exception) {
                AppLogger.e(TAG, "❌ Error loading profile photo", e)
                callback(null)
            }
        }.start()
    }
    
    /**
     * Load image asynchronously
     */
    private fun loadImageAsync(imageUrl: String, callback: (Bitmap?) -> Unit) {
        Thread {
            try {
                AppLogger.d(TAG, "Loading image from: $imageUrl")
                val url = URL(imageUrl)
                val bitmap = BitmapFactory.decodeStream(url.openConnection().getInputStream())
                
                if (bitmap != null) {
                    AppLogger.d(TAG, "✅ Successfully loaded image bitmap (${bitmap.width}x${bitmap.height})")
                    callback(bitmap)
                } else {
                    AppLogger.w(TAG, "⚠️ Failed to decode image bitmap from URL")
                    callback(null)
                }
                
            } catch (e: Exception) {
                AppLogger.e(TAG, "❌ Error loading image", e)
                callback(null)
            }
        }.start()
    }
    
    /**
     * Create circular bitmap for profile photos
     */
    private fun createCircularBitmap(bitmap: Bitmap): Bitmap {
        // Implementation for circular bitmap
        val size = minOf(bitmap.width, bitmap.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(output)
        val paint = android.graphics.Paint().apply {
            isAntiAlias = true
            color = android.graphics.Color.BLACK
        }
        
        val rect = android.graphics.Rect(0, 0, size, size)
        val radius = size / 2f
        
        canvas.drawARGB(0, 0, 0, 0)
        canvas.drawCircle(radius, radius, radius, paint)
        
        paint.xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(bitmap, rect, rect, paint)
        
        return output
    }
}
