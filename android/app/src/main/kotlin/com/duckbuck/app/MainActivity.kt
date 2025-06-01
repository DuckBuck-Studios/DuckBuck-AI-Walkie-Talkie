package com.duckbuck.app

import android.os.Bundle
import android.util.Log
import android.app.ActivityManager
import android.content.Context
import com.duckbuck.app.core.AgoraEngineInitializer
import com.duckbuck.app.core.AgoraServiceManager
import com.duckbuck.app.core.AgoraMethodChannelHandler
import com.duckbuck.app.core.CallUITrigger
import com.duckbuck.app.calls.CallLifecycleManager
import com.duckbuck.app.callstate.CallStatePersistenceManager
import com.duckbuck.app.services.WalkieTalkieService
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
    
    // Call lifecycle manager for handling app resume scenarios
    private lateinit var callLifecycleManager: CallLifecycleManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize or verify Agora service during activity startup
        initializeAgoraService()
        
        // Initialize call lifecycle manager
        callLifecycleManager = CallLifecycleManager(this)
    }
    
    override fun onResume() {
        super.onResume()
        
        // Add a slight delay for cold start scenarios (killed state)
        // This ensures Agora service has time to initialize
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            checkForActiveCallsOnResume()
        }, 500) // 500ms delay for cold start scenarios
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
            return false        }
    }
    
    /**
     * Check if WalkieTalkieService is currently running
     */
    private fun isWalkieTalkieServiceRunning(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in activityManager.getRunningServices(Integer.MAX_VALUE)) {
            if (WalkieTalkieService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }

    /**
     * Check for active calls when app is resumed and show call UI if needed
     * Simple approach: if call data exists in SharedPreferences, show call UI
     */
    private fun checkForActiveCallsOnResume() {
        try {
            Log.i(TAG, "🔄 Checking for active calls on app resume")
            
            val callStatePersistence = CallStatePersistenceManager(this)
            val callData = callStatePersistence.getCurrentCallData()
            
            // Simple check: if call data exists in SharedPreferences, show call UI
            if (callData != null) {
                Log.i(TAG, "📞 Found call data on resume: ${callData.callName}")
                
                // Check if WalkieTalkieService is running
                val isServiceRunning = isWalkieTalkieServiceRunning()
                Log.d(TAG, "🔧 WalkieTalkieService running: $isServiceRunning")
                
                if (isServiceRunning) {
                    // Service is running, so call is likely active - show UI immediately
                    val agoraService = AgoraServiceManager.getAgoraService()
                    val isMuted = agoraService?.isMicrophoneMuted() ?: true
                    
                    // Small delay to ensure Flutter engine is ready
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        CallUITrigger.showCallUI(
                            callerName = callData.callName,
                            callerPhotoUrl = callData.callerPhoto,
                            isMuted = isMuted
                        )
                        Log.i(TAG, "✅ Call UI triggered for active call: ${callData.callName} (muted: $isMuted)")
                    }, 200) // Delay for Flutter engine readiness
                } else {
                    // Service not running but call data exists - clear stale data
                    Log.w(TAG, "🧹 Service not running but call data exists - clearing stale data")
                    callStatePersistence.clearCallData()
                }
            } else {
                Log.d(TAG, "📵 No call data found on resume")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking for active calls on resume", e)
        }
    }
}