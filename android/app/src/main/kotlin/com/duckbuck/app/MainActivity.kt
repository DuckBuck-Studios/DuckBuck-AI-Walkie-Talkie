package com.duckbuck.app

import android.os.Bundle
import android.util.Log
import com.duckbuck.app.core.AgoraEngineInitializer
import com.duckbuck.app.core.AgoraServiceManager
import com.duckbuck.app.core.AgoraMethodChannelHandler
import com.duckbuck.app.core.CallUITrigger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    
    // Channel names for Flutter-Native communication
    private val AGORA_CHANNEL = "com.duckbuck.app/agora_channel"
    private val CALL_UI_CHANNEL = "com.duckbuck.app/call"
    
    // Method channel handler for Agora operations
    private val agoraMethodChannelHandler = AgoraMethodChannelHandler()
    
    // Call UI method channel for triggering Flutter call UI
    private var callUIMethodChannel: MethodChannel? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize or verify Agora service during activity startup
        initializeAgoraService()
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for Flutter to communicate with native Agora service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AGORA_CHANNEL).setMethodCallHandler { call, result ->
            agoraMethodChannelHandler.handleMethodCall(call, result)
        }
        
        // Set up call UI method channel for triggering Flutter call UI
        callUIMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_UI_CHANNEL)
        
        // Set the static reference for other components to trigger call UI
        CallUITrigger.setMethodChannel(callUIMethodChannel)
    }
    
    private fun initializeAgoraService(): Boolean {
        try {
            Log.i(TAG, "Initializing/verifying Agora service in MainActivity")
            
            // First check if a valid instance exists in the service manager
            val existingService = AgoraServiceManager.getValidatedAgoraService()
            if (existingService != null) {
                Log.i(TAG, "✅ Using existing validated Agora Engine from service manager")
                return true
            }
            
            // Use modular initializer to create or restore service
            val (success, agoraService) = AgoraEngineInitializer.initializeAgoraService(this)
            
            if (success && agoraService != null) {
                Log.i(TAG, "✅ Agora Engine initialized successfully in MainActivity")
                
                // Store reference in service manager
                AgoraServiceManager.setAgoraService(agoraService)
                return true
            } else {
                Log.e(TAG, "❌ Failed to initialize Agora Engine in MainActivity")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception initializing Agora Engine in MainActivity", e)
            return false
        }
    }
}