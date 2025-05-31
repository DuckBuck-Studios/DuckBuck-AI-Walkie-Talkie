package com.duckbuck.app

import android.os.Bundle
import android.util.Log
import com.duckbuck.app.core.AgoraEngineInitializer
import com.duckbuck.app.core.AgoraServiceManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    
    // Channel name for Flutter-Native communication
    private val AGORA_CHANNEL = "com.duckbuck.app/agora_channel"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize or verify Agora service during activity startup
        initializeAgoraService()
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel for Flutter to communicate with native Agora service
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AGORA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeAgoraEngine" -> {
                    val success = initializeAgoraService()
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
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