import Foundation

/// Shared App Group storage for communication between the main app and DeviceActivity extension.
/// Both the main app and the extension use the same App Group container.
class AppGroupStorage {
    static let shared = AppGroupStorage()
    private let userDefaults: UserDefaults?

    private init() {
        userDefaults = UserDefaults(suiteName: "group.com.focuspledge.shared")
    }

    // MARK: - Session State

    func setActiveSession(id: String, startTime: Date, endTime: Date) {
        userDefaults?.set(id, forKey: "focuspledge_active_session_id")
        userDefaults?.set(startTime.timeIntervalSince1970, forKey: "focuspledge_session_start_time")
        userDefaults?.set(endTime.timeIntervalSince1970, forKey: "focuspledge_session_end_time")
        userDefaults?.set(false, forKey: "focuspledge_session_failed")
        userDefaults?.removeObject(forKey: "focuspledge_failure_reason")
        userDefaults?.removeObject(forKey: "focuspledge_failure_timestamp")
        userDefaults?.removeObject(forKey: "focuspledge_failure_app_bundle_id")
        userDefaults?.synchronize()
    }

    func getActiveSessionId() -> String? {
        return userDefaults?.string(forKey: "focuspledge_active_session_id")
    }

    func getSessionStartTime() -> Date? {
        guard let timestamp = userDefaults?.double(forKey: "focuspledge_session_start_time"),
            timestamp > 0
        else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getSessionEndTime() -> Date? {
        guard let timestamp = userDefaults?.double(forKey: "focuspledge_session_end_time"),
            timestamp > 0
        else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func clearActiveSession() {
        userDefaults?.removeObject(forKey: "focuspledge_active_session_id")
        userDefaults?.removeObject(forKey: "focuspledge_session_start_time")
        userDefaults?.removeObject(forKey: "focuspledge_session_end_time")
        userDefaults?.removeObject(forKey: "focuspledge_session_failed")
        userDefaults?.removeObject(forKey: "focuspledge_failure_reason")
        userDefaults?.removeObject(forKey: "focuspledge_failure_timestamp")
        userDefaults?.removeObject(forKey: "focuspledge_failure_app_bundle_id")
        userDefaults?.synchronize()
    }

    // MARK: - Failure Detection

    func markSessionFailed(reason: String, appBundleId: String? = nil) {
        userDefaults?.set(true, forKey: "focuspledge_session_failed")
        userDefaults?.set(reason, forKey: "focuspledge_failure_reason")
        userDefaults?.set(Date().timeIntervalSince1970, forKey: "focuspledge_failure_timestamp")
        if let bundleId = appBundleId {
            userDefaults?.set(bundleId, forKey: "focuspledge_failure_app_bundle_id")
        }
        userDefaults?.synchronize()
    }

    func checkSessionFailed() -> (
        failed: Bool, reason: String?, timestamp: Date?, appBundleId: String?
    ) {
        let failed = userDefaults?.bool(forKey: "focuspledge_session_failed") ?? false
        let reason = userDefaults?.string(forKey: "focuspledge_failure_reason")
        let timestamp = userDefaults?.double(forKey: "focuspledge_failure_timestamp")
        let appBundleId = userDefaults?.string(forKey: "focuspledge_failure_app_bundle_id")

        let date =
            timestamp != nil && timestamp! > 0 ? Date(timeIntervalSince1970: timestamp!) : nil
        return (failed, reason, date, appBundleId)
    }

    // MARK: - Blocked Apps Selection

    @available(iOS 16.0, *)
    func saveBlockedAppsSelection(_ selection: Data) {
        userDefaults?.set(selection, forKey: "focuspledge_blocked_apps_selection")
        userDefaults?.synchronize()
    }

    @available(iOS 16.0, *)
    func getBlockedAppsSelection() -> Data? {
        return userDefaults?.data(forKey: "focuspledge_blocked_apps_selection")
    }

    // MARK: - Debug / Status

    func getAllState() -> [String: Any] {
        return [
            "activeSessionId": userDefaults?.string(forKey: "focuspledge_active_session_id")
                ?? NSNull(),
            "sessionStartTime": userDefaults?.double(forKey: "focuspledge_session_start_time") ?? 0,
            "sessionEndTime": userDefaults?.double(forKey: "focuspledge_session_end_time") ?? 0,
            "sessionFailed": userDefaults?.bool(forKey: "focuspledge_session_failed") ?? false,
            "failureReason": userDefaults?.string(forKey: "focuspledge_failure_reason") ?? NSNull(),
            "failureTimestamp": userDefaults?.double(forKey: "focuspledge_failure_timestamp") ?? 0,
            "failureAppBundleId": userDefaults?.string(forKey: "focuspledge_failure_app_bundle_id")
                ?? NSNull(),
            "hasBlockedAppsSelection": userDefaults?.data(
                forKey: "focuspledge_blocked_apps_selection") != nil,
        ]
    }
}
