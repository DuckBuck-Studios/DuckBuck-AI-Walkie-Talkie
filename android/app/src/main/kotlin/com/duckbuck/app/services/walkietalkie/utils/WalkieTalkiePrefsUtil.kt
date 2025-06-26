package com.duckbuck.app.services.walkietalkie.utils

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * WalkieTalkiePrefsUtil - Utility for storing ongoing call data in SharedPreferences
 * Used to show ongoing call screen when app opens from killed state
 */
object WalkieTalkiePrefsUtil {
    
    private const val TAG = "WalkieTalkiePrefsUtil"
    private const val PREFS_NAME = "walkie_talkie_prefs"
    
    // Call details from FCM data-only notification
    private const val KEY_CHANNEL_ID = "channel_id"
    private const val KEY_CALLER_NAME = "caller_name"
    private const val KEY_CALLER_PHOTO = "caller_photo"
    private const val KEY_AGORA_TOKEN = "agora_token"
    private const val KEY_AGORA_UID = "agora_uid"
    private const val KEY_IS_CALL_ACTIVE = "is_call_active"
    
    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }
    
    /**
     * Save active call data when call starts successfully
     */
    fun saveActiveCall(context: Context, channelId: String, callerName: String, callerPhoto: String?, agoraToken: String?, agoraUid: String?) {
        getPrefs(context).edit().apply {
            putBoolean(KEY_IS_CALL_ACTIVE, true)
            putString(KEY_CHANNEL_ID, channelId)
            putString(KEY_CALLER_NAME, callerName)
            putString(KEY_CALLER_PHOTO, callerPhoto)
            putString(KEY_AGORA_TOKEN, agoraToken)
            putString(KEY_AGORA_UID, agoraUid)
            apply()
        }
        Log.d(TAG, "📱 Saved active call data for channel: $channelId")
    }
    
    /**
     * Clear call data when call fails (timestamp rejected, channel empty, etc.)
     */
    fun clearCallFailed(context: Context, reason: String) {
        getPrefs(context).edit().clear().apply()
        Log.d(TAG, "🧹 Cleared call data - call failed: $reason")
    }
    
    /**
     * Clear call data when call ends (local user or others end call)
     */
    fun clearCallEnded(context: Context, reason: String) {
        getPrefs(context).edit().clear().apply()
        Log.d(TAG, "🧹 Cleared call data - call ended: $reason")
    }
    
    /**
     * Get active call data for Flutter (to show ongoing call screen)
     */
    fun getActiveCallData(context: Context): Map<String, Any> {
        val prefs = getPrefs(context)
        return mapOf(
            "is_call_active" to prefs.getBoolean(KEY_IS_CALL_ACTIVE, false),
            "channel_id" to (prefs.getString(KEY_CHANNEL_ID, "") ?: ""),
            "caller_name" to (prefs.getString(KEY_CALLER_NAME, "") ?: ""),
            "caller_photo" to (prefs.getString(KEY_CALLER_PHOTO, "") ?: ""),
            "agora_token" to (prefs.getString(KEY_AGORA_TOKEN, "") ?: ""),
            "agora_uid" to (prefs.getString(KEY_AGORA_UID, "") ?: "")
        )
    }
}
