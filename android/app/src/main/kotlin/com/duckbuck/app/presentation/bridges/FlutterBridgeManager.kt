package com.duckbuck.app.presentation.bridges

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.duckbuck.app.infrastructure.monitoring.AppLogger
import com.duckbuck.app.presentation.bridges.AgoraMethodChannelHandler
import com.duckbuck.app.presentation.bridges.CallUITrigger

/**
 * Flutter Bridge Manager - Handles all Flutter-Native communication setup
 * Extracted from MainActivity for better separation of concerns and testability
 */
class FlutterBridgeManager(private val context: Context) {
    
    companion object {
        private const val TAG = "FlutterBridgeManager"
        
        // Channel names for Flutter-Native communication
        private const val AGORA_CHANNEL = "com.duckbuck.app/agora_channel"
        private const val CALL_UI_CHANNEL = "com.duckbuck.app/call"
    }
    
    private val agoraMethodChannelHandler = AgoraMethodChannelHandler()
    private var callUIMethodChannel: MethodChannel? = null
    
    /**
     * Configure all Flutter method channels and bridges
     */
    fun configureFlutterBridges(flutterEngine: FlutterEngine) {
        AppLogger.i(TAG, "Configuring Flutter-Native bridges")
        
        try {
            // Set up method channel for Flutter to communicate with native Agora service
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AGORA_CHANNEL)
                .setMethodCallHandler { call, result ->
                    agoraMethodChannelHandler.handleMethodCall(call, result)
                }
            
            // Set up call UI method channel for triggering Flutter call UI
            callUIMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_UI_CHANNEL)
            
            // Set the static reference for other components to trigger call UI
            CallUITrigger.setMethodChannel(callUIMethodChannel)
            
            AppLogger.i(TAG, "✅ Flutter bridges configured successfully")
            AppLogger.production(TAG, "FLUTTER_BRIDGES_CONFIGURED", mapOf(
                "agoraChannel" to AGORA_CHANNEL,
                "callUIChannel" to CALL_UI_CHANNEL
            ))
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error configuring Flutter bridges", e)
            throw e
        }
    }
    
    /**
     * Clean up method channel references
     */
    fun cleanup() {
        callUIMethodChannel = null
        CallUITrigger.setMethodChannel(null)
        AppLogger.i(TAG, "Flutter bridge references cleaned up")
    }
    
    /**
     * Get the call UI method channel for direct access if needed
     */
    fun getCallUIChannel(): MethodChannel? = callUIMethodChannel
}
