package com.duckbuck.app.notifications

import android.app.NotificationChannel
import android.app.NotificationManager as AndroidNotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.duckbuck.app.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.net.URL

/**
 * Walkie-Talkie Notification Manager - Handles speaking notifications only
 * Shows notifications when users are actively speaking in walkie-talkie channels
 */
class CallNotificationManager(private val context: Context) {
    
    companion object {
        private const val TAG = "WalkieTalkieNotificationMgr"
        private const val SPEAKING_NOTIFICATION_CHANNEL_ID = "walkie_talkie_speaking_channel"
        private const val SPEAKING_NOTIFICATION_ID = 3001
    }
    
    private val notificationManager: AndroidNotificationManager? = 
        context.getSystemService(Context.NOTIFICATION_SERVICE) as? AndroidNotificationManager
    
    init {
        createNotificationChannel()
    }
    
    /**
     * Show speaking notification when someone is talking in walkie-talkie
     */
    fun showSpeakingNotification(
        speakerName: String,
        channelName: String
    ) {
        try {
            Log.i(TAG, "📢 $speakerName is speaking in $channelName")
            
            val notification = NotificationCompat.Builder(context, SPEAKING_NOTIFICATION_CHANNEL_ID)
                .setContentTitle("🎙️ $speakerName is speaking")
                .setContentText("Channel: $channelName")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setAutoCancel(false)
                .setOngoing(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .build()
            
            notificationManager?.notify(SPEAKING_NOTIFICATION_ID, notification)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing speaking notification", e)
        }
    }
    
    /**
     * Show disconnection notification when leaving walkie-talkie channel
     */
    fun showDisconnectionNotification(channelName: String) {
        try {
            Log.i(TAG, "📻 Disconnected from walkie-talkie: $channelName")
            
            val notification = NotificationCompat.Builder(context, SPEAKING_NOTIFICATION_CHANNEL_ID)
                .setContentTitle("📻 Walkie-Talkie Disconnected")
                .setContentText("Left channel: $channelName")
                .setSmallIcon(android.R.drawable.ic_media_pause)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setAutoCancel(true)
                .setTimeoutAfter(3000) // Auto-dismiss after 3 seconds
                .build()
            
            notificationManager?.notify(SPEAKING_NOTIFICATION_ID, notification)
            
            // Clear notification after showing disconnection message
            clearNotificationsDelayed()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing disconnection notification", e)
        }
    }
    
    /**
     * Show channel joined notification (works in all app states)
     */
    fun showChannelJoinedNotification(
        channelName: String,
        userName: String = "You"
    ) {
        try {
            Log.i(TAG, "📻 $userName joined walkie-talkie channel: $channelName")
            
            val notification = NotificationCompat.Builder(context, SPEAKING_NOTIFICATION_CHANNEL_ID)
                .setContentTitle("📻 Joined Walkie-Talkie")
                .setContentText("$userName joined: $channelName")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setAutoCancel(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setTimeoutAfter(5000) // Auto-dismiss after 5 seconds
                .build()
            
            notificationManager?.notify(SPEAKING_NOTIFICATION_ID + 1, notification)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing channel joined notification", e)
        }
    }

    /**
     * Clear all walkie-talkie notifications
     */
    fun clearWalkieTalkieNotifications() {
        try {
            notificationManager?.cancel(SPEAKING_NOTIFICATION_ID)
            Log.i(TAG, "✅ Walkie-talkie notifications cleared")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error clearing notifications", e)
        }
    }
    
    /**
     * Create notification channel for walkie-talkie notifications
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SPEAKING_NOTIFICATION_CHANNEL_ID,
                "Walkie-Talkie Speaking",
                AndroidNotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications when someone is speaking in walkie-talkie channels"
                enableVibration(true)
                setShowBadge(true)
                enableLights(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager?.createNotificationChannel(channel)
            Log.d(TAG, "✅ Walkie-talkie notification channel created")
        }
    }
    
    /**
     * Clear notifications with delay (for disconnection message)
     */
    private fun clearNotificationsDelayed() {
        CoroutineScope(Dispatchers.Main).launch {
            kotlinx.coroutines.delay(3000) // Wait 3 seconds
            clearWalkieTalkieNotifications()
        }
    }
}
