package com.duckbuck.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.duckbuck.app.infrastructure.monitoring.AppLogger
import com.duckbuck.app.domain.call.AppStateManager
import com.duckbuck.app.infrastructure.utilities.EngineStartupManager
import com.duckbuck.app.presentation.bridges.FlutterBridgeManager
import com.duckbuck.app.presentation.bridges.CallUITrigger
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity - Pure entry point for the DuckBuck application
 * 
 * This activity serves only as an entry point and delegates all business logic
 * to specialized managers for better separation of concerns and maintainability.
 * 
 * Responsibilities:
 * - App startup coordination
 * - Flutter engine configuration delegation
 * - App lifecycle event delegation
 * 
 * Business logic is handled by:
 * - EngineStartupManager: Agora engine initialization
 * - FlutterBridgeManager: Flutter-Native communication setup
 * - AppStateManager: App lifecycle and call state management
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    // Specialized managers for different concerns
    private lateinit var engineStartupManager: EngineStartupManager
    private lateinit var flutterBridgeManager: FlutterBridgeManager
    private lateinit var appStateManager: AppStateManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        AppLogger.production(TAG, "APP_STARTUP", mapOf("timestamp" to System.currentTimeMillis()))
        
        // Initialize specialized managers BEFORE calling super.onCreate()
        // This ensures flutterBridgeManager is ready when configureFlutterEngine() is called
        initializeManagers()
        
        super.onCreate(savedInstanceState)
        
        // Initialize Agora engine during startup
        engineStartupManager.initializeAgoraService()
        
        // Handle notification intent if app was opened from notification
        handleNotificationIntent()
    }
    
    override fun onResume() {
        super.onResume()
        
        // Delegate call state checking to AppStateManager
        // Add a slight delay for cold start scenarios (killed state)
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            appStateManager.checkForActiveCallsOnResume { callerName, callerPhoto, isMuted ->
                // Trigger call UI when active call is found
                CallUITrigger.showCallUI(callerName, callerPhoto, isMuted)
            }
        }, 100) // Further reduced from 250ms to 100ms for faster cold start
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Delegate Flutter bridge configuration to FlutterBridgeManager
        flutterBridgeManager.configureFlutterBridges(flutterEngine)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        
        // Clean up bridge references
        flutterBridgeManager.cleanup()
        
        AppLogger.production(TAG, "APP_SHUTDOWN", mapOf("timestamp" to System.currentTimeMillis()))
    }
    
    /**
     * Initialize all specialized managers with async optimization for faster startup
     */
    private fun initializeManagers() {
        try {
            // Initialize managers that don't depend on each other asynchronously
            engineStartupManager = EngineStartupManager(this)
            
            // Initialize FlutterBridgeManager synchronously since configureFlutterEngine needs it
            flutterBridgeManager = FlutterBridgeManager(this)
            
            // Initialize AppStateManager async - it can start in parallel
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                appStateManager = AppStateManager(this@MainActivity)
                AppLogger.i(TAG, "✅ AppStateManager initialized asynchronously")
            }
            
            AppLogger.i(TAG, "✅ Critical managers initialized successfully")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error initializing managers", e)
            throw e
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Handle notification intent when app is already running
        handleNotificationIntent()
    }
    
    /**
     * Handle notification intents when app is opened from notification tap
     */
    private fun handleNotificationIntent() {
        try {
            val intent = intent ?: return
            
            val notificationType = intent.getStringExtra("notification_type")
            val notificationData = intent.getStringExtra("notification_data")
            
            if (notificationType.isNullOrBlank()) {
                AppLogger.d(TAG, "No notification type found in intent")
                return
            }
            
            AppLogger.i(TAG, "📱 Processing notification intent: Type=$notificationType, Data=$notificationData")
            
            when (notificationType) {
                "general" -> {
                    AppLogger.i(TAG, "✅ App opened from general notification: $notificationData")
                    
                    // Extract any click action or extra data
                    val clickAction = intent.getStringExtra("click_action")
                    
                    if (!clickAction.isNullOrBlank()) {
                        AppLogger.i(TAG, "📱 Processing click action: $clickAction") 
                    }
                    
                    // Extract any extra data passed from the notification
                    val extras = mutableMapOf<String, String>()
                    intent.extras?.let { bundle ->
                        bundle.keySet().forEach { key ->
                            if (key.startsWith("extra_")) {
                                val value = bundle.getString(key)
                                if (value != null) {
                                    extras[key.removePrefix("extra_")] = value
                                }
                            }
                        }
                    }
                    
                    if (extras.isNotEmpty()) {
                        AppLogger.i(TAG, "📦 Extra data found: ${extras.size} items")
                        // Process extra data if needed
                    }
                    
                    // TODO: You can add Flutter method channel call here to notify the Flutter side
                    // about the notification tap and pass relevant data
                }
                
                "walkie_talkie_speaking" -> {
                    AppLogger.i(TAG, "✅ App opened from walkie-talkie notification: $notificationData")
                    // The app should already be connected to the channel via FCM
                    // Just ensure the call UI is visible
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        appStateManager.checkForActiveCallsOnResume { callerName, callerPhoto, isMuted ->
                            CallUITrigger.showCallUI(callerName, callerPhoto, isMuted)
                        }
                    }, 200)
                }
                
                "system_alert" -> {
                    AppLogger.i(TAG, "✅ App opened from system alert: $notificationData")
                    // Handle system alert notification taps
                }
                
                else -> {
                    AppLogger.w(TAG, "⚠️ Unknown notification type: $notificationType")
                }
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error handling notification intent", e)
        }
    }
}