package com.example.duckbuck

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.annotation.NonNull
import com.example.duckbuck.services.AgoraPlugin

class MainActivity : FlutterActivity() {
    private lateinit var agoraPlugin: AgoraPlugin
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize and register the Agora plugin
        agoraPlugin = AgoraPlugin(applicationContext)
        agoraPlugin.registerWith(flutterEngine)
    }
    
    override fun onDestroy() {
        // Clean up resources when activity is destroyed
        if (::agoraPlugin.isInitialized) {
            agoraPlugin.dispose()
        }
        super.onDestroy()
    }
} 