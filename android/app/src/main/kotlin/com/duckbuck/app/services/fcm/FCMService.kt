package com.duckbuck.app.services.fcm

import android.util.Log
import com.duckbuck.app.services.notification.NotificationService
import com.duckbuck.app.services.walkietalkie.WalkieTalkieService
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * FCMService - Handles Firebase Cloud Messaging
 * Routes notifications to appropriate handlers based on type
 */
class FCMService : FirebaseMessagingService() {
    
    companion object {
        private const val TAG = "FCMService"
    }
    
    private lateinit var notificationService: NotificationService
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🔥 FCM Service created")
        
        // Initialize notification service
        notificationService = NotificationService(this)
    }
    
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        Log.d(TAG, "📨 FCM message received")
        Log.d(TAG, "📨 From: ${remoteMessage.from}")
        Log.d(TAG, "📨 Message ID: ${remoteMessage.messageId}")
        Log.d(TAG, "📨 Data: ${remoteMessage.data}")
        Log.d(TAG, "📨 Notification: ${remoteMessage.notification}")
        
        try {
            // Get notification type from data payload
            val notificationType = remoteMessage.data["type"] ?: "notification"
            
            when (notificationType) {
                "notification" -> {
                    Log.i(TAG, "🔔 Routing to notification service")
                    notificationService.handleNormalNotification(remoteMessage)
                }
                "data_only" -> {
                    Log.i(TAG, "📊 Starting walkie-talkie foreground service")
                    WalkieTalkieService.startWithFCMData(this, remoteMessage.data)
                }
                else -> {
                    Log.w(TAG, "⚠️ Unknown notification type: $notificationType, treating as normal")
                    notificationService.handleNormalNotification(remoteMessage)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 Error processing FCM message", e)
        }
    }
    
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "🔑 New FCM token generated")
        Log.i(TAG, "FCM Token: $token")
        
        // TODO: Send token to your server
        // For now, just log it for testing
    }
    
    override fun onDeletedMessages() {
        super.onDeletedMessages()
        Log.w(TAG, "🗑️ Some messages were deleted before delivery")
    }
    
    override fun onMessageSent(msgId: String) {
        super.onMessageSent(msgId)
        Log.d(TAG, "✅ Message sent successfully: $msgId")
    }
    
    override fun onSendError(msgId: String, exception: Exception) {
        super.onSendError(msgId, exception)
        Log.e(TAG, "❌ Failed to send message: $msgId", exception)
    }
}
