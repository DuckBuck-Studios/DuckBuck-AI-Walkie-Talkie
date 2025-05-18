package com.duckbuck.app.security

import android.os.Build
import java.io.File
import java.io.BufferedReader
import java.io.InputStreamReader
import android.util.Log

/**
 * RootDetector checks if the device is rooted (has superuser access)
 * Running on a rooted device may compromise app security
 */
class RootDetector {
    private val tag = "RootDetector"
    
    /**
     * Check if the device is likely rooted
     * @return true if the device shows signs of being rooted
     */
    fun isDeviceRooted(): Boolean {
        return checkRootMethod1() || checkRootMethod2() || checkRootMethod3()
    }
    
    /**
     * Check for common root-related files
     */
    private fun checkRootMethod1(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/system/bin/su",
            "/sbin/su",
            "/system/su",
            "/system/bin/.ext/.su",
            "/system/xbin/.ext/.su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        
        for (path in paths) {
            if (File(path).exists()) {
                Log.d(tag, "Root file found: $path")
                return true
            }
        }
        
        return false
    }
    
    /**
     * Check for packages commonly installed on rooted devices
     */
    private fun checkRootMethod2(): Boolean {
        val commands = arrayOf(
            "which su",
            "busybox ls",
            "ps | grep magisk"
        )
        
        for (command in commands) {
            try {
                val process = Runtime.getRuntime().exec(command)
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val line = reader.readLine()
                
                if (line != null) {
                    Log.d(tag, "Root command succeeded: $command")
                    return true
                }
            } catch (e: Exception) {
                // Command failed, which is expected on non-rooted devices
            }
        }
        
        return false
    }
    
    /**
     * Check for build tags that indicate development/test builds
     */
    private fun checkRootMethod3(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            Log.d(tag, "Test keys detected in build")
            return true
        }
        
        return false
    }
}
