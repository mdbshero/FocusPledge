import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

/// DeviceActivity Monitor Extension for FocusPledge.
/// Runs as a separate process managed by iOS. Monitors device usage during pledge sessions
/// and applies/removes ManagedSettings shields based on the session schedule.
///
/// Key callbacks:
/// - intervalDidStart: Called when a monitored interval begins → apply shields
/// - intervalDidEnd: Called when a monitored interval ends → remove shields
/// - eventDidReachThreshold: Called when usage threshold is reached → flag violation
@available(iOS 16.0, *)
class FocusPledgeMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let storage = AppGroupStorage.shared

    /// Called when the monitored interval starts (session begins).
    /// Apply ManagedSettings shields to block selected apps.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        print("[FocusPledgeMonitor] Interval started for activity: \(activity.rawValue)")

        guard let sessionId = storage.getActiveSessionId() else {
            print("[FocusPledgeMonitor] No active session found, skipping shield application")
            return
        }

        print("[FocusPledgeMonitor] Applying shields for session: \(sessionId)")
        applyShields()
    }

    /// Called when the monitored interval ends (session time expired).
    /// Remove shields — the server will handle final settlement.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        print("[FocusPledgeMonitor] Interval ended for activity: \(activity.rawValue)")
        removeShields()
    }

    /// Called when a usage event threshold is reached.
    /// This means the user opened a blocked app → flag as violation.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        print("[FocusPledgeMonitor] ⚠️ Violation detected! Event: \(event.rawValue), Activity: \(activity.rawValue)")

        // Mark session as failed in App Group
        storage.markSessionFailed(
            reason: "app_opened",
            appBundleId: event.rawValue
        )

        // Note: We do NOT remove shields here. The app will detect the failure
        // via polling and call the server to resolve the session.
        // Shields stay until the session officially ends or is resolved.
    }

    /// Called when a warning threshold is reached (if configured).
    override func eventWillReachThresholdWarning(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        print("[FocusPledgeMonitor] Warning: approaching threshold for event: \(event.rawValue)")
    }

    // MARK: - Shield Management

    /// Apply ManagedSettings shields to block selected apps.
    private func applyShields() {
        // Load the saved app selection from App Group
        guard let selectionData = storage.getBlockedAppsSelection() else {
            print("[FocusPledgeMonitor] No blocked apps selection found")
            return
        }

        do {
            let selection = try JSONDecoder().decode(
                FamilyActivitySelection.self,
                from: selectionData
            )

            // Apply shields to selected applications
            store.shield.applications = selection.applicationTokens.isEmpty
                ? nil
                : selection.applicationTokens

            // Apply shields to selected categories
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : ShieldSettings.ActivityCategoryPolicy<Application>.specific(selection.categoryTokens)

            store.shield.webDomainCategories = selection.categoryTokens.isEmpty
                ? nil
                : ShieldSettings.ActivityCategoryPolicy<WebDomain>.specific(selection.categoryTokens)

            print("[FocusPledgeMonitor] Shields applied: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
        } catch {
            print("[FocusPledgeMonitor] Error loading app selection: \(error)")
        }
    }

    /// Remove all ManagedSettings shields.
    private func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        print("[FocusPledgeMonitor] All shields removed")
    }
}
