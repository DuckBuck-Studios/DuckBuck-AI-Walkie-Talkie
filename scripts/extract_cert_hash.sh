#!/bin/bash
#==============================================================================
# Certificate Hash Extractor for DuckBuck Android App
# This script extracts certificate hashes from Android keystore in formats
# required for TamperDetector and SSL Certificate Pinning
#==============================================================================

# Print banner
print_banner() {
  echo "======================================================"
  echo "  CERTIFICATE HASH EXTRACTOR FOR ANDROID SECURITY"
  echo "======================================================"
}

print_banner

# Set default values
KEYSTORE_PATH="$HOME/.android/debug.keystore"
PASSWORD="android"
ALIAS="androiddebugkey"
DOMAIN=""

# Function to display usage information
show_usage() {
  echo "Usage:"
  echo "  $0 [keystore_path] [password] [alias]"
  echo "  $0 duckbuck              # Use DuckBuck debug keystore"
  echo "  $0 duckbuck-release      # Use DuckBuck release keystore"
  echo "  $0 domain [domain_name]  # Extract certificate pins from a domain"
  echo ""
  echo "Examples:"
  echo "  $0                       # Use default debug keystore"
  echo "  $0 duckbuck              # Use DuckBuck debug keystore"
  echo "  $0 domain api.duckbuck.app  # Get certificate pins for a domain"
  echo ""
}

# Check for help flag
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  show_usage
  exit 0
fi

# Check for domain extraction mode
if [ "$1" == "domain" ]; then
  if [ "$2" == "" ]; then
    echo "Error: Domain name required"
    show_usage
    exit 1
  fi
  DOMAIN="$2"
  echo "Extracting certificate pins from domain: $DOMAIN"
fi

# Check for custom arguments
if [ "$1" != "" ] && [ "$1" != "domain" ]; then
  KEYSTORE_PATH="$1"
fi

if [ "$2" != "" ] && [ "$1" != "domain" ]; then
  PASSWORD="$2"
fi

if [ "$3" != "" ] && [ "$1" != "domain" ]; then
  ALIAS="$3"
fi

# For DuckBuck app, we can use the debug keystore provided in the project
if [ "$1" == "duckbuck" ]; then
  KEYSTORE_PATH="$HOME/Development/DuckBuck/android/app/duckbuck_debug.jks"
  PASSWORD="SrxnS@2005"
  ALIAS="duckbuck_debug"
  echo "Using DuckBuck debug keystore"
fi

# For DuckBuck release app
if [ "$1" == "duckbuck-release" ]; then
  KEYSTORE_PATH="$HOME/Development/DuckBuck/android/app/duckbuck_release.jks"
  echo -n "Enter keystore password: "
  read -s PASSWORD
  echo ""
  ALIAS="duckbuck"
  echo "Using DuckBuck release keystore"
fi

# Function to extract certificate from domain
extract_from_domain() {
  domain=$1
  echo -e "\nExtracting certificate pins from domain: $domain"
  
  # Create temporary files
  TEMP_CERT=$(mktemp)
  
  echo "Connecting to $domain..."
  # Use OpenSSL to get the certificate - with better error handling
  echo | openssl s_client -servername $domain -connect $domain:443 </dev/null 2>/dev/null | \
  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "$TEMP_CERT"
  
  if [ ! -s "$TEMP_CERT" ]; then
    echo "Error: Could not retrieve certificate from $domain"
    echo "Make sure the domain is accessible and supports HTTPS"
    rm -f "$TEMP_CERT"
    return 1
  fi
  
  echo "Certificate retrieved successfully!"
  
  # Format 3: Base64 format for certificate pinning
  echo -e "\nCertificate pin for $domain (for SSLPinningManager.kt):"
  CERT_PIN=$(openssl x509 -in "$TEMP_CERT" -pubkey -noout 2>/dev/null | \
             openssl pkey -pubin -outform der 2>/dev/null | \
             openssl dgst -sha256 -binary 2>/dev/null | \
             openssl enc -base64 2>/dev/null)
             
  if [ -z "$CERT_PIN" ]; then
    echo "Error: Failed to generate certificate pin"
    rm -f "$TEMP_CERT"
    return 1
  fi
  
  echo "sha256/$CERT_PIN"
  
  # Clean up
  rm -f "$TEMP_CERT"
  
  # Create code snippet 
  echo -e "\nFor SSLPinningManager.kt:"
  echo "\"$domain\" to listOf(
    \"sha256/$CERT_PIN\"
)"
  
  echo -e "\nAdd this to SSLPinningManager.kt CERTIFICATE_PINS map for domain \"$domain\""
}

# If in domain mode, extract certificate pins from the domain and exit
if [ "$DOMAIN" != "" ]; then
  extract_from_domain "$DOMAIN"
  exit 0
fi

# Check if the keystore exists
if [ ! -f "$KEYSTORE_PATH" ]; then
  echo "Error: Keystore not found at $KEYSTORE_PATH"
  exit 1
fi

echo -e "\nExtracting certificate hash from $KEYSTORE_PATH for alias $ALIAS"

# Extract certificate and hash it with SHA-256
TEMP_CERT=$(mktemp)
keytool -exportcert -keystore "$KEYSTORE_PATH" -storepass "$PASSWORD" -alias "$ALIAS" -rfc > "$TEMP_CERT"

if [ $? -ne 0 ]; then
  echo "Error: Failed to extract certificate. Check your keystore path, password, and alias."
  rm -f "$TEMP_CERT"
  exit 1
fi

# Display information about the certificate
echo -e "\nCertificate Information:"
openssl x509 -in "$TEMP_CERT" -noout -subject -issuer -dates | sed 's/^/  /'

# Use OpenSSL to get the SHA-256 hash
echo -e "\nCertificate SHA-256 fingerprints:"

# Format 1: Standard colon-delimited format
echo -e "\nFormat 1 (standard with colons):"
openssl x509 -in "$TEMP_CERT" -noout -fingerprint -sha256 | sed 's/SHA256 Fingerprint=//'

# Format 2: Uppercase hexadecimal format without separators (for TamperDetector)
echo -e "\nFormat 2 (for TamperDetector.kt):"
HASH_FOR_TAMPER_DETECTOR=$(openssl x509 -in "$TEMP_CERT" -noout -fingerprint -sha256 | sed 's/SHA256 Fingerprint=//' | sed 's/://g')
HASH_FOR_TAMPER_DETECTOR=$(echo "$HASH_FOR_TAMPER_DETECTOR" | tr -d ' ' | tr -d '\n' | sed 's/sha256Fingerprint=//g')
echo "$HASH_FOR_TAMPER_DETECTOR"

# Format 3: Base64 format for certificate pinning
echo -e "\nFormat 3 (base64 for SSL certificate pinning):"
HASH_FOR_SSL_PINNING=$(openssl x509 -in "$TEMP_CERT" -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)
echo "sha256/$HASH_FOR_SSL_PINNING"

# Clean up
rm -f "$TEMP_CERT"

# Create code snippets for direct use
echo -e "\n==================================================="
echo "Code snippets ready for your Android security files:"

# TamperDetector snippet
echo -e "\nFor TamperDetector.kt:"
echo "private const val EXPECTED_CERT_SHA256 = \"$HASH_FOR_TAMPER_DETECTOR\""

# SSLPinningManager snippet
echo -e "\nFor SSLPinningManager.kt (your app domain):"
echo "\"*.duckbuck.app\" to listOf(
    \"sha256/$HASH_FOR_SSL_PINNING\"
)"

echo -e "\n==================================================="
echo "How to use these values:"
echo "1. Update TamperDetector.kt with Format 2 value"
echo "2. Update SSLPinningManager.kt with Format 3 value"
echo "3. To extract certificates from your backend domains, run:"
echo "   $0 domain api.duckbuck.app"
echo "==================================================="
