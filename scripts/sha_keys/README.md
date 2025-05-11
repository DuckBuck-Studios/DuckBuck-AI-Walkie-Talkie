# SHA Key Generator for DuckBuck

This module contains scripts to generate SHA-1 and SHA-256 certificate fingerprints for your Android app. These fingerprints are required by Firebase services such as Google Sign-In, Phone Authentication, and Dynamic Links.

## Why are SHA keys important?

SHA keys are used by Firebase to verify the identity of your app. Without the correct SHA keys registered in your Firebase project, certain features will not work properly:

- **Google Sign-In**: Authentication will fail
- **Phone Authentication**: You won't receive verification codes
- **Dynamic Links**: Links won't open your app
- **Firebase App Check**: Increased security verification may fail
- **Firebase Cloud Messaging**: Certain notification features may not work

## Available Scripts

The module contains two scripts:

1. `generate_sha_keys.sh` - For macOS and Linux users
2. `generate_sha_keys.bat` - For Windows users

## How to Use

### For macOS/Linux Users:

1. Open Terminal
2. Navigate to the scripts directory:
   ```bash
   cd /path/to/DuckBuck/scripts/sha_keys
   ```
3. Make the script executable (if needed):
   ```bash
   chmod +x generate_sha_keys.sh
   ```
4. Run the script:
   ```bash
   ./generate_sha_keys.sh
   ```
5. Follow the on-screen instructions to generate SHA keys for debug or release keystores

### For Windows Users:

1. Open Command Prompt or PowerShell
2. Navigate to the scripts directory:
   ```cmd
   cd \path\to\DuckBuck\scripts\sha_keys
   ```
3. Run the batch script:
   ```cmd
   generate_sha_keys.bat
   ```
4. Follow the on-screen instructions to generate SHA keys for debug or release keystores

## Adding SHA Keys to Firebase

After generating the keys, add them to your Firebase project:

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `duckbuck-studios-test`
3. Navigate to Project Settings > Your Apps > Android app
4. Scroll down to "SHA certificate fingerprints" and click "Add fingerprint"
5. Enter the SHA-1 and SHA-256 hash values from the script output
6. Click "Save"

## Environments

You should add different SHA keys based on your build environments:

- **Debug**: Add debug SHA keys when developing locally
- **Release**: Add release SHA keys for app store releases
- **CI/CD**: If using continuous integration, add the SHA keys for your build server

## Troubleshooting

If you encounter issues with Firebase services:

1. Verify that your SHA keys are correctly added to Firebase
2. Make sure you're using the correct keystore for your build variant
3. Check that your app's package name matches the one registered in Firebase
4. Ensure Firebase configuration files (google-services.json, GoogleService-Info.plist) are up-to-date

## Creating a Release Keystore

For production deployments, you should use a release keystore:

1. Run the script and select option 2 (Release keystore)
2. If prompted to create a new keystore, follow the instructions
3. Once created, update your `android/app/build.gradle.kts` file with the new signing configuration
4. Add the release SHA keys to your Firebase project

## For CI/CD Environments

If you're using a CI/CD pipeline for building your app:

1. Store your keystores securely in your CI/CD environment
2. Extract SHA keys during the build process
3. Add those SHA keys to Firebase
