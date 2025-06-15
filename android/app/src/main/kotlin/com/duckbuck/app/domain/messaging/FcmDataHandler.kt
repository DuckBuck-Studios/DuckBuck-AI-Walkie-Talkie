package com.duckbuck.app.domain.messaging
import com.duckbuck.app.infrastructure.monitoring.AppLogger

import com.google.firebase.messaging.RemoteMessage

/**
 * FCM Data Handler responsible for processing FCM data payloads
 * Extracts and validates both call-related data and general notification data from FCM messages
 */
object FcmDataHandler {
    
    private const val TAG = "FcmDataHandler"
    
    /**
     * Data class representing extracted call data from FCM message
     */
    data class CallData(
        val token: String,
        val uid: Int,
        val channelId: String,
        val callName: String,
        val callerPhoto: String?,
        val timestamp: Long
    )
    
    /**
     * Data class representing general notification data from FCM message
     */
    data class GeneralNotificationData(
        val title: String,
        val message: String,
        val imageUrl: String?,
        val clickAction: String?,
        val extraData: Map<String, String>?
    )
    
    /**
     * Extract call data from FCM message
     * @param remoteMessage The FCM message to process
     * @return CallData if valid call data found, null otherwise
     */
    fun extractCallData(remoteMessage: RemoteMessage): CallData? {
        try {
            AppLogger.d(TAG, "Extracting call data from FCM message: ${remoteMessage.messageId}")
            
            // Validate message structure
            if (!isValidCallMessage(remoteMessage)) {
                return null
            }
            
            val data = remoteMessage.data
            
            val agoraToken = data["agora_token"]
            val agoraUid = data["agora_uid"]?.toIntOrNull()
            val agoraChannelId = data["agora_channelid"]
            val callName = data["call_name"]
            val callerPhoto = data["caller_photo"]
            val timestamp = data["timestamp"]?.toLongOrNull()
            
            // Validate required fields
            if (agoraToken.isNullOrBlank() || agoraUid == null || 
                agoraChannelId.isNullOrBlank() || callName.isNullOrBlank() || timestamp == null) {
                AppLogger.w(TAG, "Missing required call data fields")
                return null
            }
            
            val callData = CallData(
                token = agoraToken,
                uid = agoraUid,
                channelId = agoraChannelId,
                callName = callName,
                callerPhoto = callerPhoto?.takeIf { it.isNotBlank() },
                timestamp = timestamp
            )
            
            AppLogger.i(TAG, "✅ Extracted valid call data: Channel=${callData.channelId}, Caller=${callData.callName}")
            return callData
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error extracting call data from FCM message", e)
            return null
        }
    }
    
    /**
     * Validate if the FCM message is a valid call message
     * @param remoteMessage The message to validate
     * @return true if valid call message, false otherwise
     */
    fun isValidCallMessage(remoteMessage: RemoteMessage): Boolean {
        try {
            // CRITICAL: Only handle data-only messages (no notification field)
            if (remoteMessage.notification != null) {
                AppLogger.d(TAG, "Message contains notification field - not a data-only call message")
                return false
            }
            
            // Only process if message contains data
            if (remoteMessage.data.isEmpty()) {
                AppLogger.d(TAG, "Message contains no data - not a call message")
                return false
            }
            
            val data = remoteMessage.data
            
            // Check for presence of required Agora fields
            val hasAgoraToken = data.containsKey("agora_token") && !data["agora_token"].isNullOrBlank()
            val hasAgoraUid = data.containsKey("agora_uid") && data["agora_uid"]?.toIntOrNull() != null
            val hasChannelId = data.containsKey("agora_channelid") && !data["agora_channelid"].isNullOrBlank()
            val hasCallName = data.containsKey("call_name") && !data["call_name"].isNullOrBlank()
            val hasTimestamp = data.containsKey("timestamp") && data["timestamp"]?.toLongOrNull() != null
            
            val isValidCall = hasAgoraToken && hasAgoraUid && hasChannelId && hasCallName && hasTimestamp
            
            if (isValidCall) {
                AppLogger.d(TAG, "✅ Valid call message detected")
            } else {
                AppLogger.d(TAG, "❌ Invalid call message - missing required fields")
            }
            
            return isValidCall
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error validating call message", e)
            return false
        }
    }
    
    /**
     * Extract general notification data from FCM message
     * @param remoteMessage The FCM message to process
     * @return GeneralNotificationData if valid notification found, null otherwise
     */
    fun extractGeneralNotificationData(remoteMessage: RemoteMessage): GeneralNotificationData? {
        try {
            AppLogger.d(TAG, "Extracting general notification data from FCM message: ${remoteMessage.messageId}")
            
            // For general notifications, we check both notification field and data field
            val notification = remoteMessage.notification
            val data = remoteMessage.data
            
            // Get title and message (prioritize notification field, fallback to data)
            val title = notification?.title ?: data["title"] ?: data["notification_title"]
            val message = notification?.body ?: data["message"] ?: data["body"] ?: data["notification_body"]
            
            if (title.isNullOrBlank() || message.isNullOrBlank()) {
                AppLogger.d(TAG, "Missing title or message in general notification")
                return null
            }
            
            // Extract optional fields
            val imageUrl = notification?.imageUrl?.toString() ?: data["image"] ?: data["image_url"]
            val clickAction = data["click_action"]
            
            // Extract extra data (any key-value pairs that aren't standard notification fields)
            val standardKeys = setOf("title", "message", "body", "notification_title", "notification_body", 
                                   "image", "image_url", "click_action", "timestamp")
            val extraData = data.filterKeys { !standardKeys.contains(it) }.takeIf { it.isNotEmpty() }
            
            val notificationData = GeneralNotificationData(
                title = title,
                message = message,
                imageUrl = imageUrl?.takeIf { it.isNotBlank() },
                clickAction = clickAction?.takeIf { it.isNotBlank() },
                extraData = extraData
            )
            
            AppLogger.i(TAG, "✅ Extracted general notification: Title=$title")
            return notificationData
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error extracting general notification data", e)
            return null
        }
    }
    
    /**
     * Determine the type of FCM message
     * @param remoteMessage The FCM message to analyze
     * @return MessageType enum indicating the type of message
     */
    fun getMessageType(remoteMessage: RemoteMessage): MessageType {
        return when {
            isValidCallMessage(remoteMessage) -> MessageType.WALKIE_TALKIE_CALL
            isGeneralNotification(remoteMessage) -> MessageType.GENERAL_NOTIFICATION
            else -> MessageType.UNKNOWN
        }
    }
    
    /**
     * Check if the FCM message is a general notification
     */
    fun isGeneralNotification(remoteMessage: RemoteMessage): Boolean {
        try {
            // General notifications can have either notification field or data with title/message
            val hasNotificationField = remoteMessage.notification != null
            val hasDataTitle = !remoteMessage.data["title"].isNullOrBlank() || 
                             !remoteMessage.data["notification_title"].isNullOrBlank()
            val hasDataMessage = !remoteMessage.data["message"].isNullOrBlank() || 
                                !remoteMessage.data["body"].isNullOrBlank() || 
                                !remoteMessage.data["notification_body"].isNullOrBlank()
            
            val isGeneral = hasNotificationField || (hasDataTitle && hasDataMessage)
            
            if (isGeneral) {
                AppLogger.d(TAG, "✅ General notification detected")
            }
            
            return isGeneral
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error checking general notification", e)
            return false
        }
    }
    
    /**
     * Enum representing different types of FCM messages
     */
    enum class MessageType {
        WALKIE_TALKIE_CALL,
        GENERAL_NOTIFICATION,
        UNKNOWN
    }
    
    /**
     * Log call data for debugging purposes
     * @param callData The call data to log
     */
    fun logCallData(callData: CallData) {
        AppLogger.i(TAG, "=== CALL DATA ===")
        AppLogger.i(TAG, "Channel: ${callData.channelId}")
        AppLogger.i(TAG, "Speaker: ${callData.callName}")
        AppLogger.i(TAG, "UID: ${callData.uid}")
        AppLogger.i(TAG, "Has Photo: ${callData.callerPhoto != null}")
        AppLogger.i(TAG, "Timestamp: ${callData.timestamp}")
        AppLogger.i(TAG, "================")
    }
    
    /**
     * Log general notification data for debugging purposes
     * @param notificationData The notification data to log
     */
    fun logGeneralNotificationData(notificationData: GeneralNotificationData) {
        AppLogger.i(TAG, "=== GENERAL NOTIFICATION ===")
        AppLogger.i(TAG, "Title: ${notificationData.title}")
        AppLogger.i(TAG, "Message: ${notificationData.message}")
        AppLogger.i(TAG, "Has Image: ${notificationData.imageUrl != null}")
        AppLogger.i(TAG, "Click Action: ${notificationData.clickAction}")
        AppLogger.i(TAG, "Extra Data: ${notificationData.extraData?.size ?: 0} items")
        AppLogger.i(TAG, "===========================")
    }
}
