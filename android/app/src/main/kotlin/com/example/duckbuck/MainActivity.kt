package com.example.duckbuck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin

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
