import Foundation
import TrustKit

/// A manager class responsible for handling certificate pinning in the application
class CertificatePinningManager {
    
    // Singleton instance
    static let shared = CertificatePinningManager()
    
    // Private initializer for singleton pattern
    private init() {}
    
    /// Configures and initializes TrustKit with the appropriate certificate pins
    func setupCertificatePinning() {
        // TrustKit configuration
        let trustKitConfig: [String: Any] = [
            kTSKSwizzleNetworkDelegates: true,
            kTSKPinnedDomains: [
                // Google APIs
                "googleapis.com": [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKPublicKeyAlgorithms: [kTSKAlgorithmRsa2048],
                    kTSKPublicKeyHashes: [
                        // Primary pin (leaf certificate) - extracted on May 17, 2025
                        "jYoTE/KICxVmNXPlhLcgJpD0FwK1sNupYdQSJg4RDos=",
                        // Backup pin (intermediate certificate) - for certificate rotation
                        "YPtHaftLw6/0vnc2BnNKGF54xiCA28WFcccjkA4ypCM="
                    ]
                ],
                // Firestore
                "firestore.googleapis.com": [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKPublicKeyAlgorithms: [kTSKAlgorithmRsa2048],
                    kTSKPublicKeyHashes: [
                        // Primary pin (leaf certificate) - extracted on May 17, 2025
                        "jYoTE/KICxVmNXPlhLcgJpD0FwK1sNupYdQSJg4RDos=",
                        // Backup pin (intermediate certificate) - for certificate rotation
                        "YPtHaftLw6/0vnc2BnNKGF54xiCA28WFcccjkA4ypCM="
                    ]
                ],
                // Firebase Storage
                "firebasestorage.googleapis.com": [
                    kTSKIncludeSubdomains: true,
                    kTSKEnforcePinning: true,
                    kTSKDisableDefaultReportUri: true,
                    kTSKPublicKeyAlgorithms: [kTSKAlgorithmRsa2048],
                    kTSKPublicKeyHashes: [
                        // Primary pin (leaf certificate) - extracted on May 17, 2025
                        "jYoTE/KICxVmNXPlhLcgJpD0FwK1sNupYdQSJg4RDos=",
                        // Backup pin (intermediate certificate) - for certificate rotation
                        "YPtHaftLw6/0vnc2BnNKGF54xiCA28WFcccjkA4ypCM="
                    ]
                ]
            ]
        ]
        
        TrustKit.initSharedInstance(withConfiguration: trustKitConfig)
        
        // Set up notification center to listen for pin validation failures
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handleTrustKitValidationError(notification:)),
                                              name: NSNotification.Name(kTSKValidationErrorNotification),
                                              object: nil)
    }
    
    /// Handler for TrustKit pin validation failure notifications
    @objc private func handleTrustKitValidationError(notification: Notification) {
        guard let info = notification.userInfo else { return }
        
        // Extract information about the validation failure
        if let domain = info[kTSKValidationErrorDomain] as? String,
           let error = info[kTSKValidationErrorErrorKey] as? Error {
            // Handle the validation failure
            handlePinValidationFailure(for: domain, error: error)
        }
    }
    
    /// Process certificate validation failures
    private func handlePinValidationFailure(for domain: String, error: Error) {
        // Log the validation failure
        print("Certificate pinning validation failed for domain: \(domain)")
        print("Error: \(error.localizedDescription)")
        
        // Here you can implement additional error handling like:
        // - Send analytics event
        // - Show a security alert to the user
        // - Log the event to a security monitoring service
        
        // Example: Display an alert on the main thread
        DispatchQueue.main.async {
            // Alert could be shown here, but would require UIKit and a reference to the root view controller
            // This is just a placeholder for where you would implement your own error handling
        }
    }
}
