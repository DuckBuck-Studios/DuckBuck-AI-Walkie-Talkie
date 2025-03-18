package com.example.duckbuck
import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class AppLogger(context: Context) {
    companion object {
        private const val TAG = "AppLogger"
        private const val LOG_FILE_NAME = "fcm_debug_log.json"
        private var instance: AppLogger? = null
        
        @Synchronized
        fun getInstance(context: Context): AppLogger {
            if (instance == null) {
                instance = AppLogger(context.applicationContext)
            }
            return instance!!
        }
    }
    
    private val logFile: File
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)
    
    init {
        // Create logs directory if it doesn't exist
        val logsDir = File(context.filesDir, "logs")
        if (!logsDir.exists()) {
            logsDir.mkdirs()
        }
        
        // Initialize the log file
        logFile = File(logsDir, LOG_FILE_NAME)
        
        // Create initial JSON structure if file doesn't exist
        if (!logFile.exists()) {
            try {
                val initialJson = JSONObject()
                initialJson.put("app_sessions", JSONArray())
                initialJson.put("created_at", dateFormat.format(Date()))
                logFile.writeText(initialJson.toString(2))
            } catch (e: Exception) {
                Log.e(TAG, "Error initializing log file: ${e.message}", e)
            }
        }
    }
    
    @Synchronized
    fun logEvent(tag: String, message: String, additionalData: Map<String, Any>? = null) {
        try {
            // Read current content
            val jsonContent = logFile.readText()
            val rootJson = JSONObject(jsonContent)
            
            // Get sessions array
            val sessions = rootJson.getJSONArray("app_sessions")
            
            // Check if we need to create a new session
            var currentSession: JSONObject
            if (sessions.length() == 0) {
                currentSession = createNewSession()
                sessions.put(currentSession)
            } else {
                currentSession = sessions.getJSONObject(sessions.length() - 1)
            }
            
            // Get events array for current session
            val events = currentSession.getJSONArray("events")
            
            // Create and add new event
            val event = JSONObject()
            event.put("timestamp", dateFormat.format(Date()))
            event.put("tag", tag)
            event.put("message", message)
            
            // Add additional data if provided
            if (additionalData != null) {
                val dataJson = JSONObject()
                for ((key, value) in additionalData) {
                    dataJson.put(key, value.toString())
                }
                event.put("data", dataJson)
            }
            
            events.put(event)
            
            // Update session
            currentSession.put("events", events)
            currentSession.put("last_updated", dateFormat.format(Date()))
            
            // Write back to file
            logFile.writeText(rootJson.toString(2))
            
            // Also log to Android log
            Log.d(TAG, "$tag: $message")
        } catch (e: Exception) {
            Log.e(TAG, "Error writing to log file: ${e.message}", e)
        }
    }
    
    @Synchronized
    private fun createNewSession(): JSONObject {
        val session = JSONObject()
        val currentTime = dateFormat.format(Date())
        session.put("session_id", UUID.randomUUID().toString())
        session.put("started_at", currentTime)
        session.put("last_updated", currentTime)
        session.put("events", JSONArray())
        return session
    }
    
    @Synchronized
    fun startNewSession(reason: String) {
        try {
            // Read current content
            val jsonContent = logFile.readText()
            val rootJson = JSONObject(jsonContent)
            
            // Get sessions array
            val sessions = rootJson.getJSONArray("app_sessions")
            
            // Create new session
            val newSession = createNewSession()
            newSession.put("reason", reason)
            
            // Add to sessions
            sessions.put(newSession)
            
            // Write back to file
            logFile.writeText(rootJson.toString(2))
        } catch (e: Exception) {
            Log.e(TAG, "Error creating new session: ${e.message}", e)
        }
    }
    
    fun getLogFilePath(): String {
        return logFile.absolutePath
    }
} 