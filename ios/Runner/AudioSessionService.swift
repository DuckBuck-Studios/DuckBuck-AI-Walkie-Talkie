import CallKit
import AVFoundation

class AudioSessionService: NSObject {
    private let callController = CXCallController()
    private static let shared = AudioSessionService()
    
    private override init() {
        super.init()
        configureAudioSession()
    }
    
    static func getInstance() -> AudioSessionService {
        return shared
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func startAudioSession() {
        let callUpdate = CXCallUpdate()
        callUpdate.hasVideo = false
        callUpdate.remoteHandle = CXHandle(type: .generic, value: "DuckBuck Call")
        
        let uuid = UUID()
        let startCallAction = CXStartCallAction(call: uuid, handle: callUpdate.remoteHandle!)
        let transaction = CXTransaction(action: startCallAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Call started successfully")
            }
        }
    }
    
    func endAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}