import CallKit
import AVFoundation

class CallKitProvider: NSObject, CXProviderDelegate {
    private let provider: CXProvider
    private let audioSession: AudioSessionService
    private static let shared = CallKitProvider()
    
    private override init() {
        let configuration = CXProviderConfiguration(localizedName: "DuckBuck")
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        
        provider = CXProvider(configuration: configuration)
        audioSession = AudioSessionService.getInstance()
        
        super.init()
        provider.setDelegate(self, queue: nil)
    }
    
    static func getInstance() -> CallKitProvider {
        return shared
    }
    
    func providerDidReset(_ provider: CXProvider) {
        audioSession.endAudioSession()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        audioSession.startAudioSession()
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        audioSession.endAudioSession()
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        audioSession.startAudioSession()
        action.fulfill()
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, completion: ((Error?) -> Void)?) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = false
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                completion?(error)
            } else {
                self.audioSession.startAudioSession()
                completion?(nil)
            }
        }
    }
}