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
    ndkVersion = "27.0.12077973"
    
    // Add packagingOptions to handle native libraries properly for Agora SDK 4.5.2
    packagingOptions {
        // Pick first occurrence of any duplicated files
        pickFirst("**/*.so")
        // Exclude unnecessary files
        exclude("META-INF/DEPENDENCIES")
        exclude("META-INF/LICENSE")
        exclude("META-INF/LICENSE.txt")
        exclude("META-INF/license.txt")
        exclude("META-INF/NOTICE")
        exclude("META-INF/NOTICE.txt")
        exclude("META-INF/notice.txt")
        exclude("META-INF/ASL2.0")
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17 
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
            // ProGuard files removed - will be configured later for production
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
            
            // Add ProGuard rules for production optimization
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
    // Firebase Messaging for FCM notifications
    implementation("com.google.firebase:firebase-messaging:23.4.0")
    
    // Agora SDK 4.5.2 for voice and video calls with necessary components
    implementation("io.agora.rtc:full-rtc-basic:4.5.2")
    // Add Agora supporting libraries
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.core:core-ktx:1.12.0")
    
    // Required dependencies for Apple Sign In on Android
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("androidx.browser:browser:1.6.0")
}

flutter {
    source = "../.."
}
