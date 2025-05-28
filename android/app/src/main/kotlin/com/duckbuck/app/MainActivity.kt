package com.duckbuck.app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
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
            
            // Initialize security manager using singleton pattern
            securityManager = SecurityManager.getInstance(applicationContext, this)
            
            // Initialize all security components
            val isDevelopment = isDebuggable(applicationContext)
            Log.i(TAG, "🔐 App running in ${if (isDevelopment) "DEVELOPMENT" else "PRODUCTION"} mode")
            
            // Use coroutine to call suspend function
            lifecycleScope.launch {
                val initResult = securityManager.initialize(isDevelopment)
                
                if (!initResult.success) {
                    Log.e(TAG, "Security initialization failed: ${initResult.message}")
                    Log.e(TAG, "Violations: ${initResult.violations.joinToString(", ")}")
                    
                    if (!isDevelopment) {
                        // Security failures in production are now handled by SecurityManager.handleProductionSecurityFailure()
                        // This will terminate the app for critical violations like signature tampering
                        Log.e(TAG, "Production security failure detected - SecurityManager will take appropriate action")
                    } else {
                        Log.w(TAG, "Development mode: Security warnings detected but app will continue running")
                    }
                } else {
                    Log.i(TAG, "Security initialization successful: ${initResult.message}")
                }
            }
            
            // Set up method channel for security operations
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL).setMethodCallHandler(securityManager)
            
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
     * Check if the app is running in debug/development mode
     * @param context Application context
     * @return True if the app is in debug/development mode
     */
    private fun isDebuggable(context: Context): Boolean {
        return try {
            // Check if app is debuggable (standard check)
            val applicationInfo = context.applicationInfo
            val isDebug = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
            
            // Always report true when running in an emulator to avoid termination
            val isEmulator = Build.FINGERPRINT.startsWith("generic") ||
                    Build.FINGERPRINT.startsWith("unknown") ||
                    Build.MODEL.contains("google_sdk") ||
                    Build.MODEL.contains("Emulator") ||
                    Build.MODEL.contains("Android SDK built for x86") ||
                    Build.MANUFACTURER.contains("Genymotion") ||
                    (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
                    "google_sdk" == Build.PRODUCT
            
            val isDevelopment = isDebug || isEmulator
            
            Log.i(TAG, "App running in ${if (isDevelopment) "DEVELOPMENT" else "PRODUCTION"} mode " +
                    "(Debug: $isDebug, Emulator: $isEmulator)")
            
            isDevelopment
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if app is debuggable: ${e.message}")
            // In case of errors, assume development mode for safety
            true
        }
    }

}