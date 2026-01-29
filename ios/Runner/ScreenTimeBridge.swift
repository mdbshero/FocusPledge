import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings

/// Handles communication between Flutter and iOS Screen Time APIs
class ScreenTimeBridge {
    static let shared = ScreenTimeBridge()
    
    private let authCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    // Shared app group identifier for extension communication
    private let appGroupIdentifier = "group.com.focuspledge.shared"
    
    private init() {}
    
    // MARK: - Authorization
    
    /// Request FamilyControls authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await authCenter.requestAuthorization(for: .individual)
                let status = authCenter.authorizationStatus
                completion(status == .approved)
            } catch {
                print("Authorization request failed: \(error)")
                completion(false)
            }
        }
    }
    
    /// Get current authorization status
    func getAuthorizationStatus() -> String {
        let status = authCenter.authorizationStatus
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .approved:
            return "approved"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - App Selection
    
    /// Present the FamilyActivityPicker for app selection
    func presentAppPicker(completion: @escaping (Bool) -> Void) {
        // Note: This will be implemented with SwiftUI FamilyActivityPicker
        // For now, return placeholder
        print("App picker presentation requested")
        // TODO: Present FamilyActivityPicker and store selection
        completion(false)
    }
    
    // MARK: - Session Management
    
    /// Start a monitoring session with Screen Time shielding
    func startSession(sessionId: String, durationMinutes: Int) -> Bool {
        guard authCenter.authorizationStatus == .approved else {
            print("Cannot start session: not authorized")
            return false
        }
        
        // Write session info to App Group
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults.set(sessionId, forKey: "activeSessionId")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "sessionStartTime")
            sharedDefaults.set(durationMinutes, forKey: "sessionDurationMinutes")
            sharedDefaults.set(false, forKey: "sessionFailed")
            sharedDefaults.set(nil, forKey: "failureReason")
            sharedDefaults.synchronize()
            
            print("Session started: \(sessionId) for \(durationMinutes) minutes")
            
            // TODO: Schedule DeviceActivity monitoring
            // TODO: Apply ManagedSettings shields
            
            return true
        }
        
        return false
    }
    
    /// Stop an active session
    func stopSession(sessionId: String) -> Bool {
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let activeSessionId = sharedDefaults.string(forKey: "activeSessionId")
            
            guard activeSessionId == sessionId else {
                print("Session mismatch: requested \(sessionId), active is \(activeSessionId ?? "none")")
                return false
            }
            
            // Clear session data
            sharedDefaults.removeObject(forKey: "activeSessionId")
            sharedDefaults.removeObject(forKey: "sessionStartTime")
            sharedDefaults.removeObject(forKey: "sessionDurationMinutes")
            sharedDefaults.removeObject(forKey: "sessionFailed")
            sharedDefaults.removeObject(forKey: "failureReason")
            sharedDefaults.synchronize()
            
            print("Session stopped: \(sessionId)")
            
            // TODO: Remove ManagedSettings shields
            // TODO: Cancel DeviceActivity monitoring
            
            return true
        }
        
        return false
    }
    
    /// Check session status (for polling)
    func checkSessionStatus(sessionId: String) -> [String: Any] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return [
                "isActive": false,
                "failed": false,
                "reason": NSNull()
            ]
        }
        
        let activeSessionId = sharedDefaults.string(forKey: "activeSessionId")
        let sessionFailed = sharedDefaults.bool(forKey: "sessionFailed")
        let failureReason = sharedDefaults.string(forKey: "failureReason")
        
        let isActive = activeSessionId == sessionId
        
        return [
            "isActive": isActive,
            "failed": sessionFailed,
            "reason": failureReason ?? NSNull()
        ]
    }
    
    /// Get App Group state for debugging
    func getAppGroupState() -> [String: Any] {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return ["error": "Cannot access app group"]
        }
        
        let activeSessionId = sharedDefaults.string(forKey: "activeSessionId")
        let sessionStartTime = sharedDefaults.double(forKey: "sessionStartTime")
        let sessionDurationMinutes = sharedDefaults.integer(forKey: "sessionDurationMinutes")
        let sessionFailed = sharedDefaults.bool(forKey: "sessionFailed")
        let failureReason = sharedDefaults.string(forKey: "failureReason")
        
        return [
            "activeSessionId": activeSessionId ?? NSNull(),
            "sessionStartTime": sessionStartTime,
            "sessionDurationMinutes": sessionDurationMinutes,
            "sessionFailed": sessionFailed,
            "failureReason": failureReason ?? NSNull()
        ]
    }
}
