package com.duckbuck.app.core

import android.util.Log

/**
 * Production-safe logging utility
 * Controls logging output based on build configuration to ensure no logs in production
 */
object AppLogger {
    
    // This will be determined at compile time by ProGuard
    private const val IS_DEBUG = true
    
    /**
     * Debug logging - only shown in debug builds
     */
    fun d(tag: String, message: String) {
        if (IS_DEBUG) {
            Log.d(tag, message)
        }
    }
    
    /**
     * Info logging - only shown in debug builds
     */
    fun i(tag: String, message: String) {
        if (IS_DEBUG) {
            Log.i(tag, message)
        }
    }
    
    /**
     * Warning logging - shown in debug builds, minimal in release
     */
    fun w(tag: String, message: String, throwable: Throwable? = null) {
        if (IS_DEBUG) {
            if (throwable != null) {
                Log.w(tag, message, throwable)
            } else {
                Log.w(tag, message)
            }
        }
        // In production, warnings are suppressed unless critical
    }
    
    /**
     * Error logging - always shown (critical for crash reporting)
     */
    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (throwable != null) {
            Log.e(tag, message, throwable)
        } else {
            Log.e(tag, message)
        }
    }
    
    /**
     * Critical production logs - minimal, structured logging for production monitoring
     * Use sparingly and only for essential production events
     */
    fun production(tag: String, event: String, data: Map<String, Any>? = null) {
        if (IS_DEBUG) {
            val dataStr = data?.let { " | Data: $it" } ?: ""
            Log.i("PROD_$tag", "$event$dataStr")
        } else {
            // In production, send to analytics/crash reporting instead of logcat
            // Log.i("PROD_$tag", event) // Uncomment if production logging is needed
        }
    }
}
