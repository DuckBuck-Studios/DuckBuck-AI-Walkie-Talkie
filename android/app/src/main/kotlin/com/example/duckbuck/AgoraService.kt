package com.example.duckbuck
import android.content.Intent
import android.os.Build
import android.content.Context
import android.util.Log
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.video.VideoCanvas
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import android.os.PowerManager
import java.util.Timer
import java.util.TimerTask

class AgoraService(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val TAG = "AgoraService"
    private var rtcEngine: RtcEngine? = null
    private var localUid: Int = 0
    private val channel = MethodChannel(messenger, "com.example.duckbuck/agora")
    private var wakeLock: PowerManager.WakeLock? = null
    private var keepAliveTimer: Timer? = null
    private var lastChannelName: String? = null
    private var lastToken: String? = null
    
    init {
        channel.setMethodCallHandler(this)
    }
    
    // Event handler for RTC events
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
            Log.d(TAG, "onJoinChannelSuccess: $channel, uid: $uid")
            localUid = uid
            lastChannelName = channel
            
            // Start more aggressive keep-alive mechanism
            startKeepAliveTimer()
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            Log.d(TAG, "onUserJoined: $uid")
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "onUserOffline: $uid reason: $reason")
        }
        
        override fun onError(err: Int) {
            Log.e(TAG, "onError: $err")
            
            // Try to recover from common errors by rejoining
            if ((err == 101 || err == 109 || err == 110 || err == 8 || err == 1 || err == 2) 
                && lastChannelName != null && lastToken != null) {
                
                Log.d(TAG, "Attempting to recover from error $err by rejoining channel")
                Timer().schedule(object : TimerTask() {
                    override fun run() {
                        // Rejoin the channel
                        try {
                            rtcEngine?.leaveChannel()
                            Thread.sleep(300)
                            rtcEngine?.joinChannel(lastToken, lastChannelName, null, localUid)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to rejoin after error: ${e.message}")
                        }
                    }
                }, 2000)
            }
        }
        
        override fun onConnectionStateChanged(state: Int, reason: Int) {
            Log.d(TAG, "onConnectionStateChanged: state=$state, reason=$reason")
            
            // Handle disconnection automatically
            if (state == Constants.CONNECTION_STATE_DISCONNECTED || 
                state == Constants.CONNECTION_STATE_FAILED) {
                
                if (lastChannelName != null && lastToken != null) {
                    Log.d(TAG, "Reconnecting due to connection state change")
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            try {
                                rtcEngine?.leaveChannel()
                                Thread.sleep(200)
                                rtcEngine?.joinChannel(lastToken, lastChannelName, null, localUid)
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to reconnect: ${e.message}")
                            }
                        }
                    }, 1000)
                }
            }
        }
    }
    
    private var isInForegroundMode = false
    
    // Handle method calls from Flutter
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeEngine" -> {
                val appId = call.argument<String>("appId")
                if (appId != null) {
                    initializeEngine(appId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "AppId is required", null)
                }
            }
            "joinChannel" -> {
                val token = call.argument<String>("token") ?: ""
                val channelName = call.argument<String>("channelName")
                val userId = call.argument<Int>("userId") ?: 0
                val muteOnJoin = call.argument<Boolean>("muteOnJoin") ?: false
                
                // Save token for reconnection purposes
                lastToken = token
                lastChannelName = channelName
                
                // Acquire wake lock to keep CPU running
                acquireWakeLock()
                
                if (channelName != null) {
                    joinChannel(token, channelName, userId, muteOnJoin, result)
                    // Start foreground service when joining channel with enhanced parameters
                    startEnhancedForegroundService(channelName, token, userId)
                } else {
                    result.error("INVALID_ARGUMENT", "Channel name is required", null)
                }
            }
            
            "leaveChannel" -> {
                leaveChannel(result)
                // Stop foreground service when leaving channel
                stopForegroundService()
                releaseWakeLock()
            }
            
            "cleanup" -> {
                cleanup(result)
                // Stop foreground service during cleanup
                stopForegroundService()
                releaseWakeLock()
            }
            "muteLocalAudio" -> {
                val mute = call.argument<Boolean>("mute") ?: false
                muteLocalAudio(mute, result)
            }
            "enableLocalVideo" -> {
                val enable = call.argument<Boolean>("enable") ?: true
                enableLocalVideo(enable, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    // Acquire wakelock to keep CPU active
    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "DuckBuck:AgoraServiceWakeLock"
            )
            
            // Acquire indefinitely
            wakeLock?.setReferenceCounted(false)
            wakeLock?.acquire()
            
            Log.d(TAG, "Acquired wake lock for Agora service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire wake lock: ${e.message}", e)
        }
    }
    
    private fun releaseWakeLock() {
        if (wakeLock?.isHeld == true) {
            try {
                wakeLock?.release()
                Log.d(TAG, "Released wake lock")
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing wake lock: ${e.message}", e)
            }
        }
    }
    
    // Initialize Agora Engine
    private fun initializeEngine(appId: String, result: Result) {
        try {
            rtcEngine = RtcEngine.create(context, appId, rtcEventHandler)
            
            // Enable audio mode to continue in background
            rtcEngine?.setEnableSpeakerphone(true)
            rtcEngine?.setDefaultAudioRoutetoSpeakerphone(true)
            
            // Enhanced parameters for better background operation
            rtcEngine?.setParameters("{\"rtc.room_leave.when_queue_empty\": false}")
            rtcEngine?.setParameters("{\"rtc.queue_blocked_mode\": 0}")
            rtcEngine?.setParameters("{\"rtc.enable_accelerate_connection\": true}")
            rtcEngine?.setParameters("{\"rtc.no_disconnect_when_network_broken\": true}")
            rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
            rtcEngine?.setParameters("{\"rtc.forced_connection\": true}")
            rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
            rtcEngine?.setParameters("{\"rtc.audio.keep_send_audioframe_when_silence\": true}")
            rtcEngine?.setParameters("{\"rtc.enable_connect_always\": true}")
            rtcEngine?.setParameters("{\"rtc.enable_session_resume\": true}")
            rtcEngine?.setParameters("{\"rtc.retry_connection_limit\": 30}")
            rtcEngine?.setParameters("{\"rtc.engine.force_high_perf\": true}")
            
            // This is critical for background operation
            rtcEngine?.enableAudioVolumeIndication(200, 3, false)
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Agora engine", e)
            result.error("INIT_ERROR", "Failed to initialize Agora engine", e.message)
        }
    }
    
    // Join a channel
    private fun joinChannel(token: String, channelName: String, userId: Int, muteOnJoin: Boolean, result: Result) {
        if (rtcEngine == null) {
            result.error("ENGINE_NOT_INITIALIZED", "Agora engine not initialized", null)
            return
        }
        
        try {
            // Configure media options
            val options = ChannelMediaOptions().apply {
                channelProfile = Constants.CHANNEL_PROFILE_COMMUNICATION
                clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
                publishCameraTrack = false
                publishMicrophoneTrack = !muteOnJoin
                
                // These options help maintain connection in background
                autoSubscribeAudio = true
                publishMediaPlayerAudioTrack = true
            }
            
            // Mute audio if required
            if (muteOnJoin) {
                rtcEngine?.muteLocalAudioStream(true)
            }
            
            // Set optimized audio parameters
            rtcEngine?.setAudioProfile(
                Constants.AUDIO_PROFILE_SPEECH_STANDARD,
                Constants.AUDIO_SCENARIO_CHATROOM
            )
            
            // Join the channel with the specified userId
            rtcEngine?.setParameters("{\"rtc.connection.backup_server_enable\": true}")
            rtcEngine?.joinChannel(token, channelName, null, userId)
            
            // Save token and channel for reconnection
            lastToken = token
            lastChannelName = channelName
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to join channel", e)
            result.error("JOIN_ERROR", "Failed to join channel", e.message)
        }
    }
    
    // Keep-alive timer to prevent connection from dropping
    private fun startKeepAliveTimer() {
        keepAliveTimer?.cancel()
        keepAliveTimer = Timer()
        keepAliveTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    if (rtcEngine != null) {
                        // Send regular operations to keep connection active
                        rtcEngine?.enableAudioVolumeIndication(500, 3, false)
                        rtcEngine?.muteLocalAudioStream(false)
                        
                        // Vary signal volume slightly to ensure real traffic
                        val randomVolume = 95 + (Math.random() * 10).toInt()
                        rtcEngine?.adjustRecordingSignalVolume(randomVolume)
                        
                        // Refresh connection parameters
                        rtcEngine?.setParameters("{\"rtc.keep_alive_interval\": 1000}")
                        rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
                        
                        Log.d(TAG, "Keep-alive pulse sent")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in keep-alive timer: ${e.message}")
                    
                    // If connection fails, try to reconnect
                    if (lastToken != null && lastChannelName != null) {
                        try {
                            Log.d(TAG, "Attempting to rejoin from keep-alive failure")
                            rtcEngine?.leaveChannel()
                            Thread.sleep(200)
                            rtcEngine?.joinChannel(lastToken, lastChannelName, null, localUid)
                        } catch (e2: Exception) {
                            Log.e(TAG, "Failed to reconnect from keep-alive: ${e2.message}")
                        }
                    }
                }
            }
        }, 2000, 2000) // Every 2 seconds
    }
    
    // Leave the channel
    private fun leaveChannel(result: Result) {
        if (rtcEngine == null) {
            result.error("ENGINE_NOT_INITIALIZED", "Agora engine not initialized", null)
            return
        }
        
        try {
            keepAliveTimer?.cancel()
            rtcEngine?.leaveChannel()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to leave channel", e)
            result.error("LEAVE_ERROR", "Failed to leave channel", e.message)
        }
    }
    
    // Cleanup before joining another channel or destroying
    private fun cleanup(result: Result) {
        try {
            keepAliveTimer?.cancel()
            rtcEngine?.leaveChannel()
            RtcEngine.destroy()
            rtcEngine = null
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cleanup", e)
            result.error("CLEANUP_ERROR", "Failed to cleanup resources", e.message)
        }
    }
    
    // Mute local audio
    private fun muteLocalAudio(mute: Boolean, result: Result) {
        if (rtcEngine == null) {
            result.error("ENGINE_NOT_INITIALIZED", "Agora engine not initialized", null)
            return
        }
        
        try {
            rtcEngine?.muteLocalAudioStream(mute)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to mute audio", e)
            result.error("MUTE_ERROR", "Failed to mute audio", e.message)
        }
    }
    
    // Toggle local video
    private fun enableLocalVideo(enable: Boolean, result: Result) {
        if (rtcEngine == null) {
            result.error("ENGINE_NOT_INITIALIZED", "Agora engine not initialized", null)
            return
        }
        
        try {
            rtcEngine?.enableLocalVideo(enable)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to toggle video", e)
            result.error("VIDEO_ERROR", "Failed to toggle video", e.message)
        }
    }
    
    // New method to enable/disable background mode
    private fun enableBackgroundMode(enable: Boolean, result: Result) {
        if (rtcEngine == null) {
            result.error("ENGINE_NOT_INITIALIZED", "Agora engine not initialized", null)
            return
        }
        
        try {
            if (enable) {
                rtcEngine?.setParameters("{\"rtc.running_background\": true}")
                rtcEngine?.setEnableSpeakerphone(false)
            } else {
                rtcEngine?.setParameters("{\"rtc.running_background\": false}")
                rtcEngine?.setEnableSpeakerphone(true)
            }
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set background mode", e)
            result.error("BACKGROUND_MODE_ERROR", "Failed to set background mode", e.message)
        }
    }
    
    // Enhanced foreground service with robust parameters
    private fun startEnhancedForegroundService(channelName: String, token: String, uid: Int) {
        if (!isInForegroundMode) {
            val serviceIntent = Intent(context, AgoraForegroundService::class.java).apply {
                putExtra("channelName", channelName)
                putExtra("token", token)
                putExtra("uid", uid)
                putExtra("isConnected", true)
                
                // Add flags to ensure intent is delivered
                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
            }
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                isInForegroundMode = true
                Log.d(TAG, "Started enhanced foreground service")
                
                // Schedule periodic checks to make sure service stays running
                Timer().scheduleAtFixedRate(object : TimerTask() {
                    override fun run() {
                        if (isInForegroundMode && !isServiceRunning(AgoraForegroundService::class.java)) {
                            Log.d(TAG, "Foreground service not running, restarting")
                            
                            // Service isn't running, restart it
                            val restartIntent = Intent(context, AgoraForegroundService::class.java).apply {
                                putExtra("channelName", channelName)
                                putExtra("token", token)
                                putExtra("uid", uid)
                                putExtra("isConnected", true)
                                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                            }
                            
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                context.startForegroundService(restartIntent)
                            } else {
                                context.startService(restartIntent)
                            }
                        }
                    }
                }, 5000, 10000) // Check every 10 seconds
            } catch (e: Exception) {
                Log.e(TAG, "Error starting foreground service: ${e.message}", e)
            }
        }
    }
    
    // Check if a service is running
    private fun isServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        
        @Suppress("DEPRECATION") // This remains the most reliable way to check
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
    
    // Stop foreground service
    private fun stopForegroundService() {
        if (isInForegroundMode) {
            try {
                context.stopService(Intent(context, AgoraForegroundService::class.java))
                isInForegroundMode = false
                Log.d(TAG, "Stopped foreground service")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping foreground service: ${e.message}", e)
            }
        }
    }
    
    // Clean up resources when plugin is detached
    fun dispose() {
        keepAliveTimer?.cancel()
        channel.setMethodCallHandler(null)
        rtcEngine?.leaveChannel()
        RtcEngine.destroy()
        rtcEngine = null
        stopForegroundService()
        releaseWakeLock()
    }
}