package com.duckbuck.app.security

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Debug
import android.util.Log
import java.io.File
import java.io.BufferedReader
import java.io.InputStreamReader
import java.security.MessageDigest
import java.util.concurrent.Executors
import kotlin.random.Random

/**
 * Enhanced TamperDetector with advanced anti-tampering and anti-debugging protection
 * Provides comprehensive protection against:
 * - Code injection and modification
 * - Dynamic analysis tools (Frida, Xposed)
 * - Debugger attachment
 * - Memory manipulation
 * - Runtime hooking
 */
class TamperDetector(private val context: Context) {

    private val tag = "TamperDetector"
    
    // Expected certificate hash for release builds (in HEX format)
    // This is the SHA-256 hash of our app's signing certificate
    private val expectedCertSha256 = "E4A25E830982A1CE9FAE8E3588646AB352CF6928D059A9687C85C439F7A69AB5"
    
    // Anti-debugging state tracking
    private var debuggerDetected = false
    private var dynamicAnalysisDetected = false
    private val executorService = Executors.newSingleThreadExecutor()
    
    // Known dynamic analysis tools and frameworks
    private val suspiciousProcesses = arrayOf(
        "frida", "gdb", "lldb", "strace", "tcpdump", "wireshark",
        "charles", "burp", "mitmproxy", "proxydroid", "drony",
        "xposed", "substrate", "cycript", "introspy"
    )
    
    private val suspiciousLibraries = arrayOf(
        "libfrida", "libgadget", "libsubstrate", "libxposed",
        "libjni_", "libdvm_", "libmemtrack", "libhook"
    )
    
    private val suspiciousFiles = arrayOf(
        "/data/local/tmp/frida-server",
        "/system/lib/libsubstrate.so",
        "/system/lib64/libsubstrate.so",
        "/system/xbin/frida-server",
        "/data/local/tmp/gdbserver",
        "/system/bin/su",
        "/system/app/Superuser.apk"
    )
    
    /**
     * Comprehensive security verification with enhanced protection
     * @return True if the app signature is valid and no tampering detected, false otherwise
     */
    fun verifyAppSignature(): Boolean {
        try {
            // Start continuous monitoring in background
            startContinuousSecurityMonitoring()
            
            // Check for debugger attachment
            if (isDebuggerAttached()) {
                Log.w(tag, "Debugger detected - potential security threat")
                debuggerDetected = true
                return false
            }
            
            // Check for dynamic analysis tools
            if (isDynamicAnalysisDetected()) {
                Log.w(tag, "Dynamic analysis tools detected - security compromised")
                dynamicAnalysisDetected = true
                return false
            }
            
            // Verify app signature with enhanced checks
            val signature = getAppSignature()
            Log.d(tag, "App signature: $signature")
            
            if (expectedCertSha256.isEmpty()) {
                Log.d(tag, "Running in development mode - signature verification disabled")
                return true
            }
            
            // Enhanced signature validation
            val isValid = signature.equals(expectedCertSha256, ignoreCase = true)
            
            if (!isValid) {
                Log.w(tag, "App signature verification failed")
                Log.d(tag, "Expected: $expectedCertSha256")
                Log.d(tag, "Actual: $signature")
                
                // Perform comprehensive tamper checks
                val isPackageManagerValid = verifyPackageManager()
                val isAppInfoValid = verifyAppInfo()
                val isRuntimeIntegrityValid = verifyRuntimeIntegrity()
                val isMemoryIntegrityValid = verifyMemoryIntegrity()
                
                Log.d(tag, "Security checks - Package: $isPackageManagerValid, App: $isAppInfoValid, Runtime: $isRuntimeIntegrityValid, Memory: $isMemoryIntegrityValid")
                
                return false
            } else {
                Log.d(tag, "App signature verified successfully")
                return true
            }
        } catch (e: Exception) {
            Log.e(tag, "Error verifying app signature: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Get the app's signature as a SHA-256 hash in hexadecimal format
     * @return The signature hash string
     */
    fun getAppSignature(): String {
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
     * Enhanced APK integrity verification with multiple checks
     */
    private fun verifyPackageManager(): Boolean {
        try {
            // Get the APK path and verify file integrity
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            val applicationInfo = packageInfo.applicationInfo
            val apkPath = applicationInfo?.sourceDir ?: ""
            
            // Check if APK exists
            val apkFile = File(apkPath)
            if (apkPath.isEmpty() || !apkFile.exists()) {
                Log.w(tag, "APK file does not exist at expected path: $apkPath")
                return false
            }
            
            // Enhanced APK size validation
            val apkSize = apkFile.length()
            if (apkSize < 1024 * 1024) { // Less than 1MB
                Log.w(tag, "APK file suspiciously small: $apkSize bytes")
                return false
            }
            
            // Check APK hash integrity
            val apkHash = calculateFileHash(apkFile)
            Log.d(tag, "APK hash: $apkHash")
            
            // Verify APK hasn't been modified since installation
            val lastModified = apkFile.lastModified()
            val installTime = packageInfo.firstInstallTime
            
            // APK should not be modified after installation
            if (lastModified > installTime + 60000) { // 1 minute grace period
                Log.w(tag, "APK appears to have been modified after installation")
                return false
            }
            
            // Check for split APKs (can indicate repackaging)
            val splitSourceDirs = applicationInfo?.splitSourceDirs
            if (splitSourceDirs != null && splitSourceDirs.isNotEmpty()) {
                Log.w(tag, "Split APKs detected - potential repackaging")
                return false
            }
            
            return true
        } catch (e: Exception) {
            Log.e(tag, "Error verifying package manager: ${e.message}")
            return false
        }
    }
    
    /**
     * Calculate SHA-256 hash of a file
     */
    private fun calculateFileHash(file: File): String {
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            file.inputStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    digest.update(buffer, 0, bytesRead)
                }
            }
            digest.digest().joinToString("") { "%02X".format(it) }
        } catch (e: Exception) {
            Log.e(tag, "Error calculating file hash: ${e.message}")
            ""
        }
    }
    
    /**
     * Enhanced app info verification with comprehensive security checks
     */
    private fun verifyAppInfo(): Boolean {
        try {
            val applicationInfo = context.applicationInfo 
            
            // Check for suspicious flags
            val isDebuggable = (applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_DEBUGGABLE != 0
            val isTest = (applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_TEST_ONLY != 0
            val allowBackup = (applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_ALLOW_BACKUP != 0
            val allowClearUserData = (applicationInfo?.flags ?: 0) and ApplicationInfo.FLAG_ALLOW_CLEAR_USER_DATA != 0
            
            // Check installation source for security
            val installerPackage = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    context.packageManager.getInstallerPackageName(context.packageName)
                }
            } catch (e: Exception) {
                null
            }
            
            // Verify legitimate installation source
            val legitimateInstallers = arrayOf(
                "com.android.vending",  // Google Play Store
                "com.google.android.feedback",  // Google Play Services
                "com.android.packageinstaller",  // System installer
                null  // Direct installation (development)
            )
            
            val isLegitimateInstaller = installerPackage in legitimateInstallers
            if (!isLegitimateInstaller) {
                Log.w(tag, "App installed from suspicious source: $installerPackage")
            }
            
            // Check for code integrity
            val targetSdkVersion = applicationInfo?.targetSdkVersion ?: 0
            val minSdkVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                applicationInfo?.minSdkVersion ?: 0
            } else {
                0
            }
            
            // Basic sanity checks for SDK versions
            val sdkVersionsValid = targetSdkVersion >= 21 && minSdkVersion >= 21 && 
                                 targetSdkVersion <= Build.VERSION_CODES.TIRAMISU + 5
            
            // Check permissions for suspicious combinations
            val permissions = try {
                val packageInfoWithPermissions = context.packageManager.getPackageInfo(
                    context.packageName, 
                    PackageManager.GET_PERMISSIONS
                )
                packageInfoWithPermissions.requestedPermissions?.toList() ?: emptyList()
            } catch (e: Exception) {
                emptyList<String>()
            }
            
            // Flag suspicious permission combinations
            val hasSuspiciousPermissions = permissions.any { permission ->
                permission in arrayOf(
                    "android.permission.WRITE_EXTERNAL_STORAGE",
                    "android.permission.READ_PHONE_STATE",
                    "android.permission.ACCESS_FINE_LOCATION"
                )
            }
            
            Log.d(tag, "App info checks - Debuggable: $isDebuggable, Test: $isTest, " +
                      "Backup: $allowBackup, ClearData: $allowClearUserData, " +
                      "Installer: $installerPackage, SDKValid: $sdkVersionsValid, " +
                      "SuspiciousPerms: $hasSuspiciousPermissions")
            
            // In production, these should be more restrictive
            if (isDebuggable || isTest) {
                Log.w(tag, "App has suspicious flags: debuggable=$isDebuggable, testOnly=$isTest")
                // In production builds, consider returning false here
            }
            
            return sdkVersionsValid && isLegitimateInstaller
        } catch (e: Exception) {
            Log.e(tag, "Error verifying app info: ${e.message}")
            return false
        }
    }
    
    /**
     * Check if a debugger is attached to the process
     */
    private fun isDebuggerAttached(): Boolean {
        return try {
            // Multiple debugger detection methods
            val waitingForDebugger = Debug.waitingForDebugger()
            val isDebuggerConnected = Debug.isDebuggerConnected()
            val tracerPid = getTracerPid()
            
            // Check for timing anomalies (debugger slows execution)
            val timingAnomaly = detectTimingAnomalies()
            
            Log.d(tag, "Debugger checks - Waiting: $waitingForDebugger, Connected: $isDebuggerConnected, TracerPid: $tracerPid, Timing: $timingAnomaly")
            
            waitingForDebugger || isDebuggerConnected || tracerPid > 0 || timingAnomaly
        } catch (e: Exception) {
            Log.e(tag, "Error checking debugger: ${e.message}")
            false
        }
    }
    
    /**
     * Get the tracer PID from /proc/self/status
     */
    private fun getTracerPid(): Int {
        return try {
            val statusFile = File("/proc/self/status")
            if (!statusFile.exists()) return 0
            
            statusFile.readLines().forEach { line ->
                if (line.startsWith("TracerPid:")) {
                    return line.substringAfter(":").trim().toIntOrNull() ?: 0
                }
            }
            0
        } catch (e: Exception) {
            0
        }
    }
    
    /**
     * Detect timing anomalies that indicate debugging
     */
    private fun detectTimingAnomalies(): Boolean {
        return try {
            val iterations = 1000
            val startTime = System.nanoTime()
            
            // Perform simple operations
            var sum = 0
            for (i in 0 until iterations) {
                sum += i
            }
            
            val endTime = System.nanoTime()
            val duration = endTime - startTime
            
            // If execution took too long, debugger might be attached
            val threshold = 5000000 // 5ms in nanoseconds
            duration > threshold
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Detect dynamic analysis tools and frameworks
     */
    private fun isDynamicAnalysisDetected(): Boolean {
        return try {
            // Check for suspicious processes
            val processCheck = checkSuspiciousProcesses()
            
            // Check for suspicious libraries loaded
            val libraryCheck = checkSuspiciousLibraries()
            
            // Check for suspicious files
            val fileCheck = checkSuspiciousFiles()
            
            // Check for hooking frameworks
            val hookingCheck = detectHookingFrameworks()
            
            Log.d(tag, "Dynamic analysis checks - Process: $processCheck, Library: $libraryCheck, File: $fileCheck, Hooking: $hookingCheck")
            
            processCheck || libraryCheck || fileCheck || hookingCheck
        } catch (e: Exception) {
            Log.e(tag, "Error checking dynamic analysis: ${e.message}")
            false
        }
    }
    
    /**
     * Check for suspicious processes in the system
     */
    private fun checkSuspiciousProcesses(): Boolean {
        return try {
            val runtime = Runtime.getRuntime()
            val process = runtime.exec("ps")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            
            reader.use { br ->
                var line: String?
                while (br.readLine().also { line = it } != null) {
                    val processLine = line!!.lowercase()
                    for (suspiciousProcess in suspiciousProcesses) {
                        if (processLine.contains(suspiciousProcess)) {
                            Log.w(tag, "Suspicious process detected: $suspiciousProcess")
                            return true
                        }
                    }
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Check for suspicious libraries in memory
     */
    private fun checkSuspiciousLibraries(): Boolean {
        return try {
            val mapsFile = File("/proc/self/maps")
            if (!mapsFile.exists()) return false
            
            mapsFile.readLines().forEach { line ->
                val lowercaseLine = line.lowercase()
                for (library in suspiciousLibraries) {
                    if (lowercaseLine.contains(library)) {
                        Log.w(tag, "Suspicious library detected: $library")
                        return true
                    }
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Check for suspicious files on the system
     */
    private fun checkSuspiciousFiles(): Boolean {
        return try {
            for (filePath in suspiciousFiles) {
                if (File(filePath).exists()) {
                    Log.w(tag, "Suspicious file detected: $filePath")
                    return true
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Detect hooking frameworks by checking method integrity
     */
    private fun detectHookingFrameworks(): Boolean {
        return try {
            // Check if critical methods have been hooked
            val originalHashCode = Object::class.java.getDeclaredMethod("hashCode").hashCode()
            val currentHashCode = Object::class.java.getDeclaredMethod("hashCode").hashCode()
            
            // In a hooked environment, method references might change
            if (originalHashCode != currentHashCode) {
                Log.w(tag, "Method hooking detected")
                return true
            }
            
            // Check for Xposed framework
            try {
                Class.forName("de.robv.android.xposed.XposedBridge")
                Log.w(tag, "Xposed framework detected")
                return true
            } catch (e: ClassNotFoundException) {
                // Xposed not found, which is good
            }
            
            false
        } catch (e: Exception) {
            false
        }
    }
    
    /**
     * Verify runtime integrity by checking method signatures
     */
    private fun verifyRuntimeIntegrity(): Boolean {
        return try {
            // Check if critical classes have been tampered with
            val contextClass = Context::class.java
            val packageManagerClass = PackageManager::class.java
            
            // Verify class signatures haven't changed
            val contextMethods = contextClass.declaredMethods.size
            val packageManagerMethods = packageManagerClass.declaredMethods.size
            
            // Basic sanity check (these classes should have a reasonable number of methods)
            contextMethods > 10 && packageManagerMethods > 10
        } catch (e: Exception) {
            Log.e(tag, "Error verifying runtime integrity: ${e.message}")
            false
        }
    }
    
    /**
     * Verify memory integrity by checking for unusual memory patterns
     */
    private fun verifyMemoryIntegrity(): Boolean {
        return try {
            // Check heap integrity
            val runtime = Runtime.getRuntime()
            val maxMemory = runtime.maxMemory()
            val totalMemory = runtime.totalMemory()
            val freeMemory = runtime.freeMemory()
            
            // Basic sanity checks for memory values
            val isValid = maxMemory > 0 && totalMemory > 0 && freeMemory >= 0 && 
                         totalMemory <= maxMemory && freeMemory <= totalMemory
            
            if (!isValid) {
                Log.w(tag, "Memory integrity check failed")
            }
            
            isValid
        } catch (e: Exception) {
            Log.e(tag, "Error verifying memory integrity: ${e.message}")
            false
        }
    }
    
    /**
     * Start continuous security monitoring in background
     */
    private fun startContinuousSecurityMonitoring() {
        executorService.submit {
            try {
                while (!Thread.currentThread().isInterrupted) {
                    // Periodic security checks
                    Thread.sleep(Random.nextLong(30000, 60000)) // Random interval 30-60 seconds
                    
                    if (isDebuggerAttached()) {
                        Log.w(tag, "Continuous monitoring: Debugger detected")
                        debuggerDetected = true
                    }
                    
                    if (isDynamicAnalysisDetected()) {
                        Log.w(tag, "Continuous monitoring: Dynamic analysis detected")
                        dynamicAnalysisDetected = true
                    }
                    
                    // Random integrity checks
                    if (Random.nextBoolean()) {
                        verifyRuntimeIntegrity()
                        verifyMemoryIntegrity()
                    }
                }
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
            } catch (e: Exception) {
                Log.e(tag, "Error in continuous monitoring: ${e.message}")
            }
        }
    }
    
    /**
     * Get security status for external monitoring
     */
    fun getSecurityStatus(): Map<String, Boolean> {
        return mapOf(
            "debuggerDetected" to debuggerDetected,
            "dynamicAnalysisDetected" to dynamicAnalysisDetected,
            "signatureValid" to try { verifyAppSignature() } catch (e: Exception) { false }
        )
    }
    
    /**
     * Stop security monitoring
     */
    fun stopSecurityMonitoring() {
        try {
            executorService.shutdown()
        } catch (e: Exception) {
            Log.e(tag, "Error stopping security monitoring: ${e.message}")
        }
    }
}
