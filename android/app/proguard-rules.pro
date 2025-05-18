# Basic ProGuard rules for Flutter Android apps
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes SourceFile,LineNumberTable        # Keep file names and line numbers
-keepattributes EnclosingMethod                   # Keep method context
-keepattributes Exceptions                        # Keep exceptions

# General Android configuration
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends androidx.fragment.app.Fragment
-keep public class * extends android.view.View

# Keep Google Play Services and Firebase packages
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.android.gms.internal.**

# Keep Play Integrity classes
-keep class com.google.android.play.core.integrity.** { *; }

# Keep OkHttp and Security-related classes
-keepnames class okhttp3.** { *; }
-keepnames class okio.** { *; }
-keep class androidx.security.crypto.** { *; }

# Keep our security package from being obfuscated too much
-keep class com.duckbuck.app.security.SSLPinningManager { *; }
-keepclassmembers class com.duckbuck.app.security.** {
    public static ** Companion;
    public <fields>;
}

# Enhanced obfuscation
-repackageclasses 'com.duckbuck.app.obf'
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-optimizationpasses 5

# Encrypt string constants
-encryptstrings class com.duckbuck.app.security.**
-encryptstrings com.duckbuck.app.security.SecurityManager

# Additional Security Protections
-keep class javax.crypto.** { *; }
-keep class javax.security.** { *; }
-keep class java.security.** { *; }
-keep class androidx.biometric.** { *; }

# Special handling for sensitive info
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}

# Don't print notes about classes that might be unreachable
-dontnote com.google.**
-dontnote android.support.v4.**
-dontnote androidx.**

# Flutter support
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep methods that contain native code
-keepclasseswithmembernames class * {
    native <methods>;
}
