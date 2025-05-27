#!/bin/bash

# Build script for DuckBuck with environment variables
# Usage: ./scripts/build.sh [debug|release]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    echo "Loading environment variables from .env file..."
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found. Using default environment variables."
fi

# Validate required environment variables
if [ -z "$DUCKBUCK_API_KEY" ]; then
    echo "Error: DUCKBUCK_API_KEY environment variable is required"
    echo "Please set it in your .env file or export it directly"
    exit 1
fi

# Set build type
BUILD_TYPE=${1:-debug}

echo "Building DuckBuck in $BUILD_TYPE mode..."
echo "API Key: ${DUCKBUCK_API_KEY:0:10}... (truncated for security)"

cd "$PROJECT_ROOT"

# Build based on type
case "$BUILD_TYPE" in
    "debug")
        flutter build apk --debug --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
        ;;
    "release")
        flutter build apk --release --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
        ;;
    "ios-debug")
        flutter build ios --debug --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
        ;;
    "ios-release")
        flutter build ios --release --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
        ;;
    *)
        echo "Usage: $0 [debug|release|ios-debug|ios-release]"
        exit 1
        ;;
esac

echo "Build completed successfully!"
