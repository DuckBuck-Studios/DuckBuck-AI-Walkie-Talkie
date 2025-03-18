package com.example.duckbuck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import android.content.Context
import android.util.Log
import java.io.File
import org.json.JSONObject
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {
    private var agoraService: AgoraService? = null
    private val CHANNEL = "com.example.duckbuck/native_debug"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Agora Service
        agoraService = AgoraService(context, flutterEngine.dartExecutor.binaryMessenger)
        
        // Set up method channel for debug information
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDebugLogPath" -> {
                    val logger = AppLogger.getInstance(applicationContext)
                    val path = logger.getLogFilePath()
                    result.success(path)
                    Log.d("MainActivity", "Provided debug log path: $path")
                }
                "startNewLogSession" -> {
                    val reason = call.argument<String>("reason") ?: "Flutter requested"
                    val logger = AppLogger.getInstance(applicationContext)
                    logger.startNewSession(reason)
                    result.success(true)
                }
                "logEvent" -> {
                    val tag = call.argument<String>("tag") ?: "FlutterEvent"
                    val message = call.argument<String>("message") ?: "Event from Flutter"
                    val data = call.argument<Map<String, Any>>("data")
                    
                    val logger = AppLogger.getInstance(applicationContext)
                    logger.logEvent(tag, message, data)
                    result.success(true)
                }
                "clearLogs" -> {
                    try {
                        val logger = AppLogger.getInstance(applicationContext)
                        val logFile = File(logger.getLogFilePath())
                        
                        if (logFile.exists()) {
                            // Create a fresh log file with initial structure
                            val initialJson = JSONObject()
                            initialJson.put("app_sessions", JSONArray())
                            initialJson.put("created_at", SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date()))
                            initialJson.put("cleared_at", SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date()))
                            
                            logFile.writeText(initialJson.toString(2))
                            
                            // Start a new session after clearing
                            logger.startNewSession("After_Logs_Cleared")
                            
                            Log.d("MainActivity", "Logs cleared successfully")
                            result.success(true)
                        } else {
                            Log.d("MainActivity", "Log file doesn't exist, nothing to clear")
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error clearing logs: ${e.message}", e)
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onDestroy() {
        agoraService?.dispose()
        agoraService = null
        super.onDestroy()
    }
}
