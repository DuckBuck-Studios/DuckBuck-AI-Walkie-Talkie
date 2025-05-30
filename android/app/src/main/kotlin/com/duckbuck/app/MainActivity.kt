package com.duckbuck.app
import android.content.Context
import android.os.Bundle
import android.util.Log
import com.duckbuck.app.agora.AgoraService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private lateinit var agoraService: AgoraService
    
    // Channel name for Flutter-Native communication
    private val AGORA_CHANNEL = "com.duckbuck.app/agora_channel"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize Agora service early during app startup
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
            // First check if a valid instance exists in the holder (from Application)
            val existingService = AgoraServiceHolder.getAgoraService()
            if (existingService != null && existingService.isEngineInitialized()) {
                Log.i(TAG, "✅ Using existing initialized Agora Engine from Application")
                agoraService = existingService
                return true
            }
            
            // Create new service if needed
            agoraService = AgoraService(this)
            val success = agoraService.initializeEngine()
            
            if (success) {
                Log.i(TAG, "✅ Agora Engine initialized successfully during app startup")
                
                // Verify initialization
                if (agoraService.isEngineInitialized()) {
                    Log.i(TAG, "✅ Agora Engine verification successful")
                } else {
                    Log.w(TAG, "⚠️ Agora Engine initialization succeeded but verification failed. Trying again...")
                    
                    // Try one more time with more aggressive approach
                    agoraService.destroy()
                    agoraService = AgoraService(this)
                    
                    // Try init again
                    val retrySuccess = agoraService.initializeEngine()
                    
                    if (!retrySuccess || !agoraService.isEngineInitialized()) {
                        Log.e(TAG, "❌ Agora Engine failed to initialize even after retry")
                        return false
                    }
                    
                    Log.i(TAG, "✅ Agora Engine initialized successfully on second attempt")
                }
                
                // Store reference in singleton for service access
                AgoraServiceHolder.setAgoraService(agoraService)
                return true
            } else {
                Log.e(TAG, "❌ Failed to initialize Agora Engine during app startup")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Exception initializing Agora Engine", e)
            return false
        }
    }
}