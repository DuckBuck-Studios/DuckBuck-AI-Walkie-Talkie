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
    }

    defaultConfig {
        applicationId = "com.duckbuck.app"
        minSdk = 27
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("custom_debug")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("custom_debug")
        }
    }
}

dependencies {
    // Add desugaring library for backward compatibility with older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}

flutter {
    source = "../.."
}
