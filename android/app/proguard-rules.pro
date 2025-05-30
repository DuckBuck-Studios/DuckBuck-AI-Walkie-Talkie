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

# Enhanced obfuscation
-repackageclasses 'com.duckbuck.app.obf'
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-optimizationpasses 5

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
 