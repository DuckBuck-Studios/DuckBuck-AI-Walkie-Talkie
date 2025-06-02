package com.duckbuck.app.fcm

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.duckbuck.app.core.AppLogger
import com.duckbuck.app.services.WalkieTalkieService
import com.duckbuck.app.audio.VolumeAcquireManager
import com.duckbuck.app.channel.ChannelOccupancyManager

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
    private lateinit var volumeAcquireManager: VolumeAcquireManager
    private lateinit var occupancyManager: ChannelOccupancyManager
    
    override fun onCreate() {
        super.onCreate()
        AppLogger.i(TAG, "🚀 FCM Service Orchestrator starting up...")
        
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
            volumeAcquireManager = VolumeAcquireManager(this)
            occupancyManager = ChannelOccupancyManager()
            AppLogger.i(TAG, "✅ All high-level managers initialized successfully")
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error initializing managers", e)
        }
    }
    
    /**
     * Handle incoming FCM messages
     * Delegates to appropriate managers based on message type and app state
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super<FirebaseMessagingService>.onMessageReceived(remoteMessage)
        
        try {
            AppLogger.i(TAG, "📨 FCM message received: ${remoteMessage.messageId}")
            
            // 🕐 TIMESTAMP VALIDATION: Check if message is fresh before processing
            if (!isMessageTimestampValid(remoteMessage)) {
                AppLogger.w(TAG, "🕐 FCM message too old, rejecting stale walkie-talkie invitation")
                return
            }
            
            // Extract call data from message
            val callData = FcmDataHandler.extractCallData(remoteMessage)
            
            if (callData == null) {
                AppLogger.w(TAG, "⚠️ Invalid or non-call FCM message received")
                return
            }
            
            AppLogger.i(TAG, "📻 Processing walkie-talkie channel message: ${callData.callName}")
            
            // For walkie-talkie: Always auto-connect to channel regardless of app state
            // Use the dedicated service for persistent connection
            handleWalkieTalkieMessage(callData)
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error processing FCM message", e)
        }
    }
    
    /**
     * Handle FCM token refresh
     */
    override fun onNewToken(token: String) {
        super<FirebaseMessagingService>.onNewToken(token)
        AppLogger.i(TAG, "🔄 FCM token refreshed: ${token.take(10)}...")
        
        // TODO: Send token to app server if needed
        // This can be handled by sending the token to Flutter side
    }
    
    /**
     * Handle walkie-talkie channel message - Check occupancy before showing notifications
     */
    private fun handleWalkieTalkieMessage(callData: FcmDataHandler.CallData) {
        try {
            val speakerName = callData.callName
            AppLogger.i(TAG, "📻 FCM received: $speakerName is speaking in walkie-talkie")
            
            // 🔊 VOLUME ACQUIRE FEATURE: Set volume to 100% maximum when joining channel via FCM
            // This works in all three app states: foreground, background, and killed
            val currentAppState = appStateDetector.getCurrentAppState()
            AppLogger.i(TAG, "📱 Current app state: $currentAppState")
            
            // Acquire maximum volume for optimal walkie-talkie experience
            volumeAcquireManager.acquireMaximumVolume(
                mode = VolumeAcquireManager.Companion.VolumeAcquireMode.MEDIA_AND_VOICE_CALL,
                showUIFeedback = currentAppState == FcmAppStateDetector.AppState.FOREGROUND
            )
            
            val volumeInfo = volumeAcquireManager.getCurrentVolumeInfo()
            AppLogger.i(TAG, "🔊 Volume acquired for walkie-talkie - $volumeInfo")
            
            // 1. Store speaker info for proper leave notifications
            WalkieTalkieService.storeSpeakerInfo(
                context = this,
                speakerUid = callData.uid,
                speakerUsername = callData.callName
            )
            
            // 2. Join the walkie-talkie channel first to establish connection
            WalkieTalkieService.joinChannel(
                context = this,
                channelId = callData.channelId,
                channelName = callData.callName,
                token = callData.token,
                uid = callData.uid,
                username = callData.callName,  // Pass username for leave notifications
                callerPhoto = callData.callerPhoto  // Pass photo URL directly from FCM data
            )
            
            // 3. Start occupancy check - notifications will be shown only if channel has users
            // The WalkieTalkieService will handle the occupancy check and show notifications
            // only when the channel is confirmed to have other users
            AppLogger.i(TAG, "✅ Walkie-talkie channel join initiated - occupancy check will determine notification display")
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error handling walkie-talkie message", e)
        }
    }

    /**
     * Validate if FCM message timestamp is fresh (within 15 seconds)
     * @param remoteMessage The FCM message to validate
     * @return true if message is fresh, false if stale
     */
    private fun isMessageTimestampValid(remoteMessage: RemoteMessage): Boolean {
        try {
            val timestampString = remoteMessage.data["timestamp"]
            val messageTimestamp = timestampString?.toLongOrNull()
            
            if (messageTimestamp == null) {
                AppLogger.w(TAG, "🕐 No timestamp found in FCM message")
                return false
            }
            
            val currentTime = System.currentTimeMillis() / 1000 // Convert to seconds
            val messageAge = currentTime - messageTimestamp
            
            AppLogger.d(TAG, "🕐 Message timestamp: $messageTimestamp, Current: $currentTime, Age: ${messageAge}s")
            
            return if (messageAge <= 15) {
                AppLogger.i(TAG, "✅ Message is fresh (${messageAge}s old) - proceeding")
                true
            } else {
                AppLogger.w(TAG, "❌ Message is stale (${messageAge}s old) - rejecting to prevent empty channel join")
                false
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error validating message timestamp", e)
            return false // Treat as stale if can't validate
        }
    }

    override fun onDestroy() {
        AppLogger.i(TAG, "🛑 FCM Service Orchestrator shutting down...")
        
        // Cleanup occupancy manager
        if (::occupancyManager.isInitialized) {
            occupancyManager.cleanup()
        }
        
        super<FirebaseMessagingService>.onDestroy()
    }
}
