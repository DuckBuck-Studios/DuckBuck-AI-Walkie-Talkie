package com.example.duckbuck.service

import android.content.Context
import android.util.Log

/**
 * Manages the state of ongoing calls, providing persistence between app restarts.
 */
class CallStateManager(private val context: Context) {
    companion object {
        private const val TAG = "CallStateManager"
        
        // Call state persistence
        private const val PREFS_NAME = "CallServicePrefs"
        private const val KEY_CALL_ACTIVE = "call_active"
        private const val KEY_CALLER_NAME = "caller_name"
        private const val KEY_CALLER_AVATAR = "caller_avatar"
        private const val KEY_CALL_DURATION = "call_duration"
        private const val KEY_CALL_MUTED = "call_muted"
        private const val KEY_SENDER_UID = "sender_uid"
    }
    
    /**
     * Store call state in SharedPreferences
     */
    fun saveCallState(
        isActive: Boolean, 
        callerName: String?, 
        callerAvatar: String?,
        callDuration: Int,
        senderUid: String?,
        isAudioMuted: Boolean = false
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean(KEY_CALL_ACTIVE, isActive)
            putString(KEY_CALLER_NAME, callerName ?: "Unknown")
            putString(KEY_CALLER_AVATAR, callerAvatar)
            putString(KEY_SENDER_UID, senderUid)
            putInt(KEY_CALL_DURATION, callDuration)
            putBoolean(KEY_CALL_MUTED, isAudioMuted)
            apply()
        }
        
        Log.d(TAG, "Saved call state: active=$isActive, caller=$callerName, avatar=${callerAvatar != null}, duration=$callDuration")
    }
    
    /**
     * Clear call state when call ends
     */
    fun clearCallState() {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean(KEY_CALL_ACTIVE, false)
            apply()
        }
        Log.d(TAG, "Cleared call active state")
    }
    
    /**
     * Get saved caller info, returns null if no active call
     */
    fun getActiveCallInfo(): CallNotificationManager.Companion.CallerInfo? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        if (!prefs.getBoolean(KEY_CALL_ACTIVE, false)) {
            return null
        }
        
        return CallNotificationManager.Companion.CallerInfo(
            name = prefs.getString(KEY_CALLER_NAME, "Unknown") ?: "Unknown",
            avatarUrl = prefs.getString(KEY_CALLER_AVATAR, null),
            uid = prefs.getString(KEY_SENDER_UID, null),
            duration = prefs.getInt(KEY_CALL_DURATION, 0),
            isAudioMuted = prefs.getBoolean(KEY_CALL_MUTED, false)
        )
    }
    
    /**
     * Check if there's an active call saved
     */
    fun hasActiveCall(): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getBoolean(KEY_CALL_ACTIVE, false)
    }
}