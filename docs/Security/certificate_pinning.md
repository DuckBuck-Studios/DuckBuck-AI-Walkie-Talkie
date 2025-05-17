# Certificate Pinning Implementation

This document explains the certificate pinning implementation in the DuckBuck application.

## Overview

Certificate pinning is a security technique used to prevent man-in-the-middle attacks by validating a server's public key or certificate against a known, trusted value. It ensures that the app only communicates with servers presenting the expected certificates.

In this application, certificate pinning is implemented using:
- For iOS: TrustKit library 
- For Android: Network Security Configuration

## iOS Implementation

### Architecture

The iOS certificate pinning implementation follows these principles:
- **Separation of Concerns**: Certificate pinning logic is isolated in a dedicated `CertificatePinningManager` class
- **Singleton Pattern**: The manager is implemented as a singleton for global access
- **Error Handling**: Includes comprehensive error handling for certificate validation failures
- **Notification System**: Uses NSNotificationCenter for validating certificate failures

### Components

1. **CertificatePinningManager**: Located in the `/Security` directory, this class:
   - Initializes TrustKit with the proper configuration
   - Handles validation errors
   - Provides a clean API for the rest of the application

2. **AppDelegate**: Initializes the certificate pinning manager during app startup

3. **Info.plist**: Contains App Transport Security (ATS) settings

### Certificate Pins

The pins used in this implementation were extracted from the following domains:
- `googleapis.com`
- `firestore.googleapis.com`
- `firebasestorage.googleapis.com`

The pins are expected to be valid until May 17, 2025, and include backup pins in case of certificate rotation.

## Android Implementation

Certificate pinning in Android is implemented through the network security configuration, which allows specifying:
- Custom certificate authorities
- Certificate pinning rules
- Clear text traffic permissions

The main components are:
1. **AndroidManifest.xml**: References the network security configuration
2. **network_security_config.xml**: Contains domain configurations and certificate pins

## Best Practices

1. **Regular Updates**: Certificates should be monitored and pins updated before they expire
2. **Backup Pins**: Always include backup pins to handle certificate rotation
3. **Error Handling**: Properly handle validation failures to avoid locking users out
4. **Testing**: Test certificate pinning with both valid and invalid certificates
5. **Documentation**: Keep documentation updated with any changes to the certificate pinning strategy

## Updating Certificate Pins

To update the certificate pins:

1. **Extract Primary Pin**: Use the OpenSSL command to extract the primary pin from the leaf certificate:
   ```
   openssl s_client -servername googleapis.com -connect googleapis.com:443 | openssl x509 -pubkey -noout | openssl rsa -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
   ```

2. **Extract Backup Pin**: Generate a backup pin from the intermediate certificate in the chain:
   ```
   # Save the certificate chain to a file
   openssl s_client -servername googleapis.com -connect googleapis.com:443 -showcerts > cert_chain.pem
   
   # Extract the intermediate certificate (second in the chain)
   awk 'BEGIN {c=0;} /BEGIN CERT/{c++} { if(c==2) print $0; }' cert_chain.pem > intermediate.pem
   
   # Generate the backup pin from the intermediate certificate
   cat intermediate.pem | openssl x509 -pubkey -noout | openssl rsa -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
   ```

3. **Update Both Platforms**:
   - For iOS: Update both pins in the `CertificatePinningManager` class
   - For Android: Update both pins in the `network_security_config.xml` file

4. **Test Thoroughly**: Ensure the app can still communicate with all pinned domains

> **Why Backup Pins?** Backup pins are essential to ensure your app continues to function when certificates rotate. Without a backup pin, your app would fail to connect when the primary certificate changes, requiring an emergency app update. Ideally, the backup pin should be from an intermediate or root certificate in the same certificate chain.
