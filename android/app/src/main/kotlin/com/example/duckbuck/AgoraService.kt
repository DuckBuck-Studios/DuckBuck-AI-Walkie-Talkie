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

class AgoraService(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val TAG = "AgoraService"
    private var rtcEngine: RtcEngine? = null
    private var localUid: Int = 0
    private val channel = MethodChannel(messenger, "com.example.duckbuck/agora")
    
    init {
        channel.setMethodCallHandler(this)
    }
    
    // Event handler for RTC events
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
            Log.d(TAG, "onJoinChannelSuccess: $channel, uid: $uid")
            localUid = uid
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            Log.d(TAG, "onUserJoined: $uid")
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "onUserOffline: $uid reason: $reason")
        }
        
        override fun onError(err: Int) {
            Log.e(TAG, "onError: $err")
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
                
                if (channelName != null) {
                    joinChannel(token, channelName, userId, muteOnJoin, result)
                    // Start foreground service when joining channel
                    startForegroundService(channelName)
                } else {
                    result.error("INVALID_ARGUMENT", "Channel name is required", null)
                }
            }
            
            "leaveChannel" -> {
                leaveChannel(result)
                // Stop foreground service when leaving channel
                stopForegroundService()
            }
            
            "cleanup" -> {
                cleanup(result)
                // Stop foreground service during cleanup
                stopForegroundService()
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
    
    // Initialize Agora Engine
    private fun initializeEngine(appId: String, result: Result) {
        try {
            rtcEngine = RtcEngine.create(context, appId, rtcEventHandler)
            
            // Enable audio mode to continue in background
            rtcEngine?.setEnableSpeakerphone(true)
            rtcEngine?.setDefaultAudioRoutetoSpeakerphone(true)
            
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
            
            // Join the channel with the specified userId
            rtcEngine?.joinChannel(token, channelName, userId, options)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to join channel", e)
            result.error("JOIN_ERROR", "Failed to join channel", e.message)
        }
    }
    
    // Leave the channel
    private fun leaveChannel(result: Result) {
        if (rtcEngine == null) {
            result.error("ENGINE_NOT_INITIALIZED", "Agora engine not initialized", null)
            return
        }
        
        try {
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
    
    // Start foreground service
    private fun startForegroundService(channelName: String) {
        if (!isInForegroundMode) {
            val serviceIntent = Intent(context, AgoraForegroundService::class.java).apply {
                putExtra("channelName", channelName)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            isInForegroundMode = true
            Log.d(TAG, "Started foreground service")
        }
    }
    
    // Stop foreground service
    private fun stopForegroundService() {
        if (isInForegroundMode) {
            context.stopService(Intent(context, AgoraForegroundService::class.java))
            isInForegroundMode = false
            Log.d(TAG, "Stopped foreground service")
        }
    }
    
    // Clean up resources when plugin is detached
    fun dispose() {
        channel.setMethodCallHandler(null)
        rtcEngine?.leaveChannel()
        RtcEngine.destroy()
        rtcEngine = null
        stopForegroundService()
    }
}