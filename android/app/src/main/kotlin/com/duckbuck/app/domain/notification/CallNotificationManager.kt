package com.duckbuck.app.domain.notification
import com.duckbuck.app.infrastructure.monitoring.AppLogger
import com.duckbuck.app.R
import android.app.NotificationChannel
import android.app.NotificationManager as AndroidNotificationManager
import android.app.PendingIntent
import android.app.Notification
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import com.duckbuck.app.MainActivity
import java.net.URL

/**
 * Centralized Walkie-Talkie Notification Manager 
 * Handles ALL walkie-talkie notifications: service, speaking, and disconnection
 */
class CallNotificationManager(private val context: Context) {
    
    companion object {
        private const val TAG = "WalkieTalkieNotificationMgr"
        
        // Notification Channels
        private const val SPEAKING_NOTIFICATION_CHANNEL_ID = "walkie_talkie_speaking_channel"
        
        // Notification IDs
        private const val SPEAKING_NOTIFICATION_ID = 3001
        private const val DISCONNECTION_NOTIFICATION_ID = 3002
    }
    
    private val notificationManager: AndroidNotificationManager? = 
        context.getSystemService(Context.NOTIFICATION_SERVICE) as? AndroidNotificationManager
    
    init {
        createNotificationChannels()
    }
    
    /**
     * Create notification channels for walkie-talkie
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Speaking notification channel (high importance)
            val speakingChannel = NotificationChannel(
                SPEAKING_NOTIFICATION_CHANNEL_ID,
                "Walkie-Talkie Speaking",
                AndroidNotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when someone is speaking"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            
            notificationManager?.createNotificationChannel(speakingChannel)
        }
    }
    
    /**
     * Show speaking notification when someone is talking in walkie-talkie
     */
    fun showSpeakingNotification(speakerName: String, speakerPhotoUrl: String? = null) {
        try {
            AppLogger.i(TAG, "$speakerName is speaking")
            
            // Show notification immediately without photo, then update with photo if available
            showNotificationWithoutPhoto(speakerName)
            
            // Load profile photo asynchronously and update notification
            if (speakerPhotoUrl != null) {
                AppLogger.d(TAG, "🖼️ Attempting to load profile photo for: $speakerName")
                loadBitmapFromUrlAsync(speakerPhotoUrl) { bitmap ->
                    if (bitmap != null) {
                        AppLogger.i(TAG, "✅ Profile photo loaded successfully, updating notification")
                        showNotificationWithPhoto(speakerName, bitmap)
                    } else {
                        AppLogger.w(TAG, "❌ Failed to load profile photo, notification will remain without photo")
                    }
                }
            } else {
                AppLogger.d(TAG, "📷 No profile photo URL provided for: $speakerName")
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error showing speaking notification", e)
        }
    }
    
    /**
     * Show notification without profile photo (immediate display)
     */
    private fun showNotificationWithoutPhoto(speakerName: String) {
        val notification = NotificationCompat.Builder(context, SPEAKING_NOTIFICATION_CHANNEL_ID)
            .setContentTitle("$speakerName is speaking")
            .setSmallIcon(R.drawable.ic_speaker)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        notificationManager?.notify(SPEAKING_NOTIFICATION_ID, notification)
    }
    
    /**
     * Update notification with profile photo (after async load)
     */
    private fun showNotificationWithPhoto(speakerName: String, profileBitmap: Bitmap) {
        val notification = NotificationCompat.Builder(context, SPEAKING_NOTIFICATION_CHANNEL_ID)
            .setContentTitle("$speakerName is speaking")
            .setSmallIcon(R.drawable.ic_speaker)
            .setLargeIcon(profileBitmap)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        notificationManager?.notify(SPEAKING_NOTIFICATION_ID, notification)
        AppLogger.d(TAG, "✅ Updated notification with profile photo for: $speakerName")
    }
    
    /**
     * Show disconnection notification when leaving walkie-talkie channel
     */
    fun showDisconnectionNotification(userName: String = "You") {
        try {
            AppLogger.i(TAG, "📻 $userName over")
            
            val notification = NotificationCompat.Builder(context, SPEAKING_NOTIFICATION_CHANNEL_ID)
                .setContentTitle("📻 $userName over")
                .setSmallIcon(R.drawable.ic_speaker)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setAutoCancel(true)
                .setOngoing(false)
                .build()
            
            notificationManager?.notify(DISCONNECTION_NOTIFICATION_ID, notification)
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error showing disconnection notification", e)
        }
    }
    
    /**
     * Clear only the speaking notification (keep disconnection notifications)
     */
    fun clearSpeakingNotification() {
        try {
            notificationManager?.cancel(SPEAKING_NOTIFICATION_ID)
            AppLogger.i(TAG, "✅ Speaking notification cleared")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error clearing speaking notification", e)
        }
    }
    
    /**
     * Clear all walkie-talkie notifications
     */
    fun clearWalkieTalkieNotifications() {
        try {
            notificationManager?.cancel(SPEAKING_NOTIFICATION_ID)
            notificationManager?.cancel(DISCONNECTION_NOTIFICATION_ID)
            AppLogger.i(TAG, "✅ Walkie-talkie notifications cleared")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error clearing notifications", e)
        }
    }
    
    /**
     * Load bitmap from URL for profile photo asynchronously
     * Runs on background thread to avoid NetworkOnMainThreadException
     */
    private fun loadBitmapFromUrlAsync(url: String, callback: (Bitmap?) -> Unit) {
        Thread {
            try {
                // Decode HTML entities in URL if present
                val decodedUrl = url
                    .replace("&#x2F;", "/")
                    .replace("&amp;", "&")
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&quot;", "\"")
                
                AppLogger.d(TAG, "Loading profile photo from: $decodedUrl")
                
                val connection = URL(decodedUrl).openConnection()
                connection.connectTimeout = 5000 // 5 second timeout
                connection.readTimeout = 5000
                connection.doInput = true
                connection.connect()
                
                val inputStream = connection.getInputStream()
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream.close()
                
                // Create circular bitmap for better appearance
                val circularBitmap = if (bitmap != null) {
                    AppLogger.d(TAG, "✅ Successfully loaded bitmap (${bitmap.width}x${bitmap.height}), creating circular version")
                    createCircularBitmap(bitmap)
                } else {
                    AppLogger.w(TAG, "❌ Failed to decode bitmap from URL")
                    null
                }
                
                AppLogger.d(TAG, "🔄 Posting callback to main thread with bitmap: ${if (circularBitmap != null) "present" else "null"}")
                
                // Run callback on main thread
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    AppLogger.d(TAG, "📱 Running callback on main thread")
                    callback(circularBitmap)
                }
                
            } catch (e: Exception) {
                AppLogger.e(TAG, "Error loading profile photo", e)
                // Run callback on main thread with null result
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    AppLogger.d(TAG, "📱 Running error callback on main thread")
                    callback(null)
                }
            }
        }.start()
    }
    
    /**
     * Load bitmap from URL for profile photo
     * Returns a circular bitmap suitable for notification large icon
     */
    private fun loadBitmapFromUrl(url: String): Bitmap? {
        return try {
            AppLogger.d(TAG, "Loading profile photo from: $url")
            
            val connection = URL(url).openConnection()
            connection.connectTimeout = 5000 // 5 second timeout
            connection.readTimeout = 5000
            connection.doInput = true
            connection.connect()
            
            val inputStream = connection.getInputStream()
            val bitmap = BitmapFactory.decodeStream(inputStream)
            inputStream.close()
            
            // Create circular bitmap for better appearance
            if (bitmap != null) {
                createCircularBitmap(bitmap)
            } else {
                AppLogger.w(TAG, "Failed to decode bitmap from URL")
                null
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error loading profile photo", e)
            null
        }
    }
    
    /**
     * Create a circular bitmap from the original bitmap
     */
    private fun createCircularBitmap(originalBitmap: Bitmap): Bitmap {
        val size = minOf(originalBitmap.width, originalBitmap.height)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        
        val canvas = android.graphics.Canvas(output)
        val paint = android.graphics.Paint().apply {
            isAntiAlias = true
            color = android.graphics.Color.RED
        }
        
        // Draw circle
        val radius = size / 2f
        canvas.drawCircle(radius, radius, radius, paint)
        
        // Apply source-in blend mode to crop image to circle
        paint.xfermode = android.graphics.PorterDuffXfermode(android.graphics.PorterDuff.Mode.SRC_IN)
        
        // Calculate position to center the image
        val left = (size - originalBitmap.width) / 2f
        val top = (size - originalBitmap.height) / 2f
        
        canvas.drawBitmap(originalBitmap, left, top, paint)
        
        return output
    }
}
