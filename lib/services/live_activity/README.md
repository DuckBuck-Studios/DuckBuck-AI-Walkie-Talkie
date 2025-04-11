# Call Live Activities Setup Guide

This guide explains how to set up the iOS widget extension for displaying call information in Live Activities, which appear in the Dynamic Island and on the Lock Screen.

## Prerequisites

- Xcode 14.1 or later
- iOS 16.1+ target devices
- SwiftUI knowledge

## Setup Steps

### 1. Create App Group

1. In Xcode, select your app's target
2. Go to "Signing & Capabilities"
3. Click "+ Capability" and add "App Groups"
4. Add a group with identifier: `group.com.duckbuck.app`

### 2. Create Widget Extension

1. In Xcode, select File > New > Target
2. Choose "Widget Extension" template
3. Name it "CallWidgetExtension"
4. Make sure "Include Live Activity" is checked
5. Select Swift as the language
6. Finish creating the extension

### 3. Configure Widget Extension

1. Select the new widget extension target
2. In "Signing & Capabilities":
   - Add the same App Group: `group.com.duckbuck.app`
   - Add the "Push Notifications" capability

### 4. Modify CallLiveActivity.swift

Replace the content of `CallLiveActivity.swift` with:

```swift
import WidgetKit
import SwiftUI
import ActivityKit

struct CallAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var callerName: String
        var callDuration: String
    }
}

struct CallLiveActivityView: View {
    let context: ActivityViewContext<CallAttributes>
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
            
            VStack(spacing: 8) {
                // App logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                
                Text(context.state.callerName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(context.state.callDuration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
}

@main
struct CallWidgetBundle: WidgetBundle {
    var body: some Widget {
        CallWidget()
        CallLiveActivity()
    }
}

struct CallWidget: Widget {
    let kind: String = "CallWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CallWidgetEntryView(entry: entry)
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct CallWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Text("Call Widget")
    }
}

struct CallLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CallAttributes.self) { context in
            CallLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text(context.state.callerName)
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.callDuration)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 65, alignment: .trailing)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    // Just a phone button
                    VStack {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                        Text("End")
                            .font(.caption2)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text(context.state.callDuration)
                    .font(.system(size: 14, weight: .medium))
            } minimal: {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
        }
    }
}
```

### 5. Set Up Native Integration in AppDelegate.swift

Add this code to your AppDelegate.swift file:

```swift
import UIKit
import Flutter
import WidgetKit
import ActivityKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set up method channel for Live Activities
        let controller = window?.rootViewController as! FlutterViewController
        let liveActivitiesChannel = FlutterMethodChannel(
            name: "com.duckbuck.app/live_activities",
            binaryMessenger: controller.binaryMessenger)
        
        liveActivitiesChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "areActivitiesSupported":
                if #available(iOS 16.1, *) {
                    result(ActivityAuthorizationInfo().areActivitiesEnabled)
                } else {
                    result(false)
                }
                
            case "startCallActivity":
                guard let args = call.arguments as? [String: Any],
                      let dataString = args["data"] as? String,
                      let data = dataString.data(using: .utf8) else {
                    result(nil)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let callerName = jsonData?["callerName"] as? String,
                          let callDuration = jsonData?["callDuration"] as? String else {
                        result(nil)
                        return
                    }
                    
                    if #available(iOS 16.1, *) {
                        let initialContentState = CallAttributes.ContentState(
                            callerName: callerName,
                            callDuration: callDuration
                        )
                        
                        let activityAttributes = CallAttributes()
                        let activityContent = ActivityContent(state: initialContentState, staleDate: nil)
                        
                        do {
                            let activity = try Activity.request(
                                attributes: activityAttributes,
                                content: activityContent
                            )
                            result(activity.id)
                        } catch {
                            print("Error starting Live Activity: \(error)")
                            result(nil)
                        }
                    } else {
                        result(nil)
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                    result(nil)
                }
                
            case "updateCallActivity":
                guard let args = call.arguments as? [String: Any],
                      let activityId = args["activityId"] as? String,
                      let dataString = args["data"] as? String,
                      let data = dataString.data(using: .utf8) else {
                    result(false)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let callerName = jsonData?["callerName"] as? String,
                          let callDuration = jsonData?["callDuration"] as? String else {
                        result(false)
                        return
                    }
                    
                    if #available(iOS 16.1, *) {
                        Task {
                            for activity in Activity<CallAttributes>.activities {
                                if activity.id == activityId {
                                    let updatedContentState = CallAttributes.ContentState(
                                        callerName: callerName,
                                        callDuration: callDuration
                                    )
                                    
                                    await activity.update(using: updatedContentState)
                                    result(true)
                                    return
                                }
                            }
                            result(false)
                        }
                    } else {
                        result(false)
                    }
                } catch {
                    print("Error updating Live Activity: \(error)")
                    result(false)
                }
                
            case "endCallActivity":
                guard let args = call.arguments as? [String: Any],
                      let activityId = args["activityId"] as? String else {
                    result(false)
                    return
                }
                
                if #available(iOS 16.1, *) {
                    Task {
                        for activity in Activity<CallAttributes>.activities {
                            if activity.id == activityId {
                                await activity.end(dismissalPolicy: .immediate)
                                result(true)
                                return
                            }
                        }
                        result(false)
                    }
                } else {
                    result(false)
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

### 6. Update Info.plist for Both Targets

For both the main app and widget extension, make sure to add:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 7. Build and Test

1. Make sure your app runs on an iOS 16.1+ device
2. Use the DuckBuck app to make a call
3. Press the home button or swipe up to put the app in the background
4. Verify that the Live Activity appears in the Dynamic Island or Lock Screen

## Troubleshooting

- If activities don't appear, check that the app group is correctly configured in both targets
- Make sure you're testing on iOS 16.1+ devices
- Check Xcode logs for any errors related to Activity creation
- Ensure the CallAttributes struct in the widget matches the data sent from Flutter 