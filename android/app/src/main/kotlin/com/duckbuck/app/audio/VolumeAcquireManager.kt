package com.duckbuck.app.audio

import android.content.Context
import android.media.AudioManager
import com.duckbuck.app.core.AppLogger

/**
 * Volume Acquire Manager - Manages system volume acquisition for walkie-talkie
 * 
 * This manager ensures maximum volume (100%) is set when joining walkie-talkie channels
 * via FCM notifications, regardless of app state (foreground, background, or killed).
 * 
 * Features:
 * - Sets media volume to maximum when joining channels
 * - Stores previous volume to restore later if needed
 * - Handles different audio stream types appropriately
 * - Provides logging for volume changes
 */
class VolumeAcquireManager(private val context: Context) {
    
    companion object {
        private const val TAG = "VolumeAcquireManager"
        
        // Volume acquire modes
        enum class VolumeAcquireMode {
            MEDIA_ONLY,           // Only media volume
            VOICE_CALL_ONLY,      // Only voice call volume
            MEDIA_AND_VOICE_CALL, // Both media and voice call
            ALL_STREAMS          // All audio streams
        }
    }
    
    private val audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    
    // Store previous volumes for restoration if needed
    private var previousMediaVolume: Int = -1
    private var previousVoiceCallVolume: Int = -1
    private var previousRingVolume: Int = -1
    private var previousAlarmVolume: Int = -1
    
    /**
     * Acquire maximum volume for walkie-talkie channel joining
     * This is called when FCM triggers channel join in any app state
     * Always operates silently without showing volume UI
     * 
     * @param mode The volume acquire mode (default: MEDIA_AND_VOICE_CALL)
     */
    fun acquireMaximumVolume(
        mode: VolumeAcquireMode = VolumeAcquireMode.MEDIA_AND_VOICE_CALL
    ) {
        try {
            AppLogger.i(TAG, "🔊 Acquiring maximum volume for walkie-talkie (mode: $mode)")
            
            // Store current volumes before changing
            storePreviousVolumes()
            
            // Set volumes based on mode
            when (mode) {
                VolumeAcquireMode.MEDIA_ONLY -> {
                    setMaximumMediaVolume()
                }
                VolumeAcquireMode.VOICE_CALL_ONLY -> {
                    setMaximumVoiceCallVolume()
                }
                VolumeAcquireMode.MEDIA_AND_VOICE_CALL -> {
                    setMaximumMediaVolume()
                    setMaximumVoiceCallVolume()
                }
                VolumeAcquireMode.ALL_STREAMS -> {
                    setMaximumAllStreams()
                }
            }
            
            AppLogger.i(TAG, "✅ Volume acquisition completed successfully")
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error acquiring maximum volume", e)
        }
    }
    
    /**
     * Set media volume to maximum (for music, videos, game audio)
     * Always operates silently without showing volume UI
     */
    private fun setMaximumMediaVolume() {
        try {
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            
            AppLogger.d(TAG, "📻 Media volume before: $currentVolume/$maxVolume (${(currentVolume * 100 / maxVolume)}%)")
            
            // Always use silent flags to avoid showing volume UI
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxVolume, 0)
            
            // Verify the volume was actually set
            val newVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val percentage = if (maxVolume > 0) (newVolume * 100 / maxVolume) else 0
            
            AppLogger.i(TAG, "🎵 Media volume set: $newVolume/$maxVolume (${percentage}% - this is 100% of device max)")
            
            if (newVolume != maxVolume) {
                AppLogger.w(TAG, "⚠️ Volume not set to maximum! Expected: $maxVolume, Got: $newVolume")
            }
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error setting media volume", e)
        }
    }
    
    /**
     * Set voice call volume to maximum (for phone calls)
     * Always operates silently without showing volume UI
     */
    private fun setMaximumVoiceCallVolume() {
        try {
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL)
            
            AppLogger.d(TAG, "📞 Voice call volume: $currentVolume -> $maxVolume")
            
            // Always use silent flags to avoid showing volume UI
            audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, maxVolume, 0)
            
            AppLogger.i(TAG, "🗣️ Voice call volume set to maximum: $maxVolume")
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error setting voice call volume", e)
        }
    }
    
    /**
     * Set all audio stream volumes to maximum
     * Always operates silently without showing volume UI
     */
    private fun setMaximumAllStreams() {
        try {
            // Media stream (music, videos, games)
            setMaximumMediaVolume()
            
            // Voice call stream
            setMaximumVoiceCallVolume()
            
            // Ring stream (ringtones)
            val maxRingVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_RING)
            audioManager.setStreamVolume(AudioManager.STREAM_RING, maxRingVolume, 0)
            AppLogger.d(TAG, "📱 Ring volume set to maximum: $maxRingVolume")
            
            // Alarm stream
            val maxAlarmVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarmVolume, 0)
            AppLogger.d(TAG, "⏰ Alarm volume set to maximum: $maxAlarmVolume")
            
            AppLogger.i(TAG, "🔊 All audio streams set to maximum volume")
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error setting all stream volumes", e)
        }
    }
    
    /**
     * Store current volume levels before modification
     */
    private fun storePreviousVolumes() {
        try {
            previousMediaVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            previousVoiceCallVolume = audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL)
            previousRingVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            previousAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
            
            AppLogger.d(TAG, "💾 Stored previous volumes - Media: $previousMediaVolume, Voice: $previousVoiceCallVolume, Ring: $previousRingVolume, Alarm: $previousAlarmVolume")
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error storing previous volumes", e)
        }
    }
    
    /**
     * Restore previous volume levels (optional - for user preference)
     */
    fun restorePreviousVolumes() {
        try {
            if (previousMediaVolume >= 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previousMediaVolume, 0)
                AppLogger.d(TAG, "🔄 Restored media volume to: $previousMediaVolume")
            }
            
            if (previousVoiceCallVolume >= 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, previousVoiceCallVolume, 0)
                AppLogger.d(TAG, "🔄 Restored voice call volume to: $previousVoiceCallVolume")
            }
            
            if (previousRingVolume >= 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_RING, previousRingVolume, 0)
                AppLogger.d(TAG, "🔄 Restored ring volume to: $previousRingVolume")
            }
            
            if (previousAlarmVolume >= 0) {
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, previousAlarmVolume, 0)
                AppLogger.d(TAG, "🔄 Restored alarm volume to: $previousAlarmVolume")
            }
            
            AppLogger.i(TAG, "✅ Previous volumes restored successfully")
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error restoring previous volumes", e)
        }
    }
    
    /**
     * Get current volume information for debugging
     */
    fun getCurrentVolumeInfo(): String {
        return try {
            val mediaVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val mediaMaxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val voiceVolume = audioManager.getStreamVolume(AudioManager.STREAM_VOICE_CALL)
            val voiceMaxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
            
            "Media: $mediaVolume/$mediaMaxVolume, Voice: $voiceVolume/$voiceMaxVolume"
            
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error getting volume info", e)
            "Error getting volume info"
        }
    }
    
    /**
     * Check if volume is at maximum for media stream
     */
    fun isVolumeAtMaximum(): Boolean {
        return try {
            val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            currentVolume == maxVolume
        } catch (e: Exception) {
            AppLogger.e(TAG, "❌ Error checking maximum volume", e)
            false
        }
    }
}
