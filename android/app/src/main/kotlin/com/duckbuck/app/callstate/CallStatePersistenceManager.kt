package com.duckbuck.app.callstate

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.duckbuck.app.fcm.FcmDataHandler.CallData

/**
 * Call State Persistence Manager - Handles all call state operations
 * Separated from FCM for better modularity and reusability
 * Manages saving, restoring, and clearing call data across app lifecycle
 */
class CallStatePersistenceManager(context: Context) {
    
    companion object {
        private const val TAG = "CallStatePersistenceManager"
        private const val CALL_PREFS_NAME = "active_call_data"
        
        // SharedPreferences keys
        private const val PREF_IS_IN_CALL = "is_in_active_call"
        private const val PREF_AGORA_TOKEN = "agora_token"
        private const val PREF_AGORA_UID = "agora_uid"
        private const val PREF_CHANNEL_ID = "agora_channel_id"
        private const val PREF_CALL_NAME = "caller_name"
        private const val PREF_CALLER_PHOTO = "caller_photo"
        private const val PREF_JOIN_TIMESTAMP = "join_timestamp"
        private const val PREF_CALL_STATE = "call_state"
    }
    
    /**
     * Enum representing different call states
     */
    enum class CallState {
        INCOMING,      // Call received but not joined yet
        JOINING,       // In process of joining call
        ACTIVE,        // Successfully joined and in call
        ENDING,        // Call is ending
        ENDED          // Call has ended
    }
    
    private val callPrefs: SharedPreferences = 
        context.getSharedPreferences(CALL_PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * Save incoming call data (when FCM message is received)
     */
    fun saveIncomingCallData(callData: CallData) {
        try {
            callPrefs.edit().apply {
                putBoolean(PREF_IS_IN_CALL, false) // Not in call yet, just received
                putString(PREF_AGORA_TOKEN, callData.token)
                putInt(PREF_AGORA_UID, callData.uid)
                putString(PREF_CHANNEL_ID, callData.channelId)
                putString(PREF_CALL_NAME, callData.callName)
                putString(PREF_CALLER_PHOTO, callData.callerPhoto ?: "")
                putLong(PREF_JOIN_TIMESTAMP, System.currentTimeMillis())
                putString(PREF_CALL_STATE, CallState.INCOMING.name)
                apply()
            }
            
            Log.i(TAG, "✅ Incoming call data saved: ${callData.channelId} from ${callData.callName}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error saving incoming call data", e)
        }
    }
    
    /**
     * Mark call as actively joined
     */
    fun markCallAsJoined(channelId: String) {
        try {
            callPrefs.edit().apply {
                putBoolean(PREF_IS_IN_CALL, true)
                putString(PREF_CALL_STATE, CallState.ACTIVE.name)
                putLong(PREF_JOIN_TIMESTAMP, System.currentTimeMillis()) // Update to actual join time
                apply()
            }
            
            Log.i(TAG, "✅ Call marked as joined: $channelId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error marking call as joined", e)
        }
    }
    
    /**
     * Mark call as joining (in progress)
     */
    fun markCallAsJoining(channelId: String) {
        try {
            callPrefs.edit().apply {
                putString(PREF_CALL_STATE, CallState.JOINING.name)
                apply()
            }
            
            Log.i(TAG, "📞 Call marked as joining: $channelId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error marking call as joining", e)
        }
    }
    
    /**
     * Mark call as ending
     */
    fun markCallAsEnding(channelId: String) {
        try {
            callPrefs.edit().apply {
                putString(PREF_CALL_STATE, CallState.ENDING.name)
                apply()
            }
            
            Log.i(TAG, "📴 Call marked as ending: $channelId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error marking call as ending", e)
        }
    }
    
    /**
     * Clear all call data (when call ends or leaves)
     */
    fun clearCallData() {
        try {
            callPrefs.edit().clear().apply()
            Log.i(TAG, "✅ All call data cleared")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error clearing call data", e)
        }
    }
    
    /**
     * Get current call data (for app restart scenarios)
     */
    fun getCurrentCallData(): CallData? {
        return try {
            val channelId = callPrefs.getString(PREF_CHANNEL_ID, null)
            val token = callPrefs.getString(PREF_AGORA_TOKEN, null)
            val uid = callPrefs.getInt(PREF_AGORA_UID, 0)
            val callName = callPrefs.getString(PREF_CALL_NAME, null)
            
            if (channelId != null && token != null && uid != 0 && callName != null) {
                CallData(
                    token = token,
                    uid = uid,
                    channelId = channelId,
                    callName = callName,
                    callerPhoto = callPrefs.getString(PREF_CALLER_PHOTO, null)
                )
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error retrieving call data", e)
            null
        }
    }
    
    /**
     * Check if currently in an active call
     */
    fun isInActiveCall(): Boolean {
        return try {
            callPrefs.getBoolean(PREF_IS_IN_CALL, false)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking active call state", e)
            false
        }
    }
    
    /**
     * Get current call state
     */
    fun getCurrentCallState(): CallState {
        return try {
            val stateString = callPrefs.getString(PREF_CALL_STATE, CallState.ENDED.name)
            CallState.valueOf(stateString ?: CallState.ENDED.name)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting call state", e)
            CallState.ENDED
        }
    }
    
    /**
     * Check if there's a pending call (received but not joined)
     */
    fun hasPendingCall(): Boolean {
        return try {
            val callState = getCurrentCallState()
            callState == CallState.INCOMING || callState == CallState.JOINING
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking pending call", e)
            false
        }
    }
    
    /**
     * Get call duration in milliseconds (for active calls)
     */
    fun getCallDuration(): Long {
        return try {
            val joinTimestamp = callPrefs.getLong(PREF_JOIN_TIMESTAMP, 0)
            if (joinTimestamp == 0L || !isInActiveCall()) {
                return 0L
            }
            System.currentTimeMillis() - joinTimestamp
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error getting call duration", e)
            0L
        }
    }
    
    /**
     * Get call info for debugging
     */
    fun getCallDebugInfo(): String {
        return try {
            val callData = getCurrentCallData()
            val state = getCurrentCallState()
            val duration = getCallDuration()
            
            """
            Call Debug Info:
            - State: $state
            - Channel: ${callData?.channelId ?: "None"}
            - Caller: ${callData?.callName ?: "None"}
            - Duration: ${duration}ms
            - Is Active: ${isInActiveCall()}
            - Has Pending: ${hasPendingCall()}
            """.trimIndent()
        } catch (e: Exception) {
            "Error getting debug info: ${e.message}"
        }
    }
}
