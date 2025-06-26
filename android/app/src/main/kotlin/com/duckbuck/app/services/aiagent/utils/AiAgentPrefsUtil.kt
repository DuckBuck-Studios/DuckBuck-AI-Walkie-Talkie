package com.duckbuck.app.services.aiagent.utils

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * AiAgentPrefsUtil - Utility for managing AI agent session data in SharedPreferences
 * Handles saving, retrieving, and clearing AI agent session state
 */
class AiAgentPrefsUtil(private val context: Context) {
    
    companion object {
        private const val TAG = "AiAgentPrefsUtil"
        private const val PREFS_NAME = "ai_agent_session"
        
        // Keys for AI agent session data
        private const val KEY_IS_ACTIVE = "is_ai_session_active"
        private const val KEY_USER_ID = "ai_user_id"
        private const val KEY_CHANNEL_NAME = "ai_channel_name"
        private const val KEY_SESSION_START_TIME = "ai_session_start_time"
        private const val KEY_LAST_UPDATED = "ai_last_updated"
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * Save AI agent session data
     */
    fun saveAiAgentSession(userId: String, channelName: String, startTime: Long) {
        try {
            Log.d(TAG, "🤖 Saving AI agent session data for user: $userId, channel: $channelName")
            
            prefs.edit().apply {
                putBoolean(KEY_IS_ACTIVE, true)
                putString(KEY_USER_ID, userId)
                putString(KEY_CHANNEL_NAME, channelName)
                putLong(KEY_SESSION_START_TIME, startTime)
                putLong(KEY_LAST_UPDATED, System.currentTimeMillis())
                apply()
            }
            
            Log.i(TAG, "✅ AI agent session data saved successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error saving AI agent session data", e)
        }
    }
    
    /**
     * Get current AI agent session data
     */
    fun getAiAgentSession(): AiAgentSessionData? {
        return try {
            val isActive = prefs.getBoolean(KEY_IS_ACTIVE, false)
            
            if (!isActive) {
                Log.d(TAG, "🤖 No active AI agent session found")
                return null
            }
            
            val userId = prefs.getString(KEY_USER_ID, null)
            val channelName = prefs.getString(KEY_CHANNEL_NAME, null)
            val startTime = prefs.getLong(KEY_SESSION_START_TIME, 0)
            val lastUpdated = prefs.getLong(KEY_LAST_UPDATED, 0)
            
            if (userId.isNullOrEmpty() || channelName.isNullOrEmpty() || startTime == 0L) {
                Log.w(TAG, "⚠️ Invalid AI agent session data found, clearing")
                clearAiAgentSession()
                return null
            }
            
            val sessionData = AiAgentSessionData(
                userId = userId,
                channelName = channelName,
                startTime = startTime,
                lastUpdated = lastUpdated
            )
            
            Log.d(TAG, "🤖 Retrieved AI agent session data: $sessionData")
            return sessionData
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error retrieving AI agent session data", e)
            null
        }
    }
    
    /**
     * Check if there's an active AI agent session
     */
    fun hasActiveAiAgentSession(): Boolean {
        return try {
            val isActive = prefs.getBoolean(KEY_IS_ACTIVE, false)
            Log.d(TAG, "🤖 AI agent session active: $isActive")
            isActive
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking AI agent session status", e)
            false
        }
    }
    
    /**
     * Update the last updated timestamp for the current session
     */
    fun updateLastUpdated() {
        try {
            if (prefs.getBoolean(KEY_IS_ACTIVE, false)) {
                prefs.edit().apply {
                    putLong(KEY_LAST_UPDATED, System.currentTimeMillis())
                    apply()
                }
                Log.d(TAG, "🤖 AI agent session last updated timestamp refreshed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error updating AI agent session timestamp", e)
        }
    }
    
    /**
     * Clear AI agent session data
     */
    fun clearAiAgentSession() {
        try {
            Log.d(TAG, "🤖 Clearing AI agent session data")
            
            prefs.edit().apply {
                clear()
                apply()
            }
            
            Log.i(TAG, "✅ AI agent session data cleared successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error clearing AI agent session data", e)
        }
    }
    
    /**
     * Get session duration in seconds
     */
    fun getSessionDuration(): Long {
        return try {
            val startTime = prefs.getLong(KEY_SESSION_START_TIME, 0)
            if (startTime > 0) {
                (System.currentTimeMillis() - startTime) / 1000
            } else {
                0
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error calculating session duration", e)
            0
        }
    }
}

/**
 * Data class representing AI agent session information
 */
data class AiAgentSessionData(
    val userId: String,
    val channelName: String,
    val startTime: Long,
    val lastUpdated: Long
) {
    /**
     * Get session duration in seconds
     */
    fun getDurationSeconds(): Long {
        return (System.currentTimeMillis() - startTime) / 1000
    }
    
    /**
     * Get formatted session duration
     */
    fun getFormattedDuration(): String {
        val duration = getDurationSeconds()
        val hours = duration / 3600
        val minutes = (duration % 3600) / 60
        val seconds = duration % 60
        
        return when {
            hours > 0 -> "${hours}h ${minutes}m ${seconds}s"
            minutes > 0 -> "${minutes}m ${seconds}s"
            else -> "${seconds}s"
        }
    }
}
