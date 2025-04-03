package com.example.duckbuck.services

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AgoraPlugin(private val context: Context) : MethodCallHandler {
    private val CHANNEL_NAME = "com.duckbuck/agora_rtc"
    private lateinit var channel: MethodChannel
    private val agoraService = AgoraService(context)

    // Register the plugin with the Flutter engine
    fun registerWith(flutterEngine: FlutterEngine) {
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        agoraService.setMethodChannel(channel)
    }

    // Handle method calls from Flutter
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val appId = call.argument<String>("appId")
                val enableVideo = call.argument<Boolean>("enableVideo") ?: false
                
                if (appId.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "App ID is required", null)
                    return
                }
                
                val initialized = agoraService.initialize(appId, enableVideo)
                result.success(initialized)
            }
            
            "joinChannel" -> {
                val token = call.argument<String>("token") ?: ""
                val channelName = call.argument<String>("channelName")
                val uid = call.argument<Int>("uid") ?: 0
                val enableAudio = call.argument<Boolean>("enableAudio") ?: true
                val enableVideo = call.argument<Boolean>("enableVideo") ?: false
                
                if (channelName.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Channel name is required", null)
                    return
                }
                
                val joined = agoraService.joinChannel(token, channelName, uid, enableAudio, enableVideo)
                result.success(joined)
            }
            
            "leaveChannel" -> {
                val left = agoraService.leaveChannel()
                result.success(left)
            }
            
            "enableLocalAudio" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                val success = agoraService.enableLocalAudio(enabled)
                result.success(success)
            }
            
            "muteLocalAudio" -> {
                val mute = call.argument<Boolean>("mute") ?: false
                val success = agoraService.muteLocalAudio(mute)
                result.success(success)
            }
            
            "enableLocalVideo" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val success = agoraService.enableLocalVideo(enabled)
                result.success(success)
            }
            
            "muteLocalVideo" -> {
                val mute = call.argument<Boolean>("mute") ?: false
                val success = agoraService.muteLocalVideo(mute)
                result.success(success)
            }
            
            "switchCamera" -> {
                val success = agoraService.switchCamera()
                result.success(success)
            }
            
            "setupLocalVideo" -> {
                val viewId = call.argument<Int>("viewId") ?: -1
                if (viewId == -1) {
                    result.error("INVALID_ARGUMENT", "View ID is required", null)
                    return
                }
                val success = agoraService.setupLocalVideo(viewId)
                result.success(success)
            }
            
            "setupRemoteVideo" -> {
                val uid = call.argument<Int>("uid") ?: 0
                val viewId = call.argument<Int>("viewId") ?: -1
                if (viewId == -1) {
                    result.error("INVALID_ARGUMENT", "View ID is required", null)
                    return
                }
                val success = agoraService.setupRemoteVideo(uid, viewId)
                result.success(success)
            }
            
            "setVolume" -> {
                val volume = call.argument<Int>("volume") ?: 100
                val success = agoraService.setVolume(volume)
                result.success(success)
            }
            
            "muteRemoteUser" -> {
                val uid = call.argument<Int>("uid") ?: 0
                val mute = call.argument<Boolean>("mute") ?: false
                val success = agoraService.muteRemoteUser(uid, mute)
                result.success(success)
            }
            
            "getRemoteUsers" -> {
                val users = agoraService.getRemoteUsers()
                result.success(users)
            }
            
            "setEnableSpeakerphone" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                val success = agoraService.setEnableSpeakerphone(enabled)
                result.success(success)
            }
            
            "destroy" -> {
                agoraService.destroy()
                result.success(true)
            }
            
            else -> result.notImplemented()
        }
    }
    
    // Cleanup resources when plugin is detached
    fun dispose() {
        agoraService.destroy()
    }
} 