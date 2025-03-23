package com.example.duckbuck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import android.content.Context
import android.util.Log
import com.example.duckbuck.service.AgoraService
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    private var agoraService: AgoraService? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Agora service
        agoraService = AgoraService(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
    
    override fun onDestroy() {
        // Clean up resources
        agoraService?.dispose()
        agoraService = null
        super.onDestroy()
    }
}
