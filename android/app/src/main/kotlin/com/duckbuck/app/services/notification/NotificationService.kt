package com.duckbuck.app.services.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import com.duckbuck.app.MainActivity
import com.duckbuck.app.R
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.IOException
import java.net.URL

/**
 * NotificationService - Handles displaying notifications in the system tray
 * Clean service focused ONLY on showing notifications and opening the app
 */
class NotificationService(private val context: Context) {
    
    companion object {
        private const val TAG = "NotificationService"
        private const val CHANNEL_ID = "duckbuck_notifications"
        private const val CHANNEL_NAME = "DuckBuck Notifications"
        private const val CHANNEL_DESCRIPTION = "Notifications for friend requests and other app activities"
        private const val NOTIFICATION_ID_BASE = 1000
        
        // Ongoing call notification constants
        private const val CALL_CHANNEL_ID = "duckbuck_ongoing_call"
        private const val CALL_CHANNEL_NAME = "Ongoing Call"
        private const val CALL_CHANNEL_DESCRIPTION = "Ongoing walkie-talkie call notifications"
        private const val ONGOING_CALL_NOTIFICATION_ID = 2000
    }
    
    init {
        createNotificationChannel()
    }
    
    /**
     * Handle normal notifications (friend requests, acceptances, etc.)
     * These show in notification tray and open the app when clicked
     */
    fun handleNormalNotification(remoteMessage: RemoteMessage) {
        try {
            // Extract notification content
            val title = remoteMessage.notification?.title 
                ?: remoteMessage.data["title"] 
                ?: "DuckBuck"
                
            val body = remoteMessage.notification?.body 
                ?: remoteMessage.data["body"] 
                ?: "You have a new notification"
            
            Log.i(TAG, "📱 Showing notification: $title - $body")
            
            // Show the notification
            showNotification(title, body, remoteMessage.data)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling normal notification", e)
        }
    }
    
    /**
     * Create notification channels for Android 8.0+ (API level 26+)
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Create normal notifications channel
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = CHANNEL_DESCRIPTION
                enableVibration(true)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(channel)
            
            // Create ongoing call notifications channel
            val callImportance = NotificationManager.IMPORTANCE_HIGH
            val callChannel = NotificationChannel(CALL_CHANNEL_ID, CALL_CHANNEL_NAME, callImportance).apply {
                description = CALL_CHANNEL_DESCRIPTION
                enableVibration(false) // No vibration for ongoing calls
                setShowBadge(false)
                setSound(null, null) // No sound for ongoing notifications
            }
            notificationManager.createNotificationChannel(callChannel)
            
            Log.d(TAG, "✅ Notification channels created: $CHANNEL_ID, $CALL_CHANNEL_ID")
        }
    }
    
    /**
     * Show notification in the system tray
     */
    private fun showNotification(title: String, body: String, data: Map<String, String>) {
        try {
            // Create intent to open the app when notification is clicked
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                
                // Pass notification data to the app
                data.forEach { (key, value) ->
                    putExtra(key, value)
                }
                
                // Add special flag to indicate it came from notification
                putExtra("opened_from_notification", true)
                putExtra("notification_title", title)
                putExtra("notification_body", body)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                System.currentTimeMillis().toInt(), // Unique request code
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Build the notification
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true) // Remove notification when clicked
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 300, 100, 300)) // Short vibration pattern
                .setShowWhen(true)
                .setWhen(System.currentTimeMillis())
                .build()
            
            // Show the notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notificationId = NOTIFICATION_ID_BASE + System.currentTimeMillis().toInt() % 1000
            notificationManager.notify(notificationId, notification)
            
            Log.i(TAG, "✅ Notification displayed successfully")
            Log.d(TAG, "📱 Notification ID: $notificationId")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show notification", e)
        }
    }
    
    /**
     * Show ongoing call notification with caller name and photo
     * Only called when call is successfully connected and all checks pass
     */
    fun showOngoingCallNotification(callerName: String, callerPhotoUrl: String?) {
        try {
            Log.i(TAG, "📞 Showing ongoing call notification for: $callerName")
            
            // Create intent to open the app and show call UI
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("opened_from_call_notification", true)
                putExtra("show_ongoing_call", true)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                ONGOING_CALL_NOTIFICATION_ID,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Load caller photo if available
            if (!callerPhotoUrl.isNullOrEmpty()) {
                loadImageAndShowNotification(callerName, callerPhotoUrl, pendingIntent)
            } else {
                showOngoingCallNotificationWithoutImage(callerName, pendingIntent)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show ongoing call notification", e)
        }
    }
    
    /**
     * Clear ongoing call notification
     * Called when call ends or fails
     */
    fun clearOngoingCallNotification() {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(ONGOING_CALL_NOTIFICATION_ID)
            Log.i(TAG, "✅ Ongoing call notification cleared")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to clear ongoing call notification", e)
        }
    }
    
    /**
     * Load caller photo from URL and show notification with image
     */
    private fun loadImageAndShowNotification(callerName: String, photoUrl: String, pendingIntent: PendingIntent) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                Glide.with(context)
                    .asBitmap()
                    .load(photoUrl)
                    .circleCrop()
                    .into(object : CustomTarget<Bitmap>() {
                        override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                            showOngoingCallNotificationWithImage(callerName, resource, pendingIntent)
                        }
                        
                        override fun onLoadCleared(placeholder: android.graphics.drawable.Drawable?) {
                            // Fallback to showing notification without image
                            showOngoingCallNotificationWithoutImage(callerName, pendingIntent)
                        }
                        
                        override fun onLoadFailed(errorDrawable: android.graphics.drawable.Drawable?) {
                            Log.w(TAG, "⚠️ Failed to load caller photo, showing notification without image")
                            showOngoingCallNotificationWithoutImage(callerName, pendingIntent)
                        }
                    })
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error loading caller photo", e)
                showOngoingCallNotificationWithoutImage(callerName, pendingIntent)
            }
        }
    }
    
    /**
     * Show ongoing call notification with caller photo
     */
    private fun showOngoingCallNotificationWithImage(callerName: String, callerPhoto: Bitmap, pendingIntent: PendingIntent) {
        try {
            val notification = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_call_notification)
                .setLargeIcon(callerPhoto)
                .setContentTitle("Ongoing Call")
                .setContentText("In call with $callerName")
                .setSubText("Tap to return to call")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true) // Makes it persistent
                .setAutoCancel(false) // Don't remove when clicked
                .setContentIntent(pendingIntent)
                .setShowWhen(false) // Don't show timestamp for ongoing calls
                .setColor(context.getColor(R.color.primary_color))
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build()
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(ONGOING_CALL_NOTIFICATION_ID, notification)
            
            Log.i(TAG, "✅ Ongoing call notification with photo displayed for: $callerName")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show ongoing call notification with image", e)
            // Fallback to showing without image
            showOngoingCallNotificationWithoutImage(callerName, pendingIntent)
        }
    }
    
    /**
     * Show ongoing call notification without caller photo
     */
    private fun showOngoingCallNotificationWithoutImage(callerName: String, pendingIntent: PendingIntent) {
        try {
            val notification = NotificationCompat.Builder(context, CALL_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_call_notification)
                .setContentTitle("Ongoing Call")
                .setContentText("In call with $callerName")
                .setSubText("Tap to return to call")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setOngoing(true) // Makes it persistent
                .setAutoCancel(false) // Don't remove when clicked
                .setContentIntent(pendingIntent)
                .setShowWhen(false) // Don't show timestamp for ongoing calls
                .setColor(context.getColor(R.color.primary_color))
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build()
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(ONGOING_CALL_NOTIFICATION_ID, notification)
            
            Log.i(TAG, "✅ Ongoing call notification displayed for: $callerName")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to show ongoing call notification", e)
        }
    }
}
