#!/bin/bash

# Script to update all Log statements to use AppLogger for production readiness
# This ensures no logs appear in production builds

echo "🔄 Updating Kotlin modules to use production-safe logging..."

# Array of files to update
files=(
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/core/AgoraEngineInitializer.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/core/AgoraMethodChannelHandler.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/core/AgoraServiceManager.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/agora/AgoraService.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/agora/AgoraCallManager.kt"
    ""
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/callstate/CallStatePersistenceManager.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/notifications/NotificationManager.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/services/WalkieTalkieService.kt"
    "/Users/rudra/Development/DuckBuck/android/app/src/main/kotlin/com/duckbuck/app/fcm/FcmDataHandler.kt"
)

# Function to update imports and Log statements
update_file() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        echo "  📝 Updating: $(basename "$file")"
        
        # Add AppLogger import if not present
        if ! grep -q "import com.duckbuck.app.core.AppLogger" "$file"; then
            # Find the package line and add import after it
            sed -i '' '/^package /a\
import com.duckbuck.app.core.AppLogger
' "$file"
        fi
        
        # Remove android.util.Log import if present
        sed -i '' '/^import android\.util\.Log$/d' "$file"
        
        # Replace Log.d with AppLogger.d
        sed -i '' 's/Log\.d(/AppLogger.d(/g' "$file"
        
        # Replace Log.i with AppLogger.i
        sed -i '' 's/Log\.i(/AppLogger.i(/g' "$file"
        
        # Replace Log.w with AppLogger.w
        sed -i '' 's/Log\.w(/AppLogger.w(/g' "$file"
        
        # Replace Log.e with AppLogger.e
        sed -i '' 's/Log\.e(/AppLogger.e(/g' "$file"
        
        echo "    ✅ Updated logging in $(basename "$file")"
    else
        echo "    ⚠️  File not found: $file"
    fi
}

# Update each file
for file in "${files[@]}"; do
    update_file "$file"
done

echo ""
echo "✅ Production logging update completed!"
echo "🔒 All modules now use BuildConfig-controlled logging"
echo "📊 Logs will be automatically suppressed in release builds"
