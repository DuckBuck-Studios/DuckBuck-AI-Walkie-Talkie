package com.duckbuck.app.bridges

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

/**
 * CallUIBridge - Handles communication between native Android and Flutter for Call UI
 * Triggers call screen display when calls are successfully connected
 */
class CallUIBridge(private val context: Context) {
    
    companion object {
        private const val TAG = "CallUIBridge"
        const val CHANNEL_NAME = "com.duckbuck.app/call_ui"
        
        @Volatile
        private var INSTANCE: CallUIBridge? = null
        
        fun getInstance(context: Context): CallUIBridge {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: CallUIBridge(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    private var methodChannel: MethodChannel? = null
    
    /**
     * Initialize the method channel with Flutter engine
     */
    fun initialize(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        Log.i(TAG, "🔗 CallUI bridge initialized with channel: $CHANNEL_NAME")
    }
    
    /**
     * Show call UI with incoming call data (for receiver scenarios)
     */
    fun showIncomingCallUI(
        channelId: String,
        callerName: String,
        callerPhoto: String?,
        agoraToken: String?,
        agoraUid: String?
    ) {
        val callData = mapOf(
            "callType" to "incoming",
            "channelId" to channelId,
            "callerName" to callerName,
            "callerPhoto" to (callerPhoto ?: ""),
            "agoraToken" to (agoraToken ?: ""),
            "agoraUid" to (agoraUid ?: ""),
            "timestamp" to System.currentTimeMillis()
        )
        
        Log.i(TAG, "📞 Showing incoming call UI for: $callerName")
        Log.d(TAG, "📞 Call data: $callData")
        
        invokeFlutterMethod("showCallUI", callData)
    }
    
    /**
     * Show call UI for outgoing call (for initiator scenarios)
     */
    fun showOutgoingCallUI(
        channelId: String,
        friendName: String,
        friendPhoto: String?,
        agoraToken: String?,
        agoraUid: String?
    ) {
        val callData = mapOf(
            "callType" to "outgoing",
            "channelId" to channelId,
            "callerName" to friendName,
            "callerPhoto" to (friendPhoto ?: ""),
            "agoraToken" to (agoraToken ?: ""),
            "agoraUid" to (agoraUid ?: ""),
            "timestamp" to System.currentTimeMillis()
        )
        
        Log.i(TAG, "📞 Showing outgoing call UI for: $friendName")
        Log.d(TAG, "📞 Call data: $callData")
        
        invokeFlutterMethod("showCallUI", callData)
    }
    
    /**
     * Hide call UI when call ends
     */
    fun hideCallUI(reason: String) {
        val endData = mapOf(
            "reason" to reason,
            "timestamp" to System.currentTimeMillis()
        )
        
        Log.i(TAG, "🚪 Hiding call UI, reason: $reason")
        
        invokeFlutterMethod("hideCallUI", endData)
    }
    
    /**
     * Notify Flutter about call connection failure
     */
    fun notifyCallFailed(reason: String, errorMessage: String? = null) {
        val failureData = mapOf(
            "reason" to reason,
            "errorMessage" to (errorMessage ?: "Unknown error"),
            "timestamp" to System.currentTimeMillis()
        )
        
        Log.w(TAG, "❌ Notifying call failure: $reason")
        
        invokeFlutterMethod("onCallFailed", failureData)
    }
    
    /**
     * Update call state (connected, disconnecting, etc.)
     */
    fun updateCallState(state: String, additionalData: Map<String, Any> = emptyMap()) {
        val stateData = mutableMapOf<String, Any>(
            "state" to state,
            "timestamp" to System.currentTimeMillis()
        )
        stateData.putAll(additionalData)
        
        Log.d(TAG, "📊 Updating call state: $state")
        
        invokeFlutterMethod("updateCallState", stateData)
    }
    
    /**
     * Check if there's an active call when app resumes
     */
    fun checkActiveCall() {
        Log.d(TAG, "🔍 Checking for active call on app resume")
        invokeFlutterMethod("checkActiveCall", emptyMap<String, Any>())
    }
    
    /**
     * Safely invoke Flutter method on UI thread
     */
    private fun invokeFlutterMethod(method: String, arguments: Any) {
        val channel = methodChannel
        if (channel == null) {
            Log.w(TAG, "⚠️ Method channel not initialized, cannot invoke: $method")
            return
        }
        
        // Ensure we're on the main thread for Flutter communication
        Handler(Looper.getMainLooper()).post {
            try {
                channel.invokeMethod(method, arguments, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d(TAG, "✅ Flutter method '$method' completed successfully")
                    }
                    
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e(TAG, "❌ Flutter method '$method' failed: $errorCode - $errorMessage")
                    }
                    
                    override fun notImplemented() {
                        Log.w(TAG, "⚠️ Flutter method '$method' not implemented")
                    }
                })
            } catch (e: Exception) {
                Log.e(TAG, "💥 Error invoking Flutter method '$method'", e)
            }
        }
    }
    
    /**
     * Clean up resources
     */
    fun dispose() {
        methodChannel = null
        Log.d(TAG, "🧹 CallUI bridge disposed")
    }
}
