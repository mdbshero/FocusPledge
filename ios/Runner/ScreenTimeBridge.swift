import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Handles communication between Flutter and iOS Screen Time APIs.
/// Uses AppGroupStorage for data sharing with the DeviceActivity Monitor Extension.
@available(iOS 16.0, *)
class ScreenTimeBridge {
    static let shared = ScreenTimeBridge()

    private let authCenter = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    private let storage = AppGroupStorage.shared
    private let center = DeviceActivityCenter()

    /// The user's selected apps to block during sessions
    var appSelection = FamilyActivitySelection()

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
                print("[ScreenTimeBridge] Authorization request failed: \(error)")
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

    /// Present the FamilyActivityPicker for app selection.
    /// Note: FamilyActivityPicker is SwiftUI-only; returns false until SwiftUI hosting is wired.
    func presentAppPicker(completion: @escaping (Bool) -> Void) {
        print("[ScreenTimeBridge] App picker presentation requested")
        // TODO: Present FamilyActivityPicker via SwiftUI hosting controller
        completion(false)
    }

    /// Save the current app selection to App Group for the extension to use
    func saveAppSelection() {
        do {
            let data = try JSONEncoder().encode(appSelection)
            storage.saveBlockedAppsSelection(data)
            print(
                "[ScreenTimeBridge] Saved app selection: \(appSelection.applicationTokens.count) apps, \(appSelection.categoryTokens.count) categories"
            )
        } catch {
            print("[ScreenTimeBridge] Error saving app selection: \(error)")
        }
    }

    // MARK: - Session Management

    /// Start a monitoring session with Screen Time shielding.
    /// 1. Writes session info to App Group
    /// 2. Schedules DeviceActivity monitoring for the session window
    /// 3. Applies ManagedSettings shields immediately
    func startSession(sessionId: String, durationMinutes: Int) -> Bool {
        guard authCenter.authorizationStatus == .approved else {
            print("[ScreenTimeBridge] Cannot start session: not authorized")
            return false
        }

        let now = Date()
        let endTime = Calendar.current.date(byAdding: .minute, value: durationMinutes, to: now)!

        // 1. Write session state to App Group
        storage.setActiveSession(id: sessionId, startTime: now, endTime: endTime)

        // 2. Save current app selection for the extension
        saveAppSelection()

        // 3. Schedule DeviceActivity monitoring
        let activityName = DeviceActivityName("focuspledge_session_\(sessionId)")

        let startComponents = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: now
        )
        let endComponents = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: endTime
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        // Create events for each blocked app token (1s usage = violation)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for (index, token) in appSelection.applicationTokens.enumerated() {
            let eventName = DeviceActivityEvent.Name("app_violation_\(index)")
            events[eventName] = DeviceActivityEvent(
                applications: [token],
                threshold: DateComponents(second: 1)
            )
        }
        for (index, token) in appSelection.categoryTokens.enumerated() {
            let eventName = DeviceActivityEvent.Name("category_violation_\(index)")
            events[eventName] = DeviceActivityEvent(
                categories: [token],
                threshold: DateComponents(second: 1)
            )
        }

        do {
            try center.startMonitoring(activityName, during: schedule, events: events)
            print(
                "[ScreenTimeBridge] Monitoring started for session: \(sessionId), duration: \(durationMinutes)m"
            )
        } catch {
            print("[ScreenTimeBridge] Error starting monitoring: \(error)")
            // Continue — shields still apply directly
        }

        // 4. Apply shields immediately (don't wait for intervalDidStart callback)
        applyShields()

        print("[ScreenTimeBridge] Session started: \(sessionId) for \(durationMinutes) minutes")
        return true
    }

    /// Stop an active session.
    /// Removes shields, stops monitoring, clears App Group state.
    func stopSession(sessionId: String) -> Bool {
        let activeSessionId = storage.getActiveSessionId()

        guard activeSessionId == sessionId else {
            print(
                "[ScreenTimeBridge] Session mismatch: requested \(sessionId), active is \(activeSessionId ?? "none")"
            )
            return false
        }

        removeShields()

        let activityName = DeviceActivityName("focuspledge_session_\(sessionId)")
        center.stopMonitoring([activityName])

        storage.clearActiveSession()

        print("[ScreenTimeBridge] Session stopped: \(sessionId)")
        return true
    }

    /// Check session status by reading App Group failure flags.
    /// Called by Flutter via polling to detect violations.
    func checkSessionStatus(sessionId: String) -> [String: Any] {
        let activeSessionId = storage.getActiveSessionId()
        let isActive = activeSessionId == sessionId
        let failure = storage.checkSessionFailed()

        return [
            "isActive": isActive,
            "failed": failure.failed,
            "reason": failure.reason ?? NSNull(),
            "failureTimestamp": failure.timestamp?.timeIntervalSince1970 ?? NSNull(),
            "failureAppBundleId": failure.appBundleId ?? NSNull(),
        ]
    }

    /// Get full App Group state for debugging
    func getAppGroupState() -> [String: Any] {
        return storage.getAllState()
    }

    // MARK: - Shield Management

    /// Apply ManagedSettings shields to block selected apps
    private func applyShields() {
        if !appSelection.applicationTokens.isEmpty {
            store.shield.applications = appSelection.applicationTokens
            print("[ScreenTimeBridge] Shielded \(appSelection.applicationTokens.count) apps")
        }

        if !appSelection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings
                .ActivityCategoryPolicy<Application>
                .specific(appSelection.categoryTokens)
            store.shield.webDomainCategories = ShieldSettings
                .ActivityCategoryPolicy<WebDomain>
                .specific(appSelection.categoryTokens)
            print("[ScreenTimeBridge] Shielded \(appSelection.categoryTokens.count) categories")
        }
    }

    /// Remove all ManagedSettings shields
    private func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        store.clearAllSettings()
        print("[ScreenTimeBridge] All shields removed")
    }

    /// Re-apply shielding if there's an active session (for app relaunch scenarios)
    func reconcileOnLaunch() {
        guard let sessionId = storage.getActiveSessionId(),
            let endTime = storage.getSessionEndTime(),
            endTime > Date()
        else {
            // No active session or session expired — clean up
            removeShields()
            return
        }

        print(
            "[ScreenTimeBridge] Reconciling: active session \(sessionId) found, re-applying shields"
        )

        if let selectionData = storage.getBlockedAppsSelection() {
            do {
                appSelection = try JSONDecoder().decode(
                    FamilyActivitySelection.self,
                    from: selectionData
                )
                applyShields()
            } catch {
                print("[ScreenTimeBridge] Error loading saved selection: \(error)")
            }
        }
    }
}
