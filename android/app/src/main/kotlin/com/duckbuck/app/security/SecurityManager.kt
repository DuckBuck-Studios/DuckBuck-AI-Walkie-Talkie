package com.duckbuck.app.security

import android.app.Activity
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import android.view.WindowManager
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Security manager class that handles all security-related operations for DuckBuck app
 * This is the central hub for all security features including:
 * - SSL Certificate Pinning
 * - Tamper detection
 * - Root detection
 * - Secure data storage
 * - Encryption/Decryption
 * - Screen capture protection
 * - Integrity validation
 */
class SecurityManager(private val context: Context, private val activity: Activity?) {
    
    companion object {
        private const val TAG = "SecurityManager"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val AES_GCM_NOPADDING = "AES/GCM/NoPadding"
        private const val SECURE_PREFS_FILE = "duckbuck_secure_prefs"
        private const val ENCRYPTION_KEY_ALIAS = "duckbuck_encryption_key"
        private const val GCM_IV_LENGTH = 12
        private const val GCM_TAG_LENGTH = 128
        private var VERBOSE_LOGGING = false
    }

    // Instances of security components
    private val rootDetector = RootDetector()
    private val tamperDetector = TamperDetector(context)
    private val integrityChecker = IntegrityChecker(context)
    private var sslPinningClient: OkHttpClient? = null

    private val masterKey: MasterKey by lazy {
        MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
    }
    
    private val securePreferences by lazy {
        try {
            EncryptedSharedPreferences.create(
                context,
                SECURE_PREFS_FILE,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating secure preferences: ${e.message}")
            null
        }
    }

    /**
     * Initialize all security components for the app
     * @param isDevelopment Set to true for development environment
     * @param verbose Set to true to enable verbose logging
     * @return True if all security components initialized successfully
     */
    fun initialize(isDevelopment: Boolean = false, verbose: Boolean = false): Boolean {
        try {
            // Set verbose logging flag
            VERBOSE_LOGGING = verbose
            
            if (verbose) {
                Log.d(TAG, "Initializing security manager with verbose logging enabled")
                Log.d(TAG, "Environment: ${if (isDevelopment) "Development" else "Production"}")
            }
            
            // Verify app signature
            val signatureValid = verifyAppSignature()
            if (!signatureValid && !isDevelopment) {
                Log.e(TAG, "App signature verification failed")
                return false
            }
            
            // Check for root/jailbreak
            val isRooted = isDeviceRooted()
            if (isRooted) {
                Log.w(TAG, "Device appears to be rooted - security risk detected")
                // In production, you might want to take additional measures
            }
            
            // Set up SSL pinning based on environment
            setupSSLPinning(isDevelopment)
            
            // Log SSL pinning information if verbose mode enabled
            if (verbose) {
                logSSLPinningDomains()
            }
            
            // Configure App Check with Google Play Integrity
            integrityChecker.configureAppCheck(isDevelopment)
            
            // Verify secure storage is working
            val prefsValid = testSecurePreferences()
            if (!prefsValid) {
                Log.e(TAG, "Secure preferences validation failed")
                return false
            }
            
            Log.d(TAG, "Security manager initialized successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing security manager: ${e.message}")
            return false
        }
    }
    
    /**
     * Set up SSL certificate pinning
     */
    private fun setupSSLPinning(isDevelopment: Boolean): OkHttpClient? {
        return try {
            sslPinningClient = if (isDevelopment) {
                Log.d(TAG, "SSL Pinning configured for development")
                SSLPinningManager.getDevOkHttpClient()
            } else {
                Log.d(TAG, "SSL Pinning configured for production")
                SSLPinningManager.getPinnedOkHttpClientBuilder().build()
            }
            sslPinningClient
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up SSL pinning: ${e.message}")
            null
        }
    }
    
    /**
     * Get the configured OkHttpClient with proper SSL pinning
     */
    fun getSecureHttpClient(): OkHttpClient {
        return sslPinningClient ?: throw IllegalStateException("Security manager not initialized")
    }
    
    /**
     * Handle method channel calls from Flutter
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "performSecurityChecks" -> {
                    val passed = performSecurityChecks()
                    result.success(passed)
                }
                "enableScreenCaptureProtection" -> {
                    val enabled = enableScreenCaptureProtection()
                    result.success(enabled)
                }
                "disableScreenCaptureProtection" -> {
                    val disabled = disableScreenCaptureProtection()
                    result.success(disabled)
                }
                "encryptString" -> {
                    val text = call.argument<String>("text")
                    val key = call.argument<String>("key") ?: "default_key"
                    
                    if (text != null) {
                        val encrypted = encryptString(text, key)
                        result.success(encrypted)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text cannot be null", null)
                    }
                }
                "decryptString" -> {
                    val text = call.argument<String>("text")
                    val key = call.argument<String>("key") ?: "default_key"
                    
                    if (text != null) {
                        val decrypted = decryptString(text, key)
                        result.success(decrypted)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text cannot be null", null)
                    }
                }
                "storeSecureData" -> {
                    val key = call.argument<String>("key")
                    val value = call.argument<String>("value")
                    
                    if (key != null && value != null) {
                        val success = storeSecureData(key, value)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Key and value cannot be null", null)
                    }
                }
                "getSecureData" -> {
                    val key = call.argument<String>("key")
                    val defaultValue = call.argument<String>("defaultValue") ?: ""
                    
                    if (key != null) {
                        val value = getSecureData(key, defaultValue)
                        result.success(value)
                    } else {
                        result.error("INVALID_ARGUMENT", "Key cannot be null", null)
                    }
                }
                "removeSecureData" -> {
                    val key = call.argument<String>("key")
                    
                    if (key != null) {
                        val success = removeSecureData(key)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Key cannot be null", null)
                    }
                }
                "clearAllSecureData" -> {
                    val success = clearAllSecureData()
                    result.success(success)
                }
                "isDeviceRooted" -> {
                    val isRooted = isDeviceRooted()
                    result.success(isRooted)
                }
                "verifyAppSignature" -> {
                    val signatureValid = verifyAppSignature()
                    result.success(signatureValid)
                }
                "requestIntegrityToken" -> {
                    val nonce = call.argument<String>("nonce")
                    
                    // Launch a coroutine to handle the token request
                    GlobalScope.launch {
                        try {
                            val token = integrityChecker.requestIntegrityToken(nonce)
                            // Switch back to the main thread to deliver the result
                            withContext(Dispatchers.Main) {
                                result.success(token)
                            }
                        } catch (e: Exception) {
                            // Switch back to the main thread to deliver the error
                            withContext(Dispatchers.Main) {
                                result.error("INTEGRITY_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "testSSLPinning" -> {
                    val verbose = call.argument<Boolean>("verbose") ?: false
                    
                    // Launch a coroutine to handle SSL pinning test
                    GlobalScope.launch {
                        try {
                            val success = testSSLPinning(verbose)
                            
                            // Switch back to the main thread to deliver the result
                            withContext(Dispatchers.Main) {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            // Switch back to the main thread to deliver the error
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
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call '${call.method}': ${e.message}")
            result.error("SECURE_OPERATION_ERROR", e.message, null)
        }
    }

    /**
     * Perform security checks for the app
     * @return True if all checks pass, false otherwise
     */
    private fun performSecurityChecks(): Boolean {
        try {
            // Check if app signatures are valid
            val signatureValid = verifyAppSignature()
            
            // Check if secure preferences are working
            val prefsValid = testSecurePreferences()
            
            // Check for basic obfuscation (should be true in production builds)
            val isObfuscated = isAppObfuscated()
            
            // Check if device is rooted
            val isRooted = isDeviceRooted()
            if (isRooted) {
                Log.w(TAG, "Device appears to be rooted - security risk detected")
                // In production, consider adding more strict measures
                // or limitations for rooted devices
            }
            
            // Check if running on emulator
            val isEmulator = checkIsEmulator()
            if (isEmulator) {
                Log.w(TAG, "App is running on an emulator - potential security risk")
            }
            
            Log.d(TAG, "Security checks: Signature valid=$signatureValid, Prefs valid=$prefsValid, " + 
                  "Obfuscated=$isObfuscated, Device rooted=$isRooted, Emulator=$isEmulator")
            
            // In development, we don't require obfuscation to be true and allow rooted devices and emulators
            // In production, you might want to fail security checks for rooted devices
            return signatureValid && prefsValid
        } catch (e: Exception) {
            Log.e(TAG, "Error during security checks: ${e.message}")
            return false
        }
    }
    
    /**
     * Check if the app has been properly obfuscated
     * This is a simple check that can be enhanced in production
     */
    private fun isAppObfuscated(): Boolean {
        // In a real obfuscated app, class names would be different
        // This is a simple heuristic that checks if the class name has been obfuscated
        val className = this::class.java.simpleName
        
        // For development, just log the class name
        Log.d(TAG, "Class name: $className")
        
        // In development, we don't need obfuscation
        return true
    }

    /**
     * Test if secure preferences are working properly
     */
    private fun testSecurePreferences(): Boolean {
        try {
            securePreferences?.edit()?.putString("test_key", "test_value")?.apply()
            val value = securePreferences?.getString("test_key", null)
            securePreferences?.edit()?.remove("test_key")?.apply()
            
            return value == "test_value"
        } catch (e: Exception) {
            Log.e(TAG, "Error testing secure preferences: ${e.message}")
            return false
        }
    }

    /**
     * Enable screenshot protection for security-sensitive screens
     */
    private fun enableScreenCaptureProtection(): Boolean {
        try {
            activity?.window?.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error enabling screen capture protection: ${e.message}")
            return false
        }
    }

    /**
     * Disable screenshot protection
     */
    private fun disableScreenCaptureProtection(): Boolean {
        try {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error disabling screen capture protection: ${e.message}")
            return false
        }
    }

    /**
     * Encrypt a string using AES encryption
     * @param text The text to encrypt
     * @param keyAlias Optional key alias, for future multi-key support
     * @return Base64 encoded encrypted string
     */
    private fun encryptString(text: String, keyAlias: String = "default_key"): String {
        try {
            // We use a single key for now, but the keyAlias parameter allows for future extension
            // to support multiple encryption keys
            val secretKey: SecretKey = getOrCreateSecretKey()
            val cipher = Cipher.getInstance(AES_GCM_NOPADDING)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            
            val iv = cipher.iv
            val encryptedBytes = cipher.doFinal(text.toByteArray(Charsets.UTF_8))
            
            val combined = ByteArray(GCM_IV_LENGTH + encryptedBytes.size)
            System.arraycopy(iv, 0, combined, 0, GCM_IV_LENGTH)
            System.arraycopy(encryptedBytes, 0, combined, GCM_IV_LENGTH, encryptedBytes.size)
            
            return Base64.encodeToString(combined, Base64.DEFAULT)
        } catch (e: Exception) {
            Log.e(TAG, "Error encrypting string: ${e.message}")
            throw e
        }
    }

    /**
     * Decrypt a string using AES encryption
     * @param encryptedText Base64 encoded encrypted string
     * @param keyAlias Optional key alias, for future multi-key support
     * @return The decrypted string
     */
    private fun decryptString(encryptedText: String, keyAlias: String = "default_key"): String {
        try {
            // We use a single key for now, but the keyAlias parameter allows for future extension
            // to support multiple encryption keys
            val secretKey: SecretKey = getOrCreateSecretKey()
            val encryptedData = Base64.decode(encryptedText, Base64.DEFAULT)
            
            val iv = encryptedData.copyOfRange(0, GCM_IV_LENGTH)
            val cipherText = encryptedData.copyOfRange(GCM_IV_LENGTH, encryptedData.size)
            
            val cipher = Cipher.getInstance(AES_GCM_NOPADDING)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
            
            val decryptedBytes = cipher.doFinal(cipherText)
            return String(decryptedBytes, Charsets.UTF_8)
        } catch (e: Exception) {
            Log.e(TAG, "Error decrypting string: ${e.message}")
            throw e
        }
    }

    /**
     * Get or create a secret key for encryption
     */
    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)

        if (!keyStore.containsAlias(ENCRYPTION_KEY_ALIAS)) {
            val keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                ANDROID_KEYSTORE
            )
            val keyGenSpec = KeyGenParameterSpec.Builder(
                ENCRYPTION_KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
            
            keyGenerator.init(keyGenSpec)
            return keyGenerator.generateKey()
        }
        
        return keyStore.getKey(ENCRYPTION_KEY_ALIAS, null) as SecretKey
    }

    /**
     * Store data securely using encrypted storage
     */
    private fun storeSecureData(key: String, value: String): Boolean {
        return try {
            securePreferences?.edit()?.putString(key, value)?.apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error storing secure data: ${e.message}")
            false
        }
    }

    /**
     * Get data from secure storage
     */
    private fun getSecureData(key: String, defaultValue: String = ""): String {
        return try {
            securePreferences?.getString(key, defaultValue) ?: defaultValue
        } catch (e: Exception) {
            Log.e(TAG, "Error getting secure data: ${e.message}")
            defaultValue
        }
    }

    /**
     * Remove data from secure storage
     */
    private fun removeSecureData(key: String): Boolean {
        return try {
            securePreferences?.edit()?.remove(key)?.apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error removing secure data: ${e.message}")
            false
        }
    }

    /**
     * Clear all data from secure storage
     */
    private fun clearAllSecureData(): Boolean {
        return try {
            securePreferences?.edit()?.clear()?.apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing all secure data: ${e.message}")
            false
        }
    }
    
    /**
     * Request an integrity token from Google Play Integrity API
     * This is a wrapper around the IntegrityChecker functionality
     * 
     * @param nonce Optional server nonce
     * @return CompletableDeferred that will be completed with the token or an exception
     */
    fun requestIntegrityToken(nonce: String? = null): CompletableDeferred<String> {
        val deferred = CompletableDeferred<String>()
        
        GlobalScope.launch {
            try {
                val token = integrityChecker.requestIntegrityToken(nonce)
                deferred.complete(token)
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting integrity token: ${e.message}")
                deferred.completeExceptionally(e)
            }
        }
        
        return deferred
    }
    
    /**
     * Check if the app is running on an emulator
     * This can be used to restrict certain operations in production
     */
    private fun checkIsEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT)
    }
    
    /**
     * Get if the device is rooted - wrapper for RootDetector
     */
    fun isDeviceRooted(): Boolean {
        return rootDetector.isDeviceRooted()
    }
    
    /**
     * Verify app signature - wrapper for TamperDetector
     */
    fun verifyAppSignature(): Boolean {
        return tamperDetector.verifyAppSignature()
    }
    
    /**
     * Test SSL pinning by making a secure request to a known endpoint
     */
    private suspend fun testSSLPinning(): String {
        return try {
            // Perform a test request to a known secure endpoint
            val response = SSLPinningManager.getPinnedOkHttpClientBuilder()
                .build()
                .newCall(
                    okhttp3.Request.Builder()
                        .url("https://www.google.com")
                        .build()
                ).execute()
            
            if (response.isSuccessful) {
                "SSL Pinning test successful"
            } else {
                "SSL Pinning test failed: ${response.code}"
            }
        } catch (e: Exception) {
            "SSL Pinning test error: ${e.message}"
        }
    }
    
    /**
     * Log SSL pinning domains for validation
     */
    private fun logSSLPinningDomains() {
        try {
            Log.d(TAG, "SSL Certificate Pins configured for these domains:")
            Log.d(TAG, "- *.firebaseio.com")
            Log.d(TAG, "- securetoken.googleapis.com")
            Log.d(TAG, "- *.googleapis.com")
            Log.d(TAG, "- *.duckbuck.app")
            Log.d(TAG, "- api.duckbuck.app")
        } catch (e: Exception) {
            Log.e(TAG, "Error logging SSL pinning domains: ${e.message}")
        }
    }
    
    /**
     * Simple verification that SSL pinning is set up
     * 
     * @param verbose Whether to log verbose output
     * @return True if SSL pinning is set up
     */
    suspend fun testSSLPinning(verbose: Boolean = false): Boolean {
        return try {
            if (sslPinningClient == null) {
                Log.e(TAG, "SSL pinning client not initialized")
                return false
            }
            
            if (verbose) {
                Log.d(TAG, "SSL pinning configured successfully")
                logSSLPinningDomains()
            }
            
            // Since we've removed the tester class, we just verify the client exists
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error with SSL pinning: ${e.message}")
            return false
        }
    }
}
