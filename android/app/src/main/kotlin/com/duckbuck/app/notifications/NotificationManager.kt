package com.duckbuck.app.notifications
import com.duckbuck.app.core.AppLogger
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
    fun showSpeakingNotification(speakerName: String) {
        try {
            AppLogger.i(TAG, "$speakerName is speaking")
            
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
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error showing speaking notification", e)
        }
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
}
