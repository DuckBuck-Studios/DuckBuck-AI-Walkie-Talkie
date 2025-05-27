#!/bin/bash

# Development run script for DuckBuck with environment variables
# Usage: ./scripts/run-dev.sh [target_device]

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

TARGET_DEVICE=${1:-}

echo "Starting DuckBuck in development mode..."
echo "API Key: ${DUCKBUCK_API_KEY:0:10}... (truncated for security)"

cd "$PROJECT_ROOT"

# Run with environment variables
if [ -n "$TARGET_DEVICE" ]; then
    flutter run -d "$TARGET_DEVICE" --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
else
    flutter run --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
fi
