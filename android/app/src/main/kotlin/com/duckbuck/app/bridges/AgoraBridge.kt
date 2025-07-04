package com.duckbuck.app.bridges

import android.content.Context
import android.util.Log
import com.duckbuck.app.services.agora.AgoraService
import com.duckbuck.app.services.walkietalkie.utils.WalkieTalkiePrefsUtil
import io.agora.rtc2.Constants
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * AgoraBridge - Handles communication between Flutter and native Agora functionality
 * Exposes all AgoraService methods and walkie-talkie utilities to Flutter
 */
class AgoraBridge(private val context: Context) : MethodCallHandler {
    
    companion object {
        private const val TAG = "AgoraBridge"
        const val CHANNEL_NAME = "com.duckbuck.app/agora"
    }
    
    private val agoraService = AgoraService.getInstance(context)
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            Log.d(TAG, "📞 Method called: ${call.method}")
            
            when (call.method) {
                // Engine lifecycle methods
                "initializeEngine" -> initializeEngine(result)
                "initializeAiEngine" -> initializeAiEngine(result)
                "destroyEngine" -> destroyEngine(result)
                
                // Channel management methods
                "joinChannel" -> joinChannel(call, result)
                "leaveChannel" -> leaveChannel(result)
                "isChannelConnected" -> isChannelConnected(result)
                "getCurrentChannelName" -> getCurrentChannelName(result)
                "getCurrentUid" -> getCurrentUid(result)
                
                // Audio control methods
                "muteLocalAudio" -> muteLocalAudio(call, result)
                "muteRemoteAudio" -> muteRemoteAudio(call, result)
                "muteAllRemoteAudio" -> muteAllRemoteAudio(call, result)
                "enableLocalAudio" -> enableLocalAudio(call, result)
                
                // Audio routing methods
                "setSpeakerphoneEnabled" -> setSpeakerphoneEnabled(call, result)
                "isSpeakerphoneEnabled" -> isSpeakerphoneEnabled(result)
                "setDefaultAudioRoute" -> setDefaultAudioRoute(call, result)
                
                // Volume control methods
                "adjustRecordingVolume" -> adjustRecordingVolume(call, result)
                "adjustPlaybackVolume" -> adjustPlaybackVolume(call, result)
                "adjustUserPlaybackVolume" -> adjustUserPlaybackVolume(call, result)
                
                // Audio configuration methods
                "setAudioScenario" -> setAudioScenario(call, result)
                
                // AI audio enhancement methods
                "loadAiDenoisePlugin" -> loadAiDenoisePlugin(result)
                "loadAiEchoCancellationPlugin" -> loadAiEchoCancellationPlugin(result)
                "enableAiDenoising" -> enableAiDenoising(call, result)
                "enableAiEchoCancellation" -> enableAiEchoCancellation(call, result)
                "setAiAudioScenario" -> setAiAudioScenario(result)
                "initializeAiAudioEnhancements" -> initializeAiAudioEnhancements(result)
                // Removed: "setAudioConfigParameters" and "reconfigureAiAudioForRoute" - deprecated methods
                
                // Walkie-talkie utility methods
                "getActiveCallData" -> getActiveCallData(result)
                "clearActiveCallData" -> clearActiveCallData(result)
                
                // Debug and status methods
                "resetAgoraService" -> resetAgoraService(result)
                "validateAgoraSetup" -> validateAgoraSetup(result)
                "forceCleanInitialization" -> forceCleanInitialization(result)
                "getAiModeStatus" -> getAiModeStatus(result)
                "getCurrentEngineMode" -> getCurrentEngineMode(result)
                
                else -> {
                    Log.w(TAG, "⚠️ Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling method call: ${call.method}", e)
            result.error("AGORA_ERROR", "Error: ${e.message}", e.toString())
        }
    }
    
    // ================================
    // ENGINE LIFECYCLE METHODS
    // ================================
    
    private fun initializeEngine(result: Result) {
        val success = agoraService.initializeEngine()
        Log.d(TAG, "🔧 Initialize engine result: $success")
        result.success(success)
    }
    
    private fun initializeAiEngine(result: Result) {
        val success = agoraService.initializeAiEngine()
        Log.d(TAG, "🤖 Initialize AI engine result: $success")
        result.success(success)
    }
    
    private fun destroyEngine(result: Result) {
        agoraService.destroy()
        Log.d(TAG, "💀 Engine destroyed")
        result.success(true)
    }
    
    // ================================
    // CHANNEL MANAGEMENT METHODS
    // ================================
    
    private fun joinChannel(call: MethodCall, result: Result) {
        val token = call.argument<String?>("token")
        val channelName = call.argument<String>("channelName")
        val uid = call.argument<Int>("uid") ?: 0
        val joinMuted = call.argument<Boolean>("joinMuted") ?: false
        
        if (channelName == null) {
            result.error("INVALID_ARGUMENT", "Channel name is required", null)
            return
        }
        
        val success = agoraService.joinChannel(token, channelName, uid, joinMuted)
        Log.d(TAG, "🎯 Join channel result: $success")
        result.success(success)
    }
    
    private fun leaveChannel(result: Result) {
        val success = agoraService.leaveChannel()
        Log.d(TAG, "🚪 Leave channel result: $success")
        result.success(success)
    }
    
    private fun isChannelConnected(result: Result) {
        val connected = agoraService.isChannelConnected()
        Log.d(TAG, "🔌 Channel connected: $connected")
        result.success(connected)
    }
    
    private fun getCurrentChannelName(result: Result) {
        val channelName = agoraService.getCurrentChannelName()
        Log.d(TAG, "📋 Current channel: $channelName")
        result.success(channelName)
    }
    
    private fun getCurrentUid(result: Result) {
        val uid = agoraService.getCurrentUid()
        Log.d(TAG, "👤 Current UID: $uid")
        result.success(uid)
    }
    
    // ================================
    // AUDIO CONTROL METHODS
    // ================================
    
    private fun muteLocalAudio(call: MethodCall, result: Result) {
        val muted = call.argument<Boolean>("muted") ?: false
        val success = agoraService.muteLocalAudio(muted)
        Log.d(TAG, "🔇 Mute local audio: $muted, result: $success")
        result.success(success)
    }
    
    private fun muteRemoteAudio(call: MethodCall, result: Result) {
        val uid = call.argument<Int>("uid")
        val muted = call.argument<Boolean>("muted") ?: false
        
        if (uid == null) {
            result.error("INVALID_ARGUMENT", "User ID is required", null)
            return
        }
        
        val success = agoraService.muteRemoteAudio(uid, muted)
        Log.d(TAG, "🔊 Mute remote audio: uid=$uid, muted=$muted, result: $success")
        result.success(success)
    }
    
    private fun muteAllRemoteAudio(call: MethodCall, result: Result) {
        val muted = call.argument<Boolean>("muted") ?: false
        val success = agoraService.muteAllRemoteAudio(muted)
        Log.d(TAG, "🔊 Mute all remote audio: $muted, result: $success")
        result.success(success)
    }
    
    private fun enableLocalAudio(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        val success = agoraService.enableLocalAudio(enabled)
        Log.d(TAG, "🎤 Enable local audio: $enabled, result: $success")
        result.success(success)
    }
    
    // ================================
    // AUDIO ROUTING METHODS
    // ================================
    
    private fun setSpeakerphoneEnabled(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        val success = agoraService.setSpeakerphoneEnabled(enabled)
        Log.d(TAG, "📢 Set speakerphone: $enabled, result: $success")
        result.success(success)
    }
    
    private fun isSpeakerphoneEnabled(result: Result) {
        val enabled = agoraService.isSpeakerphoneEnabled()
        Log.d(TAG, "📢 Speakerphone enabled: $enabled")
        result.success(enabled)
    }
    
    private fun setDefaultAudioRoute(call: MethodCall, result: Result) {
        val useSpeakerphone = call.argument<Boolean>("useSpeakerphone") ?: false
        val success = agoraService.setDefaultAudioRoute(useSpeakerphone)
        Log.d(TAG, "🎧 Set default audio route: $useSpeakerphone, result: $success")
        result.success(success)
    }
    
    // ================================
    // VOLUME CONTROL METHODS
    // ================================
    
    private fun adjustRecordingVolume(call: MethodCall, result: Result) {
        val volume = call.argument<Int>("volume") ?: 100
        val success = agoraService.adjustRecordingVolume(volume)
        Log.d(TAG, "🎤 Adjust recording volume: $volume, result: $success")
        result.success(success)
    }
    
    private fun adjustPlaybackVolume(call: MethodCall, result: Result) {
        val volume = call.argument<Int>("volume") ?: 100
        val success = agoraService.adjustPlaybackVolume(volume)
        Log.d(TAG, "🔊 Adjust playback volume: $volume, result: $success")
        result.success(success)
    }
    
    private fun adjustUserPlaybackVolume(call: MethodCall, result: Result) {
        val uid = call.argument<Int>("uid")
        val volume = call.argument<Int>("volume") ?: 100
        
        if (uid == null) {
            result.error("INVALID_ARGUMENT", "User ID is required", null)
            return
        }
        
        val success = agoraService.adjustUserPlaybackVolume(uid, volume)
        Log.d(TAG, "🔊 Adjust user playback volume: uid=$uid, volume=$volume, result: $success")
        result.success(success)
    }
    
    // ================================
    // AUDIO CONFIGURATION METHODS
    // ================================
    
    private fun setAudioScenario(call: MethodCall, result: Result) {
        val scenario = call.argument<Int>("scenario") ?: 7 // AUDIO_SCENARIO_CHATROOM_ENTERTAINMENT
        val success = agoraService.setAudioScenario(scenario)
        Log.d(TAG, "🎵 Set audio scenario: $scenario, result: $success")
        result.success(success)
    }
    
    // ================================
    // AI AUDIO ENHANCEMENT METHODS
    // ================================
    
    private fun loadAiDenoisePlugin(result: Result) {
        val success = agoraService.loadAiDenoisePlugin()
        Log.d(TAG, "🤖 Load AI denoise plugin result: $success")
        result.success(success)
    }
    
    private fun loadAiEchoCancellationPlugin(result: Result) {
        val success = agoraService.loadAiEchoCancellationPlugin()
        Log.d(TAG, "🤖 Load AI echo cancellation plugin result: $success")
        result.success(success)
    }
    
    private fun enableAiDenoising(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        val success = agoraService.enableAiDenoising(enabled)
        Log.d(TAG, "🤖 Enable AI denoising: $enabled, result: $success")
        result.success(success)
    }
    
    private fun enableAiEchoCancellation(call: MethodCall, result: Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        val success = agoraService.enableAiEchoCancellation(enabled)
        Log.d(TAG, "🤖 Enable AI echo cancellation: $enabled, result: $success")
        result.success(success)
    }
    
    private fun setAiAudioScenario(result: Result) {
        val success = agoraService.setAiAudioScenario()
        Log.d(TAG, "🤖 Set AI audio scenario result: $success")
        result.success(success)
    }
    
    private fun initializeAiAudioEnhancements(result: Result) {
        val success = agoraService.initializeAiAudioEnhancements()
        Log.d(TAG, "🤖 Initialize AI audio enhancements result: $success")
        result.success(success)
    }
    
    // ================================
    // WALKIE-TALKIE UTILITY METHODS
    // ================================
    
    private fun getActiveCallData(result: Result) {
        val callData = WalkieTalkiePrefsUtil.getActiveCallData(context)
        Log.d(TAG, "📱 Get active call data: $callData")
        result.success(callData)
    }
    
    private fun clearActiveCallData(result: Result) {
        WalkieTalkiePrefsUtil.clearCallEnded(context, "flutter_requested")
        Log.d(TAG, "🧹 Cleared active call data from Flutter request")
        result.success(true)
    }
    
    // ================================
    // DEBUG METHODS
    // ================================
    
    private fun resetAgoraService(result: Result) {
        AgoraService.resetInstance()
        Log.d(TAG, "🔄 Agora service reset")
        result.success(true)
    }
    
    private fun validateAgoraSetup(result: Result) {
        val isValid = agoraService.validateSetup()
        Log.d(TAG, "🔍 Agora setup validation: $isValid")
        result.success(isValid)
    }
    
    private fun forceCleanInitialization(result: Result) {
        val success = agoraService.forceCleanInitialization()
        Log.d(TAG, "🧹 Force clean initialization: $success")
        result.success(success)
    }
    
    private fun getAiModeStatus(result: Result) {
        val status = agoraService.getAiModeStatus()
        Log.d(TAG, "🤖 AI mode status: $status")
        result.success(status)
    }
    
    private fun getCurrentEngineMode(result: Result) {
        val mode = agoraService.getCurrentEngineMode()
        Log.d(TAG, "🔧 Current engine mode: $mode")
        result.success(mode)
    }
}
