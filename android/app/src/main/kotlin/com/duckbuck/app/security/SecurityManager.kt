package com.duckbuck.app.security

import android.app.Activity
import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import okhttp3.OkHttpClient

/**
 * Central Security Manager for DuckBuck app.
 * Coordinates security modules and provides a unified interface.
 */
class SecurityManager private constructor(
    private val context: Context,
    private val activity: Activity?
) : MethodChannel.MethodCallHandler {
    
    companion object {
        private const val TAG = "SecurityManager"
        
        @Volatile
        private var INSTANCE: SecurityManager? = null
        
        fun getInstance(context: Context, activity: Activity? = null): SecurityManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SecurityManager(context.applicationContext, activity).also { INSTANCE = it }
            }
        }
    }
    
    // Security modules
    private val rootDetector = RootDetector()
    private val tamperDetector = TamperDetector(context)
    private val sslPinningManager = SSLPinningManager.getInstance(context)
    private val integrityChecker = IntegrityChecker(context)
    
    // Coroutine scope for async operations
    private val securityScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    // Security state
    private var isInitialized = false
    private var violations = mutableListOf<String>()

    
    /**
     * Initialize the security system
     */
    suspend fun initialize(isDevelopment: Boolean = false): SecurityInitResult {
        return withContext(Dispatchers.Default) {
            try {
                Log.i(TAG, "Initializing Security Manager...")
                
                violations.clear()
                
                // SSL pinning manager is already initialized in its constructor
                // No additional initialization needed
                
                // Perform initial security checks
                performSecurityChecks(isDevelopment)
                
                isInitialized = true
                
                val message = if (violations.isEmpty()) {
                    "Security system initialized successfully"
                } else {
                    "Security system initialized with ${violations.size} violations"
                }
                
                Log.i(TAG, "Security initialization completed - isDevelopment: $isDevelopment")
                
                SecurityInitResult(
                    success = true,
                    message = message,
                    violations = violations.toList()
                )
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize security system", e)
                SecurityInitResult(
                    success = false,
                    message = "Security initialization failed: ${e.message}",
                    violations = listOf("INITIALIZATION_FAILED")
                )
            }
        }
    }
    
    /**
     * Perform comprehensive security checks with production enforcement
     */
    private suspend fun performSecurityChecks(isDevelopment: Boolean = false): Boolean {
        return try {
            // Log mode for debugging purposes
            Log.i(TAG, "Running security checks in ${if (isDevelopment) "DEVELOPMENT" else "PRODUCTION"} mode")
            
            val rootCheck = performRootCheck() 
            val tamperCheck = performTamperCheck()
            val integrityCheck = performIntegrityCheck()
            
            val allChecksPassed = rootCheck && tamperCheck && integrityCheck
            
            // Handle critical security failures in production
            if (!allChecksPassed && !isDevelopment) {
                handleProductionSecurityFailure()
            } else if (!allChecksPassed) {
                Log.w(TAG, "Security checks failed but app will continue running in DEVELOPMENT mode")
            }
            
            allChecksPassed
        } catch (e: Exception) {
            Log.e(TAG, "Security check failed", e)
            violations.add("SECURITY_CHECK_ERROR: ${e.message}")
            
            // Terminate app in production for security check errors
            if (!isDevelopment) {
                handleProductionSecurityFailure()
            }
            
            false
        }
    }
    
    /**
     * Perform root detection check
     */
    private suspend fun performRootCheck(): Boolean {
        return withContext(Dispatchers.IO) {
            val isRooted = rootDetector.isDeviceRooted()
            if (isRooted) {
                violations.add("ROOT_DETECTED")
                Log.w(TAG, "Root detection: Device appears to be rooted")
            }
            !isRooted
        }
    }
    
    /**
     * Perform tamper detection check
     */
    private suspend fun performTamperCheck(): Boolean {
        return withContext(Dispatchers.IO) {
            val signatureValid = tamperDetector.verifyAppSignature()
            if (!signatureValid) {
                violations.add("SIGNATURE_INVALID")
                Log.w(TAG, "Tamper detection: App signature verification failed")
            }
            signatureValid
        }
    }
    
    /**
     * Perform integrity check
     */
    private suspend fun performIntegrityCheck(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val token = integrityChecker.requestIntegrityToken()
                if (token.isNotEmpty()) {
                    Log.d(TAG, "Integrity check: Token obtained successfully")
                    return@withContext true
                } else {
                    violations.add("INTEGRITY_TOKEN_FAILED")
                    Log.w(TAG, "Integrity check: Failed to obtain token")
                    return@withContext false
                }
            } catch (e: Exception) {
                violations.add("INTEGRITY_CHECK_ERROR")
                Log.w(TAG, "Integrity check failed: ${e.message}")
                return@withContext false
            }
        }
    }
    
    /**
     * Get current security status
     */
    fun getSecurityStatus(): SecurityStatus {
        return SecurityStatus(
            isInitialized = isInitialized,
            violationCount = violations.size,
            lastCheckTime = System.currentTimeMillis()
        )
    }
    
    /**
     * Handle method channel calls from Flutter
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                securityScope.launch {
                    try {
                        val isDevelopment = call.argument<Boolean>("isDevelopment") ?: false
                        val initResult = initialize(isDevelopment)
                        
                        val resultMap = mapOf(
                            "success" to initResult.success,
                            "message" to initResult.message,
                            "violations" to initResult.violations
                        )
                        
                        withContext(Dispatchers.Main) {
                            result.success(resultMap)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SECURITY_ERROR", e.message, null)
                        }
                    }
                }
            }
            
            "getSecurityStatus" -> {
                try {
                    val status = getSecurityStatus()
                    val statusMap = mapOf(
                        "isInitialized" to status.isInitialized,
                        "violationCount" to status.violationCount,
                        "lastCheckTime" to status.lastCheckTime
                    )
                    result.success(statusMap)
                } catch (e: Exception) {
                    result.error("SECURITY_ERROR", e.message, null)
                }
            }
            
            "performSecurityChecks" -> {
                securityScope.launch {
                    try {
                        val isDevelopment = call.argument<Boolean>("isDevelopment") ?: false
                        val checkResult = performSecurityChecks(isDevelopment)
                        val resultMap = mapOf(
                            "isSecure" to checkResult,
                            "violations" to violations.toList()
                        )
                        
                        withContext(Dispatchers.Main) {
                            result.success(resultMap)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SECURITY_ERROR", e.message, null)
                        }
                    }
                }
            }
            
            "isDeviceRooted" -> {
                try {
                    val isRooted = rootDetector.isDeviceRooted()
                    result.success(isRooted)
                } catch (e: Exception) {
                    result.error("SECURITY_ERROR", e.message, null)
                }
            }
            
            "verifyAppSignature" -> {
                try {
                    val isValid = tamperDetector.verifyAppSignature()
                    result.success(isValid)
                } catch (e: Exception) {
                    result.error("SECURITY_ERROR", e.message, null)
                }
            }
            
            "testSSLPinning" -> {
                securityScope.launch {
                    try {
                        val client = sslPinningManager.createSecureOkHttpClient()
                        val testResult = withContext(Dispatchers.IO) {
                            client.newCall(
                                okhttp3.Request.Builder()
                                    .url("https://www.google.com")
                                    .build()
                            ).execute().use { response ->
                                response.isSuccessful
                            }
                        }
                        
                        withContext(Dispatchers.Main) {
                            result.success(testResult)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("SSL_PINNING_ERROR", e.message, null)
                        }
                    }
                }
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Clean up resources
     */
    fun cleanup() {
        securityScope.cancel()
        sslPinningManager.cleanup()
    }
    
    /**
     * Handle critical security failures in production
     * This method will take progressive action based on violation type and severity:
     * 1. Report to backend security monitoring (future enhancement)
     * 2. Disable sensitive features (future enhancement)
     * 3. Terminate the app for critical violations
     */
    private fun handleProductionSecurityFailure() {
        try {
            Log.e(TAG, "CRITICAL SECURITY VIOLATION DETECTED IN PRODUCTION")
            Log.e(TAG, "Security violations: ${violations.joinToString(", ")}")
            
            // Check if any critical violations that warrant immediate termination
            val criticalViolations = listOf(
                "SIGNATURE_INVALID", 
                "INTEGRITY_TOKEN_FAILED",
                "INITIALIZATION_FAILED"
            )
            
            val hasCriticalViolation = violations.any { violation -> 
                criticalViolations.any { critical -> violation.contains(critical) }
            }
            
            if (hasCriticalViolation) {
                Log.e(TAG, "Critical security violation detected - terminating application")
                
                // Allow time for logs to be written
                securityScope.launch {
                    delay(300)
                    
                    // Force terminate the app in production
                    withContext(Dispatchers.Main) {
                        // Activity finish and System.exit to ensure complete termination
                        activity?.finishAffinity()
                        System.exit(1)
                    }
                }
            } else {
                // For less critical violations like ROOT_DETECTED, we might just log
                // and let the Flutter side decide on restrictions
                Log.w(TAG, "Non-critical security violation detected - restricting features")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling security failure", e)
            // Last resort - try to terminate if error occurs during handling
            System.exit(2)
        }
    }
}

/**
 * Data class for security initialization result
 */
data class SecurityInitResult(
    val success: Boolean,
    val message: String,
    val violations: List<String>
)

/**
 * Data class for security status
 */
data class SecurityStatus(
    val isInitialized: Boolean,
    val violationCount: Int,
    val lastCheckTime: Long
)
