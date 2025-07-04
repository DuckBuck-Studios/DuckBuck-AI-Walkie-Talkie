#!/bin/bash

# Script to test AI agent background service functionality
# This script helps verify that the AI agent service persists in the background and shows the notification

echo "🧪 Testing AI Agent Background Service..."

# 1. Build the app in debug mode
echo "📱 Building debug APK..."
cd /Users/rudra/Development/DuckBuck-AI-Walkie-Talkie
flutter build apk --debug

# 2. Install the APK
echo "📲 Installing debug APK..."
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 3. Start the app
echo "🚀 Starting the app..."
adb shell am start -n com.duckbuck.app/com.duckbuck.app.MainActivity

echo "
🧪 Test Steps:
1. Start an AI agent session in the app
2. Put the app in background (home button)
3. Check if notification appears: 'DuckBuck AI Connected'
4. Verify the AI service persists in background
5. Return to app via notification

📋 What to check:
- ✅ Notification shows: 'DuckBuck AI Connected'
- ✅ AI call persists in background
- ✅ Audio continues working
- ✅ AI filters remain active
- ✅ Notification opens the app

🔧 To monitor logs:
adb logcat -s AiAgentService:* AiAgentBridge:* AiAgentLifecycleService:* NotificationService:*
"

# 4. Monitor relevant logs
echo "📊 Monitoring AI agent logs..."
adb logcat -s AiAgentService:* AiAgentBridge:* NotificationService:*
