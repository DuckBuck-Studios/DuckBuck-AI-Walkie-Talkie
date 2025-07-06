package com.duckbuck.app

import android.os.Bundle
import android.util.Log
import com.duckbuck.app.bridges.AgoraBridge
import com.duckbuck.app.bridges.AiAgentBridge
import com.duckbuck.app.bridges.CallUIBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    private lateinit var agoraBridge: AgoraBridge
    private lateinit var aiAgentBridge: AiAgentBridge
    private lateinit var callUIBridge: CallUIBridge
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Agora bridge
        agoraBridge = AgoraBridge(this)
        
        // Initialize AI Agent bridge
        aiAgentBridge = AiAgentBridge(this)
        
        // Initialize CallUI bridge
        callUIBridge = CallUIBridge.getInstance(this)
        callUIBridge.initialize(flutterEngine)
        
        // Register method channel for Agora communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AgoraBridge.CHANNEL_NAME)
            .setMethodCallHandler(agoraBridge)
            
        // Register method channel for AI Agent communication
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AiAgentBridge.CHANNEL_NAME)
            .setMethodCallHandler(aiAgentBridge)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle intent data if app was opened from notification
        handleNotificationIntent()
    }
    
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent()
    }
    
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "📱 App going to background")
        
        // Notify AiAgentBridge that app is going to background
        aiAgentBridge.onAppBackgrounded()
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "📱 App coming to foreground")
        
        // Notify AiAgentBridge that app is coming to foreground
        aiAgentBridge.onAppForegrounded()
    }
    
    /**
     * Handle app opening from notification (ongoing call or normal notification)
     */
    private fun handleNotificationIntent() {
        intent?.let { intent ->
            val openedFromNotification = intent.getBooleanExtra("opened_from_notification", false)
            val openedFromCallNotification = intent.getBooleanExtra("opened_from_call_notification", false)
            val showOngoingCall = intent.getBooleanExtra("show_ongoing_call", false)
            
            if (openedFromNotification || openedFromCallNotification || showOngoingCall) {
                // TODO: Send intent data to Flutter to handle navigation
                // This will be implemented when Flutter side is ready
                Log.d(TAG, "📱 App opened from notification")
            }
        }
    }
}