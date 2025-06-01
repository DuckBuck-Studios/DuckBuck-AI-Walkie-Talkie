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
        
        // Don't start walkie-talkie service automatically
        // It will be started only when FCM message is received
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
     * Handle walkie-talkie channel message - Show speaking notification immediately
     */
    private fun handleWalkieTalkieMessage(callData: FcmDataHandler.CallData) {
        try {
            val speakerName = callData.callName
            Log.i(TAG, "📻 FCM received: $speakerName is speaking in walkie-talkie")
            
            // 1. IMMEDIATELY show speaking notification when FCM arrives
            val notificationManager = com.duckbuck.app.notifications.CallNotificationManager(this)
            notificationManager.showSpeakingNotification(speakerName)
            Log.i(TAG, "📢 IMMEDIATE notification shown: $speakerName is speaking")
            
            // 2. Store speaker info for proper leave notifications
            WalkieTalkieService.storeSpeakerInfo(
                context = this,
                speakerUid = callData.uid,
                speakerUsername = callData.callName
            )
            
            // 3. Join/maintain the walkie-talkie channel to keep call active
            // This ensures the connection persists and we can detect when user leaves
            WalkieTalkieService.joinChannel(
                context = this,
                channelId = callData.channelId,
                channelName = callData.callName,
                token = callData.token,
                uid = callData.uid,
                username = callData.callName  // Pass username for leave notifications
            )
            
            Log.i(TAG, "✅ Walkie-talkie channel joined to maintain active connection")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling walkie-talkie message", e)
        }
    }

    override fun onDestroy() {
        Log.i(TAG, "🛑 FCM Service Orchestrator shutting down...")
        super<FirebaseMessagingService>.onDestroy()
    }
}
