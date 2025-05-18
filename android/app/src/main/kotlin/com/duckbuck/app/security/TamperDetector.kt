package com.duckbuck.app.security

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import java.security.MessageDigest
import java.util.Arrays

/**
 * TamperDetector verifies the app's signature to detect if it has been tampered with.
 * It uses the app's signing certificate to verify integrity.
 */
class TamperDetector(private val context: Context) {

    private val tag = "TamperDetector"
    
    // Expected certificate hash for release builds (in HEX format)
    // This is the SHA-256 hash of our app's signing certificate
    // For development builds, we're using the debug keystore certificate hash
    private val expectedCertSha256 = "186F6AE36F18CA016BF3B4EAAF45A346129EB043FD70BB48E2E2F0C9C59E0D24"
    
    // Alternative expected hashes (for different build flavors or key rotation)
    private val alternativeHashes = listOf<String>(
        // Add additional valid certificate hashes here if you use multiple signing keys
        // or plan to rotate keys in the future
    )
    
    /**
     * Verify that the app has not been tampered with by checking its signature.
     * @return True if the app signature is valid, false otherwise
     */
    fun verifyAppSignature(): Boolean {
        try {
            val signature = getAppSignature()
            
            // For development, always log the signature hash
            Log.d(tag, "App signature: $signature")
            
            if (expectedCertSha256.isEmpty()) {
                // For development, don't enforce verification if not configured
                Log.d(tag, "Running in development mode - signature verification disabled")
                return true
            }
            
            // Check against primary expected hash
            var isValid = signature.equals(expectedCertSha256, ignoreCase = true)
            
            // If primary check fails, try alternative hashes (for key rotation)
            if (!isValid && alternativeHashes.isNotEmpty()) {
                isValid = alternativeHashes.any { it.equals(signature, ignoreCase = true) }
            }
            
            if (!isValid) {
                Log.w(tag, "App signature verification failed")
                Log.d(tag, "Expected: $expectedCertSha256")
                Log.d(tag, "Actual: $signature")
                
                // Perform additional tamper checks
                val isPackageManagerValid = verifyPackageManager()
                val isAppInfoValid = verifyAppInfo()
                
                Log.d(tag, "Additional checks - PackageManager: $isPackageManagerValid, AppInfo: $isAppInfoValid")
            } else {
                Log.d(tag, "App signature verified successfully")
            }
            
            return isValid
        } catch (e: Exception) {
            Log.e(tag, "Error verifying app signature: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Get the app's signature as a SHA-256 hash in hexadecimal format
     * @return The signature hash string
     */
    private fun getAppSignature(): String {
        val packageManager = context.packageManager
        val packageName = context.packageName
        
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val packageInfo = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
            packageInfo.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            val packageInfo = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES
            )
            @Suppress("DEPRECATION")
            packageInfo.signatures
        }
        
        if (signatures.isNullOrEmpty()) {
            throw SecurityException("No signatures found")
        }
        
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(signatures[0]!!.toByteArray())
        
        // Convert to hex string without separators
        return digest.joinToString("") { "%02X".format(it) }
    }
    
    /**
     * Verify that the package manager hasn't been tampered with
     */
    private fun verifyPackageManager(): Boolean {
        try {
            // Get the APK path
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            val applicationInfo = packageInfo.applicationInfo
            val apkPath = applicationInfo?.sourceDir ?: ""
            
            // Check if APK exists
            val apkFile = java.io.File(apkPath)
            if (apkPath.isEmpty() || !apkFile.exists()) {
                Log.w(tag, "APK file does not exist at expected path: $apkPath")
                return false
            }
            
            // Check APK size - extremely small APKs might be suspicious
            if (apkFile.length() < 1024 * 1024) { // Less than 1MB
                Log.w(tag, "APK file suspiciously small: ${apkFile.length()} bytes")
                return false
            }
            
            return true
        } catch (e: Exception) {
            Log.e(tag, "Error verifying package manager: ${e.message}")
            return false
        }
    }
    
    /**
     * Verify app info for signs of tampering
     */
    private fun verifyAppInfo(): Boolean {
        try {
            val applicationInfo = context.applicationInfo 
            context.packageManager.getPackageInfo(context.packageName, 0)
            
            // Check for suspicious flags
            val isDebuggable = (applicationInfo?.flags ?: 0) and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0
            val isTest = (applicationInfo?.flags ?: 0) and android.content.pm.ApplicationInfo.FLAG_TEST_ONLY != 0
            
            // In production, these should both be false
            if (isDebuggable || isTest) {
                Log.w(tag, "App has suspicious flags: debuggable=$isDebuggable, testOnly=$isTest")
                // Don't fail here as these are normal in development builds
            }
            
            return true
        } catch (e: Exception) {
            Log.e(tag, "Error verifying app info: ${e.message}")
            return false
        }
    }
}
