package com.duckbuck.app.security

import android.util.Log
import okhttp3.CertificatePinner
import okhttp3.OkHttpClient
import java.security.MessageDigest
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * SSLPinningManager handles certificate pinning for secure API communication.
 * It pins the public key of trusted certificates to prevent man-in-the-middle attacks.
 */
class SSLPinningManager {

    companion object {
        private const val TAG = "SSLPinningManager"
        
        // Certificate pins for different domains
        // Format: "sha256/Base64-encoded-SHA-256-hash"
        private val certificatePins = mapOf(
            // Replace with your actual pins in production
            // For Firebase domains
            "*.firebaseio.com" to listOf(
                "sha256/jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=",
                // Secondary pin for backup/rotation
                "sha256/s//bfYjzukDDZIABJmDLkKFYbMiQK0YKhp+FKw6++1I="
            ),
            // Firebase auth domain
            "securetoken.googleapis.com" to listOf(
                "sha256/5ya9kbP0AWelymASCjOV+tzpBm7ItAOTzsR5kaQQKY8=",
                // Keep the previous pin during certificate rotation period
                "sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc="
            ),
            // Google APIs
            "*.googleapis.com" to listOf(
                "sha256/5ya9kbP0AWelymASCjOV+tzpBm7ItAOTzsR5kaQQKY8=",
                "sha256/hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc="
            ),
            // Your app backend
            "*.duckbuck.app" to listOf(
                "sha256/sjZer4YplCna656qXVu42TwFohQlOd0xQW9OBAiRCUE=",
                // Keep previous pin during rotation period
                "sha256/fWBpm3/2BeN6bTTgRwAV7J3ckbAA0azsm0BUmACMumo="
            ),
            // Specific API endpoint
            "api.duckbuck.app" to listOf(
                "sha256/fWBpm3/2BeN6bTTgRwAV7J3ckbAA0azsm0BUmACMumo="
            )
        )
        
        /**
         * Create an OkHttpClient.Builder with certificate pinning
         */
        fun getPinnedOkHttpClientBuilder(): OkHttpClient.Builder {
            val builder = OkHttpClient.Builder()
            val certificatePinner = CertificatePinner.Builder()
            
            // Add all pins to the certificate pinner
            certificatePins.forEach { (domain, pins) ->
                pins.forEach { pin ->
                    certificatePinner.add(domain, pin)
                }
            }
            
            // Add security enhancements
            return builder
                .certificatePinner(certificatePinner.build())
                .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                .followRedirects(true)
                .followSslRedirects(true)
        }
        
        /**
         * Create a dev OkHttpClient for development use - allows local testing but logs warnings
         * IMPORTANT: This should ONLY be used during development, never in production
         */
        fun getDevOkHttpClient(): OkHttpClient {
            try {
                // Log a warning that we're using a less secure client for development
                Log.w(TAG, "⚠️ Using development OkHttpClient - DO NOT USE IN PRODUCTION")
                
                // Create a trust manager that does not validate certificate chains but logs details
                // WARNING: This should ONLY be used in DEBUG builds
                val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {
                        Log.d(TAG, "Client cert check bypassed in dev mode")
                    }
                    
                    override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                        // Log certificate info for debugging
                        Log.d(TAG, "Server cert chain length: ${chain.size}")
                        chain.forEachIndexed { index, cert ->
                            Log.d(TAG, "Cert[$index]: ${cert.subjectDN}")
                            Log.d(TAG, "Issuer: ${cert.issuerDN}")
                            Log.d(TAG, "Serial: ${cert.serialNumber}")
                            Log.d(TAG, "Valid from: ${cert.notBefore} to ${cert.notAfter}")
                        }
                    }
                    
                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                })
                
                // Install the all-trusting trust manager
                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, trustAllCerts, java.security.SecureRandom())
                
                // Create an ssl socket factory with our all-trusting manager
                val sslSocketFactory = sslContext.socketFactory
                
                return OkHttpClient.Builder()
                    .sslSocketFactory(sslSocketFactory, trustAllCerts[0] as X509TrustManager)
                    .hostnameVerifier { hostname: String, _ -> 
                        Log.d(TAG, "Hostname verification bypassed for: $hostname")
                        true 
                    }
                    .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                    .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                    .writeTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
                    .build()
            } catch (e: Exception) {
                Log.e(TAG, "Error creating dev OkHttpClient: ${e.message}")
                throw e
            }
        }
        
        /**
         * Validate if a certificate's public key hash matches any of our pins
         * This can be used for additional validation beyond OkHttp's built-in pinning
         * 
         * @param certificate The X509Certificate to validate
         * @param hostname The hostname this certificate should be valid for
         * @return true if the certificate matches our pins, false otherwise
         */
        fun validateCertificatePin(certificate: X509Certificate, hostname: String): Boolean {
            try {
                // Extract the public key hash
                val publicKey = certificate.publicKey.encoded
                val md = MessageDigest.getInstance("SHA-256")
                val digest = md.digest(publicKey)
                val pin = android.util.Base64.encodeToString(digest, android.util.Base64.NO_WRAP)
                
                // Find matching pins for the hostname
                val matchingPins = certificatePins.entries.filter { (domain, _) -> 
                    // Match exact domain or wildcard domains
                    domain == hostname || 
                    (domain.startsWith("*.") && hostname.endsWith(domain.substring(1)))
                }.flatMap { it.value }
                
                // Get just the hash part from our pins (remove "sha256/")
                val expectedHashes = matchingPins.map { it.substring(7) }
                
                // Check if our computed hash matches any of the expected hashes
                val isValid = expectedHashes.contains(pin)
                
                if (isValid) {
                    Log.d(TAG, "Certificate validation successful for $hostname")
                } else {
                    Log.e(TAG, "Certificate validation FAILED for $hostname")
                    Log.e(TAG, "Got: sha256/$pin")
                    Log.e(TAG, "Expected one of: $expectedHashes")
                }
                
                return isValid
            } catch (e: Exception) {
                Log.e(TAG, "Error validating certificate: ${e.message}")
                return false
            }
        }
    }
}
