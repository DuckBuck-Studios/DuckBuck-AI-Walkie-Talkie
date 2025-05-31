package com.duckbuck.app.fcm

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.duckbuck.app.services.WalkieTalkieService

/**
 * FCM Service Orchestrator - Pure coordination and delegation
 * 
 * This service acts as a minimal coordinator that:
 * 1. Receives FCM messages
 * 2. Determines app state and call handling strategy
 * 3. Delegates to high-level managers for execution
 * 
 * No business logic here - just pure orchestration and delegation
 */
class FcmServiceOrchestrator : FirebaseMessagingService() {
    
    companion object {
        private const val TAG = "FcmServiceOrchestrator"
    }
    
    // High-level managers for delegation
    private lateinit var appStateDetector: FcmAppStateDetector
    
    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🚀 FCM Service Orchestrator starting up...")
        
        // Initialize managers
        initializeManagers()
        
        // Start persistent walkie-talkie service
        startWalkieTalkieService()
    }
    
    /**
     * Initialize high-level managers for delegation
     */
    private fun initializeManagers() {
        try {
            appStateDetector = FcmAppStateDetector(this)
            Log.i(TAG, "✅ All high-level managers initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing managers", e)
        }
    }
    
    /**
     * Start the persistent walkie-talkie service
     */
    private fun startWalkieTalkieService() {
        try {
            WalkieTalkieService.startService(this)
            Log.i(TAG, "✅ Walkie-talkie service started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting walkie-talkie service", e)
        }
    }
    
    /**
     * Handle incoming FCM messages
     * Delegates to appropriate managers based on message type and app state
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super<FirebaseMessagingService>.onMessageReceived(remoteMessage)
        
        try {
            Log.i(TAG, "📨 FCM message received: ${remoteMessage.messageId}")
            
            // Extract call data from message
            val callData = FcmDataHandler.extractCallData(remoteMessage)
            
            if (callData == null) {
                Log.w(TAG, "⚠️ Invalid or non-call FCM message received")
                return
            }
            
            Log.i(TAG, "📻 Processing walkie-talkie channel message: ${callData.callName}")
            
            // For walkie-talkie: Always auto-connect to channel regardless of app state
            // Use the dedicated service for persistent connection
            handleWalkieTalkieMessage(callData)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing FCM message", e)
        }
    }
    
    /**
     * Handle FCM token refresh
     */
    override fun onNewToken(token: String) {
        super<FirebaseMessagingService>.onNewToken(token)
        Log.i(TAG, "🔄 FCM token refreshed: ${token.take(10)}...")
        
        // TODO: Send token to app server if needed
        // This can be handled by sending the token to Flutter side
    }
    
    /**
     * Handle walkie-talkie channel message - Always auto-connect using persistent service
     */
    private fun handleWalkieTalkieMessage(callData: FcmDataHandler.CallData) {
        try {
            Log.i(TAG, "📻 Auto-connecting to walkie-talkie channel via service: ${callData.callName}")
            
            // Use the persistent walkie-talkie service to join the channel
            // This ensures the connection persists even if app is backgrounded
            WalkieTalkieService.joinChannel(
                context = this,
                channelId = callData.channelId,
                channelName = callData.callName,
                token = callData.token,
                uid = callData.uid
            )
            
            Log.i(TAG, "✅ Walkie-talkie channel join initiated via service")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling walkie-talkie message", e)
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "🛑 FCM Service Orchestrator shutting down...")
        super<FirebaseMessagingService>.onDestroy()
    }
}
