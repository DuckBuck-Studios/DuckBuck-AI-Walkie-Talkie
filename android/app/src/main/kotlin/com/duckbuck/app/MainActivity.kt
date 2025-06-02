package com.duckbuck.app

import android.os.Bundle
import com.duckbuck.app.core.AppLogger
import com.duckbuck.app.core.AppStateManager
import com.duckbuck.app.core.EngineStartupManager
import com.duckbuck.app.core.FlutterBridgeManager
import com.duckbuck.app.core.CallUITrigger
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
        }, 500) // 500ms delay for cold start scenarios
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
     * Initialize all specialized managers
     */
    private fun initializeManagers() {
        try {
            engineStartupManager = EngineStartupManager(this)
            flutterBridgeManager = FlutterBridgeManager()
            appStateManager = AppStateManager(this)
            
            AppLogger.i(TAG, "✅ All managers initialized successfully")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error initializing managers", e)
            throw e
        }
    }
}