plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.duckbuck.app"
    compileSdk = flutter.compileSdkVersion
    // Update NDK version as recommended by the build output
    ndkVersion = "27.0.12077973"
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Add isCoreLibraryDesugaringEnabled to support newer Java APIs on older Android versions
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Add signing configurations for the custom keystore with the correct password
    signingConfigs {
        create("custom_debug") {
            keyAlias = "duckbuck_debug"
            keyPassword = "SrxnS@2005" // Updated to the correct password
            storeFile = file("duckbuck_debug.jks")
            storePassword = "SrxnS@2005" // Updated to the correct password
        }
        
        // TODO: Add a proper release signing config with a more secure keystore
        // For production, do NOT store credentials in the build file
        // Use environment variables or a secure credential store instead
        create("release") {
            // These should be externalized in production
            keyAlias = System.getenv("KEYSTORE_ALIAS") ?: "duckbuck_debug"
            keyPassword = System.getenv("KEYSTORE_PASSWORD") ?: "SrxnS@2005"
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "duckbuck_debug.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "SrxnS@2005"
        }
    }

    defaultConfig {
        applicationId = "com.duckbuck.app"
        minSdk = 27
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Add manifest placeholder for package name to ensure consistency
        manifestPlaceholders["appPackageName"] = "com.duckbuck.app"
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("custom_debug")
            // Add proguard rules for debug builds to fix Google API Manager error
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = true
            
            // Add Firebase App Check debug provider only in debug builds
            manifestPlaceholders["appCheckDebugProvider"] = "true"
        }
        release {
            // Use the release signing config for production builds
            signingConfig = signingConfigs.getByName("release")
            
            // Enable obfuscation and code shrinking for release builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), 
                "proguard-rules.pro",
                "security-rules.pro"
            )
            
            // Disable debugging for release builds
            isDebuggable = false
            
            // Disable App Check debug provider in release builds
            manifestPlaceholders["appCheckDebugProvider"] = "false"
        }
    }
}

dependencies {
    // Add desugaring library for backward compatibility with older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
    
    // Required dependencies for Apple Sign In on Android
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("androidx.browser:browser:1.6.0")
    
    // AppCompat dependency for SecurityVerificationActivity
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // Add explicit dependencies for Play Integrity and App Check
    implementation("com.google.android.play:integrity:1.2.0")
    implementation("com.google.firebase:firebase-appcheck-playintegrity:17.1.2")
    implementation("com.google.firebase:firebase-appcheck-debug:17.1.2")
    
    // Security-related dependencies
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.bouncycastle:bcprov-jdk18on:1.76")
    
    // SafetyNet for additional device integrity checks
    implementation("com.google.android.gms:play-services-safetynet:18.0.1")
    
    // Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    
    // Additional security libraries
    implementation("com.google.crypto.tink:tink-android:1.9.0")
    implementation("androidx.biometric:biometric:1.1.0")
}

flutter {
    source = "../.."
}
