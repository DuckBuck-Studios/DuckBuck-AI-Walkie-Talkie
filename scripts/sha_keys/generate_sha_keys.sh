#!/bin/bash

# Script to generate SHA-1 and SHA-256 keys for Android app signing
# This script supports both debug and release keystores

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}        Firebase SHA Key Generator for DuckBuck      ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Function to generate both SHA-1 and SHA-256 fingerprints
generate_fingerprints() {
    local keystore_path=$1
    local keystore_password=$2
    local key_alias=$3

    echo -e "${YELLOW}Generating SHA-1 fingerprint...${NC}"
    keytool -list -v -keystore "$keystore_path" -alias "$key_alias" -storepass "$keystore_password" | grep -A 1 "SHA1:"
    
    echo -e "${YELLOW}Generating SHA-256 fingerprint...${NC}"
    keytool -list -v -keystore "$keystore_path" -alias "$key_alias" -storepass "$keystore_password" | grep -A 1 "SHA256:"
    
    echo ""
}

# Check for keytool
if ! command -v keytool &> /dev/null; then
    echo -e "${RED}Error: keytool not found.${NC}"
    echo -e "${YELLOW}Please make sure you have Java installed and keytool is in your PATH.${NC}"
    exit 1
fi

# Script root directory (parent of the directory containing this script)
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_DIR="$PROJECT_ROOT/android"

# Get user input for which keystore to process
echo -e "Choose the keystore to generate SHA keys for:"
echo -e "1) Debug keystore (for development)"
echo -e "2) Release keystore (for production)"
echo -e "3) Both keystores"
read -p "Enter your choice (1-3): " KEYSTORE_CHOICE

# Debug keystore paths and info
DEBUG_KEYSTORE_PATH="$ANDROID_DIR/app/duckbuck_debug.jks"
DEBUG_KEYSTORE_PASSWORD="SrxnS@2005"
DEBUG_KEY_ALIAS="duckbuck_debug"

# Check if debug keystore file exists
if [ ! -f "$DEBUG_KEYSTORE_PATH" ]; then
    echo -e "${YELLOW}Debug keystore not found at $DEBUG_KEYSTORE_PATH${NC}"
    echo -e "${GREEN}Creating new debug keystore...${NC}"
    
    # Create the debug keystore
    keytool -genkey -v -keystore "$DEBUG_KEYSTORE_PATH" \
        -alias "$DEBUG_KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass "$DEBUG_KEYSTORE_PASSWORD" \
        -keypass "$DEBUG_KEYSTORE_PASSWORD" \
        -dname "CN=DuckBuck Debug, OU=DuckBuck, O=DuckBuck Studios, L=Banglore, S=Karnataka, C=IN"
    
    if [ -f "$DEBUG_KEYSTORE_PATH" ]; then
        echo -e "${GREEN}Debug keystore created successfully at $DEBUG_KEYSTORE_PATH${NC}"
    else
        echo -e "${RED}Failed to create debug keystore. Trying default location...${NC}"
        DEBUG_KEYSTORE_PATH="$HOME/.android/debug.keystore"
        DEBUG_KEYSTORE_PASSWORD="android"
        DEBUG_KEY_ALIAS="androiddebugkey"
        echo -e "${YELLOW}Using default debug keystore location: $DEBUG_KEYSTORE_PATH${NC}"
    fi
fi

# Check for release keystore info
RELEASE_KEYSTORE_PATH="$ANDROID_DIR/app/duckbuck_release.jks"

# Process debug keystore if selected
if [[ "$KEYSTORE_CHOICE" == "1" || "$KEYSTORE_CHOICE" == "3" ]]; then
    echo -e "${GREEN}==== Debug Keystore SHA Keys ====${NC}"
    if [ -f "$DEBUG_KEYSTORE_PATH" ]; then
        generate_fingerprints "$DEBUG_KEYSTORE_PATH" "$DEBUG_KEYSTORE_PASSWORD" "$DEBUG_KEY_ALIAS"
        echo -e "${GREEN}Debug SHA Keys generated successfully!${NC}"
    else
        echo -e "${RED}Error: Debug keystore not found at $DEBUG_KEYSTORE_PATH${NC}"
        exit 1
    fi
fi

# Process release keystore if selected
if [[ "$KEYSTORE_CHOICE" == "2" || "$KEYSTORE_CHOICE" == "3" ]]; then
    echo -e "${GREEN}==== Release Keystore SHA Keys ====${NC}"
    
    # Check if release keystore exists
    if [ -f "$RELEASE_KEYSTORE_PATH" ]; then
        # Ask for release keystore password and alias
        read -p "Enter release keystore password: " RELEASE_KEYSTORE_PASSWORD
        read -p "Enter release key alias: " RELEASE_KEY_ALIAS
        
        generate_fingerprints "$RELEASE_KEYSTORE_PATH" "$RELEASE_KEYSTORE_PASSWORD" "$RELEASE_KEY_ALIAS"
        echo -e "${GREEN}Release SHA Keys generated successfully!${NC}"
    else
        echo -e "${RED}Warning: Release keystore not found at $RELEASE_KEYSTORE_PATH${NC}"
        echo -e "${YELLOW}Would you like to create a new release keystore? (y/n)${NC}"
        read CREATE_NEW_KEYSTORE
        
        if [[ "$CREATE_NEW_KEYSTORE" == "y" || "$CREATE_NEW_KEYSTORE" == "Y" ]]; then
            # Create a new release keystore
            read -p "Enter new keystore password: " NEW_KEYSTORE_PASSWORD
            read -p "Enter key alias: " NEW_KEY_ALIAS
            read -p "Enter your name (CN): " KEY_CN
            
            echo -e "${YELLOW}Generating new release keystore...${NC}"
            keytool -genkey -v -keystore "$RELEASE_KEYSTORE_PATH" \
                -alias "$NEW_KEY_ALIAS" \
                -keyalg RSA \
                -keysize 2048 \
                -validity 10000 \
                -storepass "$NEW_KEYSTORE_PASSWORD" \
                -keypass "$NEW_KEYSTORE_PASSWORD" \
                -dname "CN=$KEY_CN, OU=DuckBuck, O=DuckBuck Studios, L=Unknown, S=Unknown, C=US"
                
            echo -e "${GREEN}Release keystore created successfully!${NC}"
            generate_fingerprints "$RELEASE_KEYSTORE_PATH" "$NEW_KEYSTORE_PASSWORD" "$NEW_KEY_ALIAS"
            
            echo -e "${YELLOW}Important: Remember to update your build.gradle.kts with the new signing config!${NC}"
            echo -e "Example:"
            echo -e "signingConfigs {"
            echo -e "    create(\"release\") {"
            echo -e "        keyAlias = \"$NEW_KEY_ALIAS\""
            echo -e "        keyPassword = \"$NEW_KEYSTORE_PASSWORD\""
            echo -e "        storeFile = file(\"duckbuck_release.jks\")"
            echo -e "        storePassword = \"$NEW_KEYSTORE_PASSWORD\""
            echo -e "    }"
            echo -e "}"
        else
            echo -e "${YELLOW}Skipping release keystore generation.${NC}"
        fi
    fi
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}Add these SHA keys to your Firebase project:${NC}"
echo -e "1. Go to Firebase Console (https://console.firebase.google.com/)"
echo -e "2. Select your project: duckbuck-studios-test"
echo -e "3. Go to Project Settings > Your Apps > Android app"
echo -e "4. Scroll down to 'SHA certificate fingerprints' and click 'Add fingerprint'"
echo -e "5. Add both SHA-1 and SHA-256 fingerprints for your keystores"
echo -e "${BLUE}====================================================${NC}"
