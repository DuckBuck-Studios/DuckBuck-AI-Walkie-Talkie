package com.duckbuck.app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import com.duckbuck.app.security.SecurityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val SECURITY_CHANNEL = "com.duckbuck.app/security"
    private lateinit var securityManager: SecurityManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        try {
            // Log app signing info in debug mode
            logAppSigningInfo()
            
            // Initialize security manager
            securityManager = SecurityManager(applicationContext, this)
            
            // Initialize all security components with verbose logging in debug mode
            val isDevelopment = isDebuggable(applicationContext)
            val isInitialized = securityManager.initialize(isDevelopment, isDevelopment)
            
            if (!isInitialized) {
                Log.e(TAG, "Security components failed to initialize properly")
                // In production, you might want to take more drastic actions
                // like preventing the app from starting or limiting functionality
            }
            
            // Set up method channel for security operations
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler { call, result ->
                securityManager.handleMethodCall(call, result)
            }
            
            Log.d(TAG, "Security components initialized successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing security components: ${e.message}")
        }
    }
    
    private fun logAppSigningInfo() {
        try {
            val packageManager = applicationContext.packageManager
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
            }
            
            Log.d(TAG, "Package name: $packageName")
            Log.d(TAG, "Version name: ${packageInfo.versionName}")
            Log.d(TAG, "Version code: ${packageInfo.longVersionCode}")
        } catch (e: Exception) {
            Log.e(TAG, "Error logging app signing info: ${e.message}")
        }
    }
    
    /**
     * Check if the app is running in debug mode
     * @param context Application context
     * @return True if the app is in debug mode
     */
    private fun isDebuggable(context: Context): Boolean {
        return try {
            val applicationInfo = context.applicationInfo
            (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if app is debuggable: ${e.message}")
            false
        }
    }

}