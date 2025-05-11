@echo off
setlocal EnableDelayedExpansion

::: Check if debug keystore file exists
if not exist "%DEBUG_KEYSTORE_PATH%" (
    echo %YELLOW%Debug keystore not found at %DEBUG_KEYSTORE_PATH%%NC%
    echo %GREEN%Creating new debug keystore...%NC%
    
    :: Create the debug keystore
    keytool -genkey -v -keystore "%DEBUG_KEYSTORE_PATH%" ^
        -alias "%DEBUG_KEY_ALIAS%" ^
        -keyalg RSA ^
        -keysize 2048 ^
        -validity 10000 ^
        -storepass "%DEBUG_KEYSTORE_PASSWORD%" ^
        -keypass "%DEBUG_KEYSTORE_PASSWORD%" ^
        -dname "CN=DuckBuck Debug, OU=DuckBuck, O=DuckBuck Studios, L=Unknown, S=Unknown, C=US"
    
    if exist "%DEBUG_KEYSTORE_PATH%" (
        echo %GREEN%Debug keystore created successfully at %DEBUG_KEYSTORE_PATH%%NC%
    ) else (
        echo %RED%Failed to create debug keystore. Trying default location...%NC%
        set "DEBUG_KEYSTORE_PATH=%USERPROFILE%\.android\debug.keystore"
        set "DEBUG_KEYSTORE_PASSWORD=android"
        set "DEBUG_KEY_ALIAS=androiddebugkey"
        echo %YELLOW%Using default debug keystore location: %DEBUG_KEYSTORE_PATH%%NC%
    )
)t to generate SHA-1 and SHA-256 keys for Android app signing
:: This script supports both debug and release keystores

:: Set colors for console output
set GREEN=[92m
set YELLOW=[93m
set RED=[91m
set BLUE=[94m
set NC=[0m

:: Print header
echo %BLUE%=====================================================%NC%
echo %BLUE%        Firebase SHA Key Generator for DuckBuck      %NC%
echo %BLUE%=====================================================%NC%

:: Check for keytool
where keytool > nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%Error: keytool not found.%NC%
    echo %YELLOW%Please make sure you have Java installed and keytool is in your PATH.%NC%
    exit /b 1
)

:: Script root directory
set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\..\"
set "ANDROID_DIR=%PROJECT_ROOT%android"

:: Get user input for which keystore to process
echo Choose the keystore to generate SHA keys for:
echo 1) Debug keystore (for development)
echo 2) Release keystore (for production)
echo 3) Both keystores
set /p KEYSTORE_CHOICE="Enter your choice (1-3): "

:: Debug keystore paths and info
set "DEBUG_KEYSTORE_PATH=%ANDROID_DIR%\app\duckbuck_debug.jks"
set "DEBUG_KEYSTORE_PASSWORD=SrxnS@2005"
set "DEBUG_KEY_ALIAS=duckbuck_debug"

:: Check if debug keystore file exists
if not exist "%DEBUG_KEYSTORE_PATH%" (
    echo %RED%Warning: Debug keystore not found at %DEBUG_KEYSTORE_PATH%%NC%
    set "DEBUG_KEYSTORE_PATH=%USERPROFILE%\.android\debug.keystore"
    set "DEBUG_KEYSTORE_PASSWORD=android"
    set "DEBUG_KEY_ALIAS=androiddebugkey"
    echo %YELLOW%Trying default debug keystore location: %DEBUG_KEYSTORE_PATH%%NC%
)

:: Check for release keystore
set "RELEASE_KEYSTORE_PATH=%ANDROID_DIR%\app\duckbuck_release.jks"

:: Process debug keystore if selected
if %KEYSTORE_CHOICE%==1 (
    goto :generate_debug
) else if %KEYSTORE_CHOICE%==3 (
    goto :generate_debug
) else (
    goto :check_release
)

:generate_debug
echo %GREEN%==== Debug Keystore SHA Keys ====%NC%
if exist "%DEBUG_KEYSTORE_PATH%" (
    echo %YELLOW%Generating SHA-1 fingerprint...%NC%
    keytool -list -v -keystore "%DEBUG_KEYSTORE_PATH%" -alias "%DEBUG_KEY_ALIAS%" -storepass "%DEBUG_KEYSTORE_PASSWORD%" | findstr /C:"SHA1" /C:"SHA1:" /C:"SHA256" /C:"SHA256:"
    echo.
    echo %GREEN%Debug SHA Keys generated successfully!%NC%
) else (
    echo %RED%Error: Debug keystore not found at %DEBUG_KEYSTORE_PATH%%NC%
    exit /b 1
)
if %KEYSTORE_CHOICE%==1 goto :end

:check_release
:: Process release keystore if selected
if %KEYSTORE_CHOICE%==2 (
    echo %GREEN%==== Release Keystore SHA Keys ====%NC%
    goto :generate_release
) else if %KEYSTORE_CHOICE%==3 (
    echo %GREEN%==== Release Keystore SHA Keys ====%NC%
    goto :generate_release
) else (
    goto :end
)

:generate_release
:: Check if release keystore exists
if exist "%RELEASE_KEYSTORE_PATH%" (
    :: Ask for release keystore password and alias
    set /p RELEASE_KEYSTORE_PASSWORD="Enter release keystore password: "
    set /p RELEASE_KEY_ALIAS="Enter release key alias: "
    
    echo %YELLOW%Generating SHA-1 and SHA-256 fingerprints...%NC%
    keytool -list -v -keystore "%RELEASE_KEYSTORE_PATH%" -alias "%RELEASE_KEY_ALIAS%" -storepass "%RELEASE_KEYSTORE_PASSWORD%" | findstr /C:"SHA1" /C:"SHA1:" /C:"SHA256" /C:"SHA256:"
    echo.
    echo %GREEN%Release SHA Keys generated successfully!%NC%
) else (
    echo %RED%Warning: Release keystore not found at %RELEASE_KEYSTORE_PATH%%NC%
    set /p CREATE_NEW_KEYSTORE="Would you like to create a new release keystore? (y/n): "
    
    if /i "%CREATE_NEW_KEYSTORE%"=="y" (
        :: Create a new release keystore
        set /p NEW_KEYSTORE_PASSWORD="Enter new keystore password: "
        set /p NEW_KEY_ALIAS="Enter key alias: "
        set /p KEY_CN="Enter your name (CN): "
        
        echo %YELLOW%Generating new release keystore...%NC%
        keytool -genkey -v -keystore "%RELEASE_KEYSTORE_PATH%" ^
            -alias "%NEW_KEY_ALIAS%" ^
            -keyalg RSA ^
            -keysize 2048 ^
            -validity 10000 ^
            -storepass "%NEW_KEYSTORE_PASSWORD%" ^
            -keypass "%NEW_KEYSTORE_PASSWORD%" ^
            -dname "CN=%KEY_CN%, OU=DuckBuck, O=DuckBuck Studios, L=Unknown, S=Unknown, C=US"
                
        echo %GREEN%Release keystore created successfully!%NC%
        echo %YELLOW%Generating SHA-1 and SHA-256 fingerprints...%NC%
        keytool -list -v -keystore "%RELEASE_KEYSTORE_PATH%" -alias "%NEW_KEY_ALIAS%" -storepass "%NEW_KEYSTORE_PASSWORD%" | findstr /C:"SHA1" /C:"SHA1:" /C:"SHA256" /C:"SHA256:"
        
        echo.
        echo %YELLOW%Important: Remember to update your build.gradle.kts with the new signing config!%NC%
        echo Example:
        echo signingConfigs {
        echo     create("release") {
        echo         keyAlias = "%NEW_KEY_ALIAS%"
        echo         keyPassword = "%NEW_KEYSTORE_PASSWORD%"
        echo         storeFile = file("duckbuck_release.jks")
        echo         storePassword = "%NEW_KEYSTORE_PASSWORD%"
        echo     }
        echo }
    ) else (
        echo %YELLOW%Skipping release keystore generation.%NC%
    )
)

:end
echo %BLUE%=====================================================%NC%
echo %GREEN%Add these SHA keys to your Firebase project:%NC%
echo 1. Go to Firebase Console (https://console.firebase.google.com/)
echo 2. Select your project: duckbuck-studios-test
echo 3. Go to Project Settings ^> Your Apps ^> Android app
echo 4. Scroll down to 'SHA certificate fingerprints' and click 'Add fingerprint'
echo 5. Add both SHA-1 and SHA-256 fingerprints for your keystores
echo %BLUE%=====================================================%NC%

endlocal
