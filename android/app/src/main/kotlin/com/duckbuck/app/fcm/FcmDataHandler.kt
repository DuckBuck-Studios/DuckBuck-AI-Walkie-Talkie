package com.duckbuck.app.fcm
import com.duckbuck.app.core.AppLogger

import com.google.firebase.messaging.RemoteMessage

/**
 * FCM Data Handler responsible for processing FCM data payloads
 * Extracts and validates call-related data from FCM messages
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
            
            // 🕐 TIMESTAMP VALIDATION: Check if message is fresh (within 15 seconds)
            if (!isMessageFresh(timestamp)) {
                AppLogger.w(TAG, "🕐 FCM message too old, rejecting stale walkie-talkie invitation")
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
     * Check if FCM message is fresh (within 15 seconds)
     * @param messageTimestamp Unix timestamp in seconds from FCM message
     * @return true if message is fresh, false if stale
     */
    private fun isMessageFresh(messageTimestamp: Long): Boolean {
        try {
            val currentTime = System.currentTimeMillis() / 1000 // Convert to seconds
            val messageAge = currentTime - messageTimestamp
            
            AppLogger.d(TAG, "🕐 Message timestamp: $messageTimestamp, Current: $currentTime, Age: ${messageAge}s")
            
            return if (messageAge <= 15) {
                AppLogger.i(TAG, "✅ Message is fresh (${messageAge}s old) - proceeding")
                true
            } else {
                AppLogger.w(TAG, "❌ Message is stale (${messageAge}s old) - rejecting to prevent empty channel join")
                false
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error validating message timestamp", e)
            return false // Treat as stale if can't validate
        }
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
}
