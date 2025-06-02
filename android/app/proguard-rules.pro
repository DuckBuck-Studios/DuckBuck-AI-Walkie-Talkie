# DuckBuck ProGuard Rules for Production Builds
# Ensures complete removal of logging code and other debug elements

# Remove all logging statements completely in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Remove AppLogger calls in release builds (our custom logger)
-assumenosideeffects class com.duckbuck.app.core.AppLogger {
    public static void d(...);
    public static void i(...);
    public static void w(...);
    public static void production(...);
}

# Keep AppLogger.e for crash reporting
-keep class com.duckbuck.app.core.AppLogger {
    public static void e(...);
}

# Keep Firebase Crashlytics for production error reporting
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.analytics.** { *; }

# Keep Agora SDK classes
-keep class io.agora.rtc.** { *; }
-keep class io.agora.base.** { *; }

# Keep Flutter related classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep FCM classes
-keep class com.google.firebase.messaging.** { *; }

# Keep model classes (data classes)
-keep class com.duckbuck.app.fcm.FcmDataHandler$CallData { *; }
-keep class com.duckbuck.app.callstate.** { *; }

# Remove debug/test related code
-assumenosideeffects class com.duckbuck.app.** {
    *** debug*(...);
    *** test*(...);
}

# Ignore Play Core classes that are not used (for apps not using dynamic delivery)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.devtools.build.android.desugar.runtime.ThrowableExtension
