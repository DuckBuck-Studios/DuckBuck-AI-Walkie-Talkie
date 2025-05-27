# Environment Configuration

This document explains how to set up and run the DuckBuck application with proper environment configuration for development and production.

## Required Environment Variables

### DUCKBUCK_API_KEY
The API key used to authenticate with the DuckBuck backend services.

## Quick Start

### 1. Environment Setup

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set your actual API key:

```bash
DUCKBUCK_API_KEY=your_actual_api_key_here
ENVIRONMENT=development
```

### 2. Development

Run the app in development mode with automatic environment loading:

```bash
# Run on default device
./scripts/run-dev.sh

# Run on specific device (iOS)
./scripts/run-dev.sh "iPhone 15 Pro"
./scripts/run-dev.sh "Rudra's iPhone"

# Run on specific device (Android)
./scripts/run-dev.sh "Pixel 7 API 34"
./scripts/run-dev.sh "emulator-name"
```

The development script will:
- Automatically load environment variables from `.env`
- Start the app with hot reload enabled
- Show truncated API key for security verification
- List available devices if no specific device is found

### 3. Production Builds

Use the build script for production-ready builds:

```bash
# Android builds
./scripts/build.sh debug          # Debug APK
./scripts/build.sh release        # Release APK

# iOS builds  
./scripts/build.sh ios-debug      # Debug iOS build
./scripts/build.sh ios-release    # Release iOS build
```

The build script will:
- Load environment variables from `.env`
- Validate that `DUCKBUCK_API_KEY` is set
- Pass environment variables using `--dart-define`
- Create optimized builds for the target platform

## Advanced Usage

### Manual Environment Setup

If you prefer to set environment variables manually:

```bash
# Export the variable
export DUCKBUCK_API_KEY="your_api_key_here"

# Run Flutter with dart-define
flutter run --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"

# Or build with dart-define  
flutter build apk --release --dart-define=DUCKBUCK_API_KEY="$DUCKBUCK_API_KEY"
```

### Script Details

#### Development Script (`./scripts/run-dev.sh`)
- Loads `.env` file automatically
- Shows truncated API key for verification
- Lists available devices if target not found
- Supports device name or ID as parameter
- Enables hot reload for fast development

#### Build Script (`./scripts/build.sh`)
- Validates environment variables before building
- Supports multiple build types: `debug`, `release`, `ios-debug`, `ios-release`
- Passes environment variables securely using `--dart-define`
- Creates optimized builds for deployment

### Example Workflow

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your API key

# 2. Start development
./scripts/run-dev.sh

# 3. Build for production when ready
./scripts/build.sh release
```

## Security Notes

- **Never commit the `.env` file** to version control (it's already in `.gitignore`)
- The `.env.example` file should only contain placeholder values
- API keys should be rotated regularly
- Use different API keys for development and production environments

## CI/CD Setup

For continuous integration, set the environment variables in your CI system:

### GitHub Actions
```yaml
env:
  DUCKBUCK_API_KEY: ${{ secrets.DUCKBUCK_API_KEY }}
```

### Other CI Systems
Set `DUCKBUCK_API_KEY` as a secret environment variable in your CI configuration.

## Troubleshooting

### "API key is required" Error
This error occurs when the `DUCKBUCK_API_KEY` environment variable is not set or is empty.

**Solutions:**
1. Ensure your `.env` file exists and contains the API key
2. Use the provided scripts (`./scripts/run-dev.sh` or `./scripts/build.sh`)
3. Manually export the environment variable before running Flutter commands

### Environment File Not Found
If scripts show "Warning: .env file not found":

1. Create the `.env` file: `cp .env.example .env`
2. Edit the file and add your API key
3. Ensure the file is in the project root directory

### Device Not Found
If you get "No supported devices found":

1. Check available devices: `flutter devices`
2. Start an emulator or connect a physical device
3. Use the exact device name or ID as shown in `flutter devices`

### Build Failures
If builds fail with environment-related errors:

1. Verify the API key is set: `echo $DUCKBUCK_API_KEY`
2. Try cleaning the build: `flutter clean && flutter pub get`
3. Ensure scripts are executable: `chmod +x scripts/*.sh`
