package com.example.duckbuck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import android.content.Context
import android.util.Log

class MainActivity : FlutterActivity() {
    private var agoraService: AgoraService? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Agora Service
        agoraService = AgoraService(context, flutterEngine.dartExecutor.binaryMessenger)
    }
    
    override fun onDestroy() {
        agoraService?.dispose()
        agoraService = null
        super.onDestroy()
    }
}
