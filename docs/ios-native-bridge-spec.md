# iOS Native Bridge Specification — Flutter ↔ Screen Time Integration

**Document purpose:** Technical specification for the Flutter ↔ iOS Swift bridge that enables Screen Time enforcement during pledge sessions, with robust failure detection and server reconciliation.

**Last updated:** February 17, 2026

**Implementation status:** ✅ Fully implemented — MethodChannel bridge, App Group storage, DeviceActivity Monitor extension, ManagedSettings shielding, and Flutter failure polling all complete and building successfully.

---

## Overview

FocusPledge's core mechanic—blocking distracting apps during pledge sessions—requires iOS Screen Time APIs (`FamilyControls`, `DeviceActivity`, `ManagedSettings`). These APIs are **Swift-only** and cannot be called directly from Flutter/Dart.

This spec defines:

1. **MethodChannel API** for Flutter → Swift calls
2. **App Group shared storage** for Swift extension → Flutter app communication
3. **Polling mechanism** for Flutter to detect native failure events
4. **State reconciliation** to ensure server-side settlement even if app is terminated

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App (Dart)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Session UI: Start pledge → Call startSession()          │  │
│  │             ↓                                              │  │
│  │  MethodChannel.invokeMethod("startNativeSession", ...)   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │ MethodChannel
┌────────────────────────────┴────────────────────────────────────┐
│                   iOS Host App (Swift)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  NativeBridge.swift:                                      │  │
│  │   - Apply ManagedSettings shields                         │  │
│  │   - Schedule DeviceActivity monitoring                    │  │
│  │   - Write session state to App Group                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │ App Group Shared Container
┌────────────────────────────┴────────────────────────────────────┐
│           DeviceActivity Monitor Extension (Swift)              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Detects violations (user opens blocked app):            │  │
│  │   - Write failure flag to App Group                       │  │
│  │   - Record violation metadata (timestamp, app ID)        │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │ App Group Shared Container
┌────────────────────────────┴────────────────────────────────────┐
│                    Flutter App Polling Loop                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Every 5s: MethodChannel.invokeMethod("checkSessionStatus")│
│  │            ↓                                              │  │
│  │  Read App Group → Detect failure flag                    │  │
│  │            ↓                                              │  │
│  │  Call Cloud Function: resolveSession(FAILURE)            │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## App Group Configuration

### Purpose

App Groups enable data sharing between:

- Main Flutter app (host)
- DeviceActivity Monitor Extension

Without App Groups, extensions cannot communicate state back to the app.

### Setup (Xcode)

1. **Add App Group capability:**
   - Target: Runner (main app)
   - Capability: App Groups
   - Identifier: `group.com.focuspledge.shared`

2. **Add App Group to Extension:**
   - Target: DeviceActivityMonitor (extension)
   - Capability: App Groups
   - Identifier: `group.com.focuspledge.shared` (same)

3. **Entitlements files:**
   - `Runner/Runner.entitlements` and `DeviceActivityMonitor/DeviceActivityMonitor.entitlements` should both include:
     ```xml
     <key>com.apple.security.application-groups</key>
     <array>
       <string>group.com.focuspledge.shared</string>
     </array>
     ```

### Shared Storage Keys

All keys are prefixed with `focuspledge_` to avoid collisions.

| Key                                 | Type               | Purpose                                     | Writer    | Reader              |
| ----------------------------------- | ------------------ | ------------------------------------------- | --------- | ------------------- |
| `focuspledge_active_session_id`     | String             | Current active session ID                   | Host app  | Extension, Host app |
| `focuspledge_session_start_time`    | Double (timestamp) | Session start time (Unix epoch)             | Host app  | Extension, Host app |
| `focuspledge_session_end_time`      | Double             | Session expected end time                   | Host app  | Extension, Host app |
| `focuspledge_session_failed`        | Bool               | Failure flag                                | Extension | Host app            |
| `focuspledge_failure_reason`        | String             | Reason (e.g., "app_opened", "no_heartbeat") | Extension | Host app            |
| `focuspledge_failure_timestamp`     | Double             | When failure occurred                       | Extension | Host app            |
| `focuspledge_failure_app_bundle_id` | String             | Blocked app that was opened                 | Extension | Host app            |
| `focuspledge_blocked_apps_tokens`   | Data               | Serialized FamilyActivitySelection          | Host app  | Extension           |

### Swift Helper Class

```swift
import Foundation

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
        userDefaults?.synchronize()
    }

    func getActiveSessionId() -> String? {
        return userDefaults?.string(forKey: "focuspledge_active_session_id")
    }

    func getSessionEndTime() -> Date? {
        guard let timestamp = userDefaults?.double(forKey: "focuspledge_session_end_time"),
              timestamp > 0 else { return nil }
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

    func checkSessionFailed() -> (failed: Bool, reason: String?, timestamp: Date?, appBundleId: String?) {
        let failed = userDefaults?.bool(forKey: "focuspledge_session_failed") ?? false
        let reason = userDefaults?.string(forKey: "focuspledge_failure_reason")
        let timestamp = userDefaults?.double(forKey: "focuspledge_failure_timestamp")
        let appBundleId = userDefaults?.string(forKey: "focuspledge_failure_app_bundle_id")

        let date = timestamp != nil && timestamp! > 0 ? Date(timeIntervalSince1970: timestamp!) : nil
        return (failed, reason, date, appBundleId)
    }

    // MARK: - Blocked Apps

    func saveBlockedAppsTokens(_ data: Data) {
        userDefaults?.set(data, forKey: "focuspledge_blocked_apps_tokens")
        userDefaults?.synchronize()
    }

    func getBlockedAppsTokens() -> Data? {
        return userDefaults?.data(forKey: "focuspledge_blocked_apps_tokens")
    }
}
```

---

## MethodChannel API

### Channel Name

`"com.focuspledge/screen_time"`

> **Note:** Originally specified as `com.focuspledge.native_bridge` — implemented as `com.focuspledge/screen_time` for clarity.

### Methods

#### 1. `requestAuthorization`

**Purpose:** Request Screen Time authorization from the user.

**Parameters:** None

**Returns:**

```dart
{
  "authorized": bool,
  "error": String? // if authorization failed
}
```

**Swift Implementation:**

```swift
import FamilyControls

func requestAuthorization(result: @escaping FlutterResult) {
    Task {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            result(["authorized": true])
        } catch {
            result(["authorized": false, "error": error.localizedDescription])
        }
    }
}
```

---

#### 2. `getAuthorizationStatus`

**Purpose:** Check current authorization status without prompting.

**Parameters:** None

**Returns:**

```dart
{
  "status": String // "authorized" | "denied" | "notDetermined"
}
```

**Swift Implementation:**

```swift
func getAuthorizationStatus(result: FlutterResult) {
    let status = AuthorizationCenter.shared.authorizationStatus
    let statusString: String
    switch status {
    case .approved:
        statusString = "authorized"
    case .denied:
        statusString = "denied"
    case .notDetermined:
        statusString = "notDetermined"
    @unknown default:
        statusString = "unknown"
    }
    result(["status": statusString])
}
```

---

#### 3. `presentAppPicker`

**Purpose:** Show FamilyActivityPicker to let user select apps to block.

**Parameters:** None

**Returns:**

```dart
{
  "selected": bool,
  "count": int // number of apps selected
}
```

**Swift Implementation:**

```swift
import FamilyControls
import SwiftUI

func presentAppPicker(result: @escaping FlutterResult) {
    // Present picker modally from root view controller
    let pickerView = FamilyActivityPickerView { selection in
        // Save selection to App Group
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: selection, requiringSecureCoding: true) {
            AppGroupStorage.shared.saveBlockedAppsTokens(data)
        }
        result(["selected": true, "count": selection.applicationTokens.count])
    }

    // Present using UIHostingController
    let hostingController = UIHostingController(rootView: pickerView)
    if let rootVC = UIApplication.shared.windows.first?.rootViewController {
        rootVC.present(hostingController, animated: true)
    }
}
```

---

#### 4. `startNativeSession`

**Purpose:** Begin monitoring and apply shields for a pledge session.

**Parameters:**

```dart
{
  "sessionId": String,
  "durationMinutes": int
}
```

**Returns:**

```dart
{
  "success": bool,
  "error": String?
}
```

**Swift Implementation:**

```swift
import DeviceActivity
import ManagedSettings

func startNativeSession(sessionId: String, durationMinutes: Int, result: @escaping FlutterResult) {
    let startTime = Date()
    let endTime = startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))

    // Save session state to App Group
    AppGroupStorage.shared.setActiveSession(id: sessionId, startTime: startTime, endTime: endTime)

    // Load blocked apps selection
    guard let tokensData = AppGroupStorage.shared.getBlockedAppsTokens(),
          let selection = try? NSKeyedUnarchiver.unarchivedObject(ofClass: FamilyActivitySelection.self, from: tokensData) else {
        result(["success": false, "error": "No blocked apps selected"])
        return
    }

    // Apply shields (ManagedSettings)
    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens
    store.shield.applicationCategories = .all // optional: block entire categories

    // Start DeviceActivity monitoring
    let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(calendar: .current, hour: startTime.hour, minute: startTime.minute),
        intervalEnd: DateComponents(calendar: .current, hour: endTime.hour, minute: endTime.minute),
        repeats: false
    )

    let activityName = DeviceActivityName("focuspledge_\(sessionId)")
    let center = DeviceActivityCenter()

    do {
        try center.startMonitoring(activityName, during: schedule)
        result(["success": true])
    } catch {
        result(["success": false, "error": error.localizedDescription])
    }
}
```

**Notes:**

- `ManagedSettings` applies shields immediately
- `DeviceActivity` monitoring triggers extension callbacks when interval starts/ends or violation occurs

---

#### 5. `stopNativeSession`

**Purpose:** Remove shields and stop monitoring when session ends (success or manually stopped).

**Parameters:**

```dart
{
  "sessionId": String
}
```

**Returns:**

```dart
{
  "success": bool
}
```

**Swift Implementation:**

```swift
func stopNativeSession(sessionId: String, result: FlutterResult) {
    // Remove shields
    let store = ManagedSettingsStore()
    store.shield.applications = nil
    store.shield.applicationCategories = nil

    // Stop monitoring
    let activityName = DeviceActivityName("focuspledge_\(sessionId)")
    let center = DeviceActivityCenter()
    center.stopMonitoring([activityName])

    // Clear App Group state
    AppGroupStorage.shared.clearActiveSession()

    result(["success": true])
}
```

---

#### 6. `checkSessionStatus`

**Purpose:** Poll for native failure events (used by Flutter every 5s during active session).

**Parameters:**

```dart
{
  "sessionId": String
}
```

**Returns:**

```dart
{
  "failed": bool,
  "reason": String?,
  "timestamp": int?, // Unix timestamp (milliseconds)
  "appBundleId": String?
}
```

**Swift Implementation:**

```swift
func checkSessionStatus(sessionId: String, result: FlutterResult) {
    let status = AppGroupStorage.shared.checkSessionFailed()

    result([
        "failed": status.failed,
        "reason": status.reason as Any,
        "timestamp": status.timestamp?.timeIntervalSince1970 ?? 0,
        "appBundleId": status.appBundleId as Any
    ])
}
```

---

#### 7. `getAppGroupState` (Debug Only)

**Purpose:** Dump all App Group keys for debugging.

**Parameters:** None

**Returns:**

```dart
{
  "state": Map<String, dynamic>
}
```

---

## DeviceActivity Monitor Extension

### Extension Target Setup

1. Add new target: **File → New → Target → Device Activity Monitor Extension**
2. Name: `DeviceActivityMonitor`
3. Add App Group entitlement (same as host app)

### Extension Class

```swift
import DeviceActivity
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    // Called when monitoring interval starts
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Session monitoring has started
        // Optionally log or set a flag
    }

    // Called when monitoring interval ends
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Session monitoring has ended (time expired)
        // Remove shields in host app via stopNativeSession
    }

    // Called when user attempts to use a shielded app
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // User violated session by opening blocked app
        // Write failure to App Group
        AppGroupStorage.shared.markSessionFailed(
            reason: "app_opened",
            appBundleId: nil // Unfortunately, bundle ID not available in this callback
        )
    }
}
```

**Important limitation:** Apple does not provide the specific app bundle ID in the violation callback. We only know _that_ a violation occurred, not _which_ app.

### Alternative: ShieldActionExtension (Optional)

If you want to capture which app was opened, use a **ShieldActionExtension**:

```swift
import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {

        // User tapped on a shielded app
        // Log violation with app token (can be mapped to bundle ID)

        AppGroupStorage.shared.markSessionFailed(
            reason: "app_opened",
            appBundleId: application.bundleIdentifier // if available
        )

        // Return .none to keep shield active (user cannot bypass)
        completionHandler(.none)
    }
}
```

---

## Flutter Polling Loop

### Purpose

Since extensions cannot directly call Cloud Functions or make network requests, the Flutter app polls App Group state and triggers server settlement.

### Implementation (Dart)

```dart
import 'package:flutter/services.dart';
import 'dart:async';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.focuspledge.native_bridge');

  Timer? _pollingTimer;
  String? _activeSessionId;

  /// Start polling for native failure during active session
  void startPolling(String sessionId) {
    _activeSessionId = sessionId;
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _checkAndHandleFailure(sessionId);
    });
  }

  /// Stop polling when session ends
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activeSessionId = null;
  }

  /// Check App Group for failure flag and trigger settlement
  Future<void> _checkAndHandleFailure(String sessionId) async {
    try {
      final result = await _channel.invokeMethod('checkSessionStatus', {
        'sessionId': sessionId,
      });

      final failed = result['failed'] as bool;
      if (failed) {
        final reason = result['reason'] as String?;
        final timestamp = result['timestamp'] as int?;
        final appBundleId = result['appBundleId'] as String?;

        print('Native failure detected: $reason at $timestamp');

        // Stop polling
        stopPolling();

        // Call server to settle session
        await _settleSessionOnServer(
          sessionId: sessionId,
          resolution: 'FAILURE',
          reason: reason ?? 'native_violation',
          nativeEvidence: {
            'timestamp': timestamp,
            'appBundleId': appBundleId,
          },
        );
      }
    } catch (e) {
      print('Error checking session status: $e');
    }
  }

  /// Call Cloud Function to settle session
  Future<void> _settleSessionOnServer({
    required String sessionId,
    required String resolution,
    required String reason,
    Map<String, dynamic>? nativeEvidence,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable('resolveSession');

    await callable.call({
      'sessionId': sessionId,
      'resolution': resolution,
      'idempotencyKey': 'flutter_${sessionId}_${DateTime.now().millisecondsSinceEpoch}',
      'reason': reason,
      'nativeEvidence': nativeEvidence,
    });

    print('Session settled: $sessionId as $resolution');
  }
}
```

### Usage in Session Screen

```dart
class ActiveSessionScreen extends StatefulWidget {
  final String sessionId;

  @override
  _ActiveSessionScreenState createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  final _nativeBridge = NativeBridge();

  @override
  void initState() {
    super.initState();

    // Start native session
    _startNativeSession();

    // Start polling for failures
    _nativeBridge.startPolling(widget.sessionId);
  }

  Future<void> _startNativeSession() async {
    await MethodChannel('com.focuspledge.native_bridge').invokeMethod('startNativeSession', {
      'sessionId': widget.sessionId,
      'durationMinutes': 60,
    });
  }

  @override
  void dispose() {
    _nativeBridge.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Focus Session Active')),
      body: Center(child: Text('Stay focused!')),
    );
  }
}
```

---

## Resilience & Edge Cases

### 1. App Termination During Session

**Scenario:** User force-quits app or iOS terminates it.

**Solution:**

- App Group state persists (session still active)
- On app relaunch, read `focuspledge_active_session_id`
- If session ID exists and hasn't expired, resume polling
- If session failed while app was dead, detect on relaunch and settle

**Implementation:**

```dart
// In app initialization
Future<void> checkForActiveSession() async {
  final sessionId = await _nativeBridge.getActiveSessionId();
  if (sessionId != null) {
    // Check if failed
    final status = await _nativeBridge.checkSessionStatus(sessionId);
    if (status['failed']) {
      await _settleFailedSession(sessionId, status);
    } else {
      // Resume polling
      _nativeBridge.startPolling(sessionId);
    }
  }
}
```

---

### 2. Device Reboot During Session

**Scenario:** iOS reboots while session is active.

**Behavior:**

- ManagedSettings shields persist across reboots (iOS enforces them)
- DeviceActivity monitoring is restarted by iOS
- App Group state persists

**Solution:**

- Same as app termination: on relaunch, reconcile state

---

### 3. Time Zone Changes

**Scenario:** User travels and changes time zone mid-session.

**Mitigation:**

- Store `session_end_time` as Unix timestamp (UTC)
- DeviceActivity schedules use local time, but we validate end time server-side

---

### 4. No Heartbeat (Stale Session)

**Scenario:** User never reopens app, heartbeat stops.

**Solution:**

- Server-side scheduled job finds sessions with stale `native.lastCheckedAt`
- Auto-resolves as `FAILURE` with reason `no_heartbeat`
- On next app open, Flutter detects server-side settlement and updates UI

---

## Testing Checklist

### Manual Tests (On-Device Required)

| Test Case               | Steps                               | Expected Result                                           |
| ----------------------- | ----------------------------------- | --------------------------------------------------------- |
| Authorization flow      | Call `requestAuthorization`         | iOS prompt appears, returns `authorized: true`            |
| App picker              | Call `presentAppPicker`             | FamilyActivityPicker shows, saves selection               |
| Start session           | Call `startNativeSession`           | Shields apply immediately, DeviceActivity starts          |
| Open blocked app        | During session, tap blocked app     | iOS shield UI appears, violation detected in App Group    |
| Polling detects failure | Flutter polls every 5s              | `checkSessionStatus` returns `failed: true`               |
| Server settlement       | After failure detected              | `resolveSession(FAILURE)` called, credits burned          |
| Stop session            | Call `stopNativeSession`            | Shields removed, monitoring stopped                       |
| App termination         | Force-quit app during session       | On relaunch, failure is detected and settled              |
| Time expiry             | Wait for session duration to elapse | Extension `intervalDidEnd` called, session ends naturally |

---

## Known Limitations

1. **Extension cannot make network calls:** Extensions are heavily restricted. No direct Cloud Function calls. Must use App Group → polling pattern.

2. **No bundle ID in violation callback:** `eventDidReachThreshold` doesn't provide the specific app. Consider using ShieldActionExtension for more granular logging.

3. **DeviceActivity scheduling quirks:** If session spans midnight, may need to split into two monitoring intervals.

4. **Authorization is per-user:** Screen Time authorization cannot be programmatically revoked. User must manually revoke in Settings.

5. **Simulator limitations:** DeviceActivity and ManagedSettings do not work in iOS Simulator. **Physical device required** for testing.

---

## Implementation Priority

### Phase 1: Minimal Viable Native Bridge

1. ✅ App Group setup
2. ✅ `requestAuthorization` + `getAuthorizationStatus`
3. ✅ `presentAppPicker` with selection persistence
4. ✅ `startNativeSession` with basic shielding
5. ✅ `checkSessionStatus` polling
6. ✅ DeviceActivity extension with violation detection

### Phase 2: Resilience

7. App relaunch reconciliation
8. Server-side expiry job integration
9. Edge case testing (reboot, time zone, etc.)

### Phase 3: Polish

10. Better error messages
11. ShieldActionExtension for granular app logging
12. Analytics/telemetry for native events

---

## Security Considerations

1. **App Group data is user-accessible:** Do not store sensitive tokens or secrets in App Group. Only store session state and failure flags.

2. **Validate session IDs server-side:** When settling a session, always validate the session belongs to the authenticated user.

3. **Replay protection:** Use idempotency keys when calling `resolveSession` from Flutter.

4. **Shield persistence:** ManagedSettings shields persist until explicitly removed. Always call `stopNativeSession` on success or failure.

---

## Summary

This native bridge specification provides:

- ✅ **MethodChannel API** for all Screen Time operations
- ✅ **App Group storage** for extension ↔ app communication
- ✅ **Polling mechanism** to detect violations
- ✅ **Resilience patterns** for app termination and edge cases
- ✅ **Testing strategy** for on-device validation

Implementation can proceed with confidence that the design handles iOS restrictions and provides robust failure detection aligned with server-authoritative settlement.
