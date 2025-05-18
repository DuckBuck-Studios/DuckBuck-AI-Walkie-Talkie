# filepath: /Users/rudrasahoo/Development/DuckBuck/android/app/security-rules.pro
# Security-specific ProGuard rules

# Keep security-related classes completely
-keep class com.duckbuck.app.security.** { *; }

# Keep crypto operations classes
-keep class javax.crypto.** { *; }
-keep class javax.crypto.spec.** { *; }
-keep class javax.net.ssl.** { *; }

# Prevent security-related strings from being obfuscated
-keepclassmembers class com.duckbuck.app.security.** {
    private static final java.lang.String *;
    public static final java.lang.String *;
}

# Keep annotations on security classes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses

# Prevent security constants from being inlined/removed
-keepclassmembers class com.duckbuck.app.security.** {
    static final boolean *;
    static final byte *;
    static final int *;
    static final long *;
    static final short *;
    static final char *;
    static final double *;
    static final float *;
}
