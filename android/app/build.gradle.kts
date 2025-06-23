plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties for release builds
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.duckbuck.app"
    compileSdk = 34  // Updated to latest Android 14
    ndkVersion = "27.0.12077973"
    
    // Add packagingOptions to handle native libraries properly for Agora SDK and production
    packagingOptions {
        // Pick first occurrence of any duplicated files
        pickFirst("**/*.so")
        pickFirst("**/libc++_shared.so")
        pickFirst("**/libjsc.so")
        // Exclude unnecessary files for smaller APK size
        exclude("META-INF/DEPENDENCIES")
        exclude("META-INF/LICENSE")
        exclude("META-INF/LICENSE.txt")
        exclude("META-INF/license.txt")
        exclude("META-INF/NOTICE")
        exclude("META-INF/NOTICE.txt")  
        exclude("META-INF/notice.txt")
        exclude("META-INF/ASL2.0")
        exclude("META-INF/*.kotlin_module")
        exclude("**/kotlin/**")
        exclude("**/*.kotlin_builtins") 
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17 
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Add signing configurations for production builds using key.properties
    signingConfigs {
        getByName("debug") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String  
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.duckbuck.app"
        minSdk = 27  // Android 8.1+ for better performance and security
        targetSdk = 34  // Latest Android 14 for better compatibility
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Add manifest placeholder for package name to ensure consistency
        manifestPlaceholders["appPackageName"] = "com.duckbuck.app"
        
        // Enable multidex for production builds with many dependencies
        multiDexEnabled = true
        
        // Disable legacy multidex for better performance
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        debug {
            // Use release keystore for debug builds to match Firebase SHA keys
            signingConfig = signingConfigs.getByName("debug")
            
            // Keep debugging enabled for development
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
