package com.example.duckbuck.service

import android.content.Context
import android.util.Log
import io.agora.rtc2.Constants
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.video.VideoCanvas
import io.agora.rtc2.video.VideoEncoderConfiguration
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import java.util.Timer
import java.util.TimerTask
import java.util.HashMap
import java.util.concurrent.ConcurrentHashMap
import android.view.SurfaceView

class AgoraService(private val context: Context, messenger: BinaryMessenger) {
    companion object {
        private const val TAG = "AgoraService"
        
        // Events
        private const val EVENT_USER_JOINED = "userJoined"
        private const val EVENT_USER_LEFT = "userLeft"
        private const val EVENT_JOIN_CHANNEL_SUCCESS = "joinChannelSuccess"
        private const val EVENT_CONNECTION_STATE_CHANGED = "connectionStateChanged"
        private const val EVENT_LEAVE_CHANNEL = "leaveChannel"
        private const val EVENT_ERROR = "error"
        private const val EVENT_TOKEN_EXPIRED = "tokenExpired"
        private const val EVENT_LOCAL_AUDIO_STATE_CHANGED = "localAudioStateChanged"
        private const val EVENT_LOCAL_VIDEO_STATE_CHANGED = "localVideoStateChanged"
        private const val EVENT_REMOTE_AUDIO_STATE_CHANGED = "remoteAudioStateChanged"
        private const val EVENT_REMOTE_VIDEO_STATE_CHANGED = "remoteVideoStateChanged"
        
        // Media options
        private const val DEFAULT_AUDIO_PROFILE = Constants.AUDIO_PROFILE_DEFAULT
        private const val DEFAULT_AUDIO_SCENARIO = Constants.AUDIO_SCENARIO_CHATROOM
        private const val DEFAULT_VIDEO_PROFILE = VideoEncoderConfiguration.STANDARD_BITRATE
    }
    
    private val methodChannel = MethodChannel(messenger, "com.example.duckbuck/agora")
    private var rtcEngine: RtcEngine? = null
    private var channelName: String? = null
    private var localUid: Int = 0
    private var token: String? = null
    private var remoteUsers = ConcurrentHashMap<Int, Boolean>() // uid -> isActive
    private var keepAliveTimer: Timer? = null
    private var autoLeaveEnabled = true // Whether to auto-leave when all users leave
    private var lastActiveTimestamp = System.currentTimeMillis()
    private var isMuted = false
    private var isVideoEnabled = true
    private var localSurfaceView: SurfaceView? = null
    private var remoteSurfaceViews = HashMap<Int, SurfaceView>()
    
    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeEngine" -> {
                    val appId = call.argument<String>("appId")
                    if (appId.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "App ID is required", null)
                        return@setMethodCallHandler
                    }
                    initialize(appId, result)
                }
                "joinChannel" -> {
                    val token = call.argument<String>("token") ?: ""
                    val channelName = call.argument<String>("channelName")
                    val userId = call.argument<Int>("userId") ?: 0
                    val muteOnJoin = call.argument<Boolean>("muteOnJoin") ?: true // Default to muted
                    
                    if (channelName.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "Channel name is required", null)
                        return@setMethodCallHandler
                    }
                    
                    // Create options from the parameters
                    val options = ChannelMediaOptions()
                    options.publishMicrophoneTrack = !muteOnJoin // Default to muted (false)
                    options.autoSubscribeAudio = true // Speaker on
                    options.publishCameraTrack = false // Camera off by default
                    options.autoSubscribeVideo = true
                    options.clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
                    
                    joinChannel(token, channelName, userId, options, result)
                }
                "leaveChannel" -> {
                    leaveChannel(result)
                }
                "cleanup" -> {
                    cleanupResources(result)
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
    }
    
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String, uid: Int, elapsed: Int) {
            Log.d(TAG, "onJoinChannelSuccess: channel=$channel, uid=$uid")
            localUid = uid
            channelName = channel
            lastActiveTimestamp = System.currentTimeMillis()
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["channel"] = channel
            eventData["uid"] = uid
            eventData["elapsed"] = elapsed
            sendEvent(EVENT_JOIN_CHANNEL_SUCCESS, eventData)
            
            // Start keep-alive mechanism
            startKeepAliveTimer()
        }
        
        override fun onUserJoined(uid: Int, elapsed: Int) {
            Log.d(TAG, "onUserJoined: uid=$uid")
            remoteUsers[uid] = true
            lastActiveTimestamp = System.currentTimeMillis()
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["uid"] = uid
            eventData["elapsed"] = elapsed
            sendEvent(EVENT_USER_JOINED, eventData)
        }
        
        override fun onUserOffline(uid: Int, reason: Int) {
            Log.d(TAG, "onUserOffline: uid=$uid, reason=$reason")
            remoteUsers.remove(uid)
            lastActiveTimestamp = System.currentTimeMillis()
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["uid"] = uid
            eventData["reason"] = reason
            sendEvent(EVENT_USER_LEFT, eventData)
            
            // Remove remote surface view if it exists
            remoteSurfaceViews.remove(uid)
            
            // Check if we should auto-leave when all users are gone
            if (autoLeaveEnabled && remoteUsers.isEmpty()) {
                Log.d(TAG, "All remote users left, automatically leaving channel")
                Timer().schedule(object : TimerTask() {
                    override fun run() {
                        leaveChannelInternal()
                    }
                }, 2000) // Wait 2 seconds before leaving
            }
        }
        
        override fun onConnectionStateChanged(state: Int, reason: Int) {
            Log.d(TAG, "onConnectionStateChanged: state=$state, reason=$reason")
            lastActiveTimestamp = System.currentTimeMillis()
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["state"] = state
            eventData["reason"] = reason
            sendEvent(EVENT_CONNECTION_STATE_CHANGED, eventData)
            
            // Try to reconnect if disconnected
            if (state == Constants.CONNECTION_STATE_DISCONNECTED || 
                state == Constants.CONNECTION_STATE_FAILED) {
                
                if (channelName != null && token != null) {
                    Log.d(TAG, "Connection lost, attempting to reconnect")
                    Timer().schedule(object : TimerTask() {
                        override fun run() {
                            try {
                                rtcEngine?.leaveChannel()
                                rtcEngine?.joinChannel(token, channelName, null, localUid)
                                Log.d(TAG, "Reconnection attempt initiated")
                            } catch (e: Exception) {
                                Log.e(TAG, "Reconnection failed: ${e.message}")
                            }
                        }
                    }, 2000)
                }
            }
        }
        
        override fun onError(err: Int) {
            Log.e(TAG, "onError: code=$err")
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["errorCode"] = err
            sendEvent(EVENT_ERROR, eventData)
            
            // Handle token expiration
            if (err == Constants.ERR_TOKEN_EXPIRED) {
                sendEvent(EVENT_TOKEN_EXPIRED, HashMap<String, Any>())
            }
        }
        
        override fun onTokenPrivilegeWillExpire(token: String) {
            Log.d(TAG, "onTokenPrivilegeWillExpire")
            sendEvent(EVENT_TOKEN_EXPIRED, HashMap<String, Any>())
        }
        
        override fun onLeaveChannel(stats: RtcStats) {
            Log.d(TAG, "onLeaveChannel")
            remoteUsers.clear()
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["duration"] = stats.totalDuration
            sendEvent(EVENT_LEAVE_CHANNEL, eventData)
        }
        
        override fun onLocalAudioStateChanged(state: Int, error: Int) {
            Log.d(TAG, "onLocalAudioStateChanged: state=$state, error=$error")
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["state"] = state
            eventData["error"] = error
            sendEvent(EVENT_LOCAL_AUDIO_STATE_CHANGED, eventData)
        }
        
        override fun onRemoteAudioStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
            Log.d(TAG, "onRemoteAudioStateChanged: uid=$uid, state=$state, reason=$reason")
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["uid"] = uid
            eventData["state"] = state
            eventData["reason"] = reason
            sendEvent(EVENT_REMOTE_AUDIO_STATE_CHANGED, eventData)
        }
        
        override fun onRemoteVideoStateChanged(uid: Int, state: Int, reason: Int, elapsed: Int) {
            Log.d(TAG, "onRemoteVideoStateChanged: uid=$uid, state=$state, reason=$reason")
            
            // Send event to Flutter
            val eventData = HashMap<String, Any>()
            eventData["uid"] = uid
            eventData["state"] = state
            eventData["reason"] = reason
            sendEvent(EVENT_REMOTE_VIDEO_STATE_CHANGED, eventData)
        }
    }
    
    private fun parseMediaOptions(call: io.flutter.plugin.common.MethodCall): ChannelMediaOptions {
        val options = ChannelMediaOptions()
        
        // Audio options
        options.publishMicrophoneTrack = call.argument<Boolean>("publishAudio") ?: true
        options.autoSubscribeAudio = call.argument<Boolean>("subscribeAudio") ?: true
        
        // Video options
        options.publishCameraTrack = call.argument<Boolean>("publishVideo") ?: true
        options.autoSubscribeVideo = call.argument<Boolean>("subscribeVideo") ?: true
        
        // Client role: 1 = broadcaster, 2 = audience
        options.clientRoleType = call.argument<Int>("clientRole") ?: Constants.CLIENT_ROLE_BROADCASTER
        
        return options
    }
    
    private fun initialize(appId: String, result: MethodChannel.Result) {
        try {
            if (rtcEngine != null) {
                cleanupResources(null)
            }
            
            Log.d(TAG, "Initializing RTC engine with app ID: $appId")
            rtcEngine = RtcEngine.create(context, appId, rtcEventHandler)
            
            // Set default channel profile
            rtcEngine?.setChannelProfile(Constants.CHANNEL_PROFILE_COMMUNICATION)
            
            // Enable audio/video
            rtcEngine?.enableAudio()
            rtcEngine?.enableVideo()
            
            // Set default audio profile
            rtcEngine?.setAudioProfile(DEFAULT_AUDIO_PROFILE, DEFAULT_AUDIO_SCENARIO)
            
            // Enable dual stream mode for better performance
            rtcEngine?.enableDualStreamMode(true)
            
            // Set reliable connection parameters
            rtcEngine?.setParameters("{\"rtc.enable_accelerate_connection\": true}")
            rtcEngine?.setParameters("{\"rtc.enable_session_resume\": true}")
            rtcEngine?.setParameters("{\"rtc.use_persistent_connection\": true}")
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize RTC engine: ${e.message}", e)
            result.error("INIT_ERROR", "Failed to initialize Agora engine: ${e.message}", null)
        }
    }
    
    private fun joinChannel(token: String, channelName: String, uid: Int, options: ChannelMediaOptions, result: MethodChannel.Result) {
        try {
            if (rtcEngine == null) {
                result.error("NOT_INITIALIZED", "Agora engine not initialized", null)
                return
            }
            
            Log.d(TAG, "Joining channel: $channelName with UID: $uid")
            this.channelName = channelName
            this.token = token
            this.localUid = uid
            
            // Initialize state
            remoteUsers.clear()
            isMuted = !options.publishMicrophoneTrack // Default to muted (true)
            isVideoEnabled = options.publishCameraTrack // Default to camera off (false)
            
            // Apply mute state before joining
            rtcEngine?.muteLocalAudioStream(isMuted)
            rtcEngine?.enableLocalVideo(isVideoEnabled)
            
            // Join the channel
            val joinResult = rtcEngine?.joinChannel(token, channelName, null, uid)
            Log.d(TAG, "Join channel result: $joinResult")
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to join channel: ${e.message}", e)
            result.error("JOIN_ERROR", "Failed to join channel: ${e.message}", null)
        }
    }
    
    private fun leaveChannelInternal() {
        try {
            Log.d(TAG, "Leaving channel internally")
            rtcEngine?.leaveChannel()
            
            // Clean up resources
            keepAliveTimer?.cancel()
            keepAliveTimer = null
            
            // Clear state
            channelName = null
            token = null
            remoteUsers.clear()
            
            // Clean up views
            remoteSurfaceViews.clear()
            localSurfaceView = null
            
            Log.d(TAG, "Left channel successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error leaving channel: ${e.message}", e)
        }
    }
    
    private fun leaveChannel(result: MethodChannel.Result?) {
        try {
            if (rtcEngine == null) {
                result?.error("NOT_INITIALIZED", "Agora engine not initialized", null)
                return
            }
            
            leaveChannelInternal()
            result?.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to leave channel: ${e.message}", e)
            result?.error("LEAVE_ERROR", "Failed to leave channel: ${e.message}", null)
        }
    }
    
    private fun muteLocalAudio(mute: Boolean, result: MethodChannel.Result) {
        try {
            if (rtcEngine == null) {
                result.error("NOT_INITIALIZED", "Agora engine not initialized", null)
                return
            }
            
            Log.d(TAG, "Muting local audio: $mute")
            rtcEngine?.muteLocalAudioStream(mute)
            isMuted = mute
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to mute audio: ${e.message}", e)
            result.error("MUTE_ERROR", "Failed to mute audio: ${e.message}", null)
        }
    }
    
    private fun enableLocalVideo(enable: Boolean, result: MethodChannel.Result) {
        try {
            if (rtcEngine == null) {
                result.error("NOT_INITIALIZED", "Agora engine not initialized", null)
                return
            }
            
            Log.d(TAG, "Enabling local video: $enable")
            rtcEngine?.enableLocalVideo(enable)
            isVideoEnabled = enable
            
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable video: ${e.message}", e)
            result.error("VIDEO_ERROR", "Failed to enable video: ${e.message}", null)
        }
    }
    
    private fun setupLocalVideo(viewId: Int, result: MethodChannel.Result) {
        try {
            if (rtcEngine == null) {
                result.error("NOT_INITIALIZED", "Agora engine not initialized", null)
                return
            }
            
            // Create surface view for local video
            val surfaceView = SurfaceView(context)
            surfaceView.id = viewId
            
            // Set up local video renderer
            rtcEngine?.setupLocalVideo(VideoCanvas(surfaceView, VideoCanvas.RENDER_MODE_HIDDEN, 0))
            localSurfaceView = surfaceView
            
            Log.d(TAG, "Local video setup complete with view ID: $viewId")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup local video: ${e.message}", e)
            result.error("VIDEO_SETUP_ERROR", "Failed to setup local video: ${e.message}", null)
        }
    }
    
    private fun setupRemoteVideo(uid: Int, viewId: Int, result: MethodChannel.Result) {
        try {
            if (rtcEngine == null) {
                result.error("NOT_INITIALIZED", "Agora engine not initialized", null)
                return
            }
            
            // Create surface view for remote video
            val surfaceView = SurfaceView(context)
            surfaceView.id = viewId
            
            // Set up remote video renderer
            rtcEngine?.setupRemoteVideo(VideoCanvas(surfaceView, VideoCanvas.RENDER_MODE_HIDDEN, uid))
            remoteSurfaceViews[uid] = surfaceView
            
            Log.d(TAG, "Remote video setup complete for UID: $uid with view ID: $viewId")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to setup remote video: ${e.message}", e)
            result.error("VIDEO_SETUP_ERROR", "Failed to setup remote video: ${e.message}", null)
        }
    }
    
    private fun startKeepAliveTimer() {
        keepAliveTimer?.cancel()
        keepAliveTimer = Timer()
        keepAliveTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                try {
                    if (rtcEngine != null) {
                        // Perform minimal operations to keep connection active
                        rtcEngine?.muteLocalAudioStream(isMuted)
                        
                        Log.d(TAG, "Keep-alive ping sent")
                        lastActiveTimestamp = System.currentTimeMillis()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in keep-alive timer: ${e.message}")
                }
            }
        }, 15000, 15000) // Every 15 seconds
    }
    
    private fun sendEvent(eventName: String, params: HashMap<String, Any>) {
        methodChannel.invokeMethod(eventName, params)
    }
    
    // Renamed from destroy to cleanupResources to avoid confusion
    private fun cleanupResources(result: MethodChannel.Result?) {
        try {
            Log.d(TAG, "Cleaning up Agora service resources")
            
            // Cancel timer
            keepAliveTimer?.cancel()
            keepAliveTimer = null
            
            // Leave channel if still connected
            rtcEngine?.leaveChannel()
            
            // Clean up resources - Use appropriate cleanup method
            try {
                // Try with different approaches since the API may vary
                try {
                    val destroyMethod = RtcEngine::class.java.getMethod("destroy")
                    destroyMethod.invoke(rtcEngine)
                } catch (e: Exception) {
                    Log.w(TAG, "Method 'destroy' not found, trying with different approach...")
                    rtcEngine = null
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up RtcEngine: ${e.message}")
            } finally {
                rtcEngine = null
            }
            
            // Clear state
            channelName = null
            token = null
            remoteUsers.clear()
            remoteSurfaceViews.clear()
            localSurfaceView = null
            
            result?.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up Agora service: ${e.message}", e)
            result?.error("CLEANUP_ERROR", "Failed to clean up Agora engine: ${e.message}", null)
        }
    }
    
    // Clean up when the class is no longer needed
    fun dispose() {
        cleanupResources(null)
        methodChannel.setMethodCallHandler(null)
    }
} 