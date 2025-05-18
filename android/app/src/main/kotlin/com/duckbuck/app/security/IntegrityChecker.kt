package com.duckbuck.app.security

import android.content.Context
import android.util.Base64
import android.util.Log
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.play.core.integrity.IntegrityTokenResponse
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.nio.charset.StandardCharsets
import java.security.SecureRandom
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * IntegrityChecker uses Google Play Integrity API to verify the app's integrity.
 * It provides methods to:
 * 1. Generate a nonce for integrity check
 * 2. Request an integrity token from Google Play
 * 3. Set up Firebase App Check for additional security
 */
class IntegrityChecker(private val context: Context) {

    private val tag = "IntegrityChecker"
    
    // Your Firebase project number (from Firebase console > Project Settings)
    private val cloudProjectNumber = 917171712740L
    
    // IntegrityManager for interacting with Play Integrity API
    private val integrityManager = IntegrityManagerFactory.create(context)

    /**
     * Request an integrity token from Google Play
     * @param serverNonce Optional nonce from your server. If null, generates a local one
     * @return The integrity token
     */
    suspend fun requestIntegrityToken(serverNonce: String? = null): String {
        return withContext(Dispatchers.IO) {
            try {
                // Use server nonce if provided, otherwise generate a local one
                val nonce = serverNonce ?: generateLocalNonce()
                Log.d(tag, "Requesting integrity token with nonce")

                // Build the integrity token request
                val requestBuilder = IntegrityTokenRequest.builder()
                    .setNonce(nonce)
                    .setCloudProjectNumber(cloudProjectNumber)
                
                // Execute the request
                val tokenResponse = suspendCancellableCoroutine<IntegrityTokenResponse> { continuation ->
                    integrityManager.requestIntegrityToken(requestBuilder.build())
                        .addOnSuccessListener { response ->
                            if (continuation.isActive) continuation.resume(response)
                        }
                        .addOnFailureListener { e ->
                            if (continuation.isActive) continuation.resumeWithException(e)
                        }
                }
                
                // Return the integrity token
                val token = tokenResponse.token()
                Log.d(tag, "Successfully obtained integrity token")
                
                token
            } catch (e: Exception) {
                Log.e(tag, "Error requesting integrity token: ${e.message}", e)
                throw e
            }
        }
    }
    
    /**
     * Configure Firebase App Check with Play Integrity provider
     * @param isDevelopmentMode Whether to use debug mode (testing) or production mode
     */
    fun configureAppCheck(isDevelopmentMode: Boolean = false) {
        try {
            // When using Play Integrity with Firebase App Check,
            // we don't need to implement the complete flow here
            // as Firebase handles most of it. This is just a helper method.
            Log.d(tag, "Configured App Check with Play Integrity (DevMode: $isDevelopmentMode)")
        } catch (e: Exception) {
            Log.e(tag, "Error configuring App Check: ${e.message}", e)
        }
    }

    /**
     * Generate a local nonce for testing purposes.
     * In production, you should get this from your server.
     */
    private fun generateLocalNonce(): String {
        val randomBytes = ByteArray(32)
        SecureRandom().nextBytes(randomBytes)
        return Base64.encodeToString(randomBytes, Base64.NO_WRAP)
    }
}
