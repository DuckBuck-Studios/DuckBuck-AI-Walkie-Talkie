package com.duckbuck.app.services.walkietalkie.utils

import android.util.Log

/**
 * TimestampValidator - Validates FCM notification timestamps
 * Ensures notifications are processed only if they're within acceptable time window
 */
class TimestampValidator {
    
    companion object {
        private const val TAG = "TimestampValidator"
        private const val MAX_TIMESTAMP_DIFF_SECONDS = 25L
        private const val MILLIS_PER_SECOND = 1000L
    }
    
    /**
     * Validates if the notification timestamp is within acceptable range
     * @param timestampString The timestamp from FCM notification (in milliseconds)
     * @return true if valid (within 25 seconds), false if expired/invalid
     */
    fun isTimestampValid(timestampString: String?): Boolean {
        try {
            if (timestampString.isNullOrEmpty()) {
                Log.w(TAG, "⚠️ Timestamp is null or empty")
                return false
            }
            
            val notificationTimestamp = timestampString.toLongOrNull()
            if (notificationTimestamp == null) {
                Log.w(TAG, "⚠️ Invalid timestamp format: $timestampString")
                return false
            }
            
            val currentTimestamp = System.currentTimeMillis()
            val timestampDiffMillis = kotlin.math.abs(currentTimestamp - notificationTimestamp)
            val timestampDiffSeconds = timestampDiffMillis / MILLIS_PER_SECOND
            
            Log.d(TAG, "🕐 Notification timestamp: $notificationTimestamp")
            Log.d(TAG, "🕐 Current timestamp: $currentTimestamp")
            Log.d(TAG, "🕐 Difference: ${timestampDiffSeconds}s")
            
            val isValid = timestampDiffSeconds <= MAX_TIMESTAMP_DIFF_SECONDS
            
            if (isValid) {
                Log.i(TAG, "✅ Timestamp valid (${timestampDiffSeconds}s difference)")
            } else {
                Log.w(TAG, "❌ Timestamp expired (${timestampDiffSeconds}s difference, max allowed: ${MAX_TIMESTAMP_DIFF_SECONDS}s)")
            }
            
            return isValid
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 Error validating timestamp", e)
            return false
        }
    }
    
    /**
     * Get human-readable timestamp difference
     * @param timestampString The timestamp from FCM notification
     * @return String description of the time difference
     */
    fun getTimestampDifference(timestampString: String?): String {
        try {
            if (timestampString.isNullOrEmpty()) {
                return "Invalid timestamp"
            }
            
            val notificationTimestamp = timestampString.toLongOrNull()
            if (notificationTimestamp == null) {
                return "Invalid timestamp format"
            }
            
            val currentTimestamp = System.currentTimeMillis()
            val timestampDiffMillis = currentTimestamp - notificationTimestamp
            val timestampDiffSeconds = timestampDiffMillis / MILLIS_PER_SECOND
            
            return when {
                timestampDiffSeconds < 0 -> "${kotlin.math.abs(timestampDiffSeconds)}s in the future"
                timestampDiffSeconds == 0L -> "Just now"
                timestampDiffSeconds < 60 -> "${timestampDiffSeconds}s ago"
                else -> "${timestampDiffSeconds / 60}m ${timestampDiffSeconds % 60}s ago"
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error calculating timestamp difference", e)
            return "Error calculating difference"
        }
    }
}
