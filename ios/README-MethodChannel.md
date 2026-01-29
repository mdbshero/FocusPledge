# iOS MethodChannel Bridge - Implementation Summary

## Overview

This implements the Flutter ↔ iOS MethodChannel bridge for Screen Time API integration.

## Files Created

### Dart Side
- **`lib/services/screen_time_service.dart`**: Flutter service that communicates with iOS via MethodChannel

### Swift Side
- **`ios/Runner/ScreenTimeBridge.swift`**: Core Swift implementation handling Screen Time APIs
- **`ios/Runner/AppDelegate.swift`**: Updated to wire MethodChannel handlers
- **`ios/Runner/Runner.entitlements`**: Entitlements file for FamilyControls and App Groups

## API Methods Implemented

### 1. `requestAuthorization() -> bool`
- Requests FamilyControls authorization from the user
- Async operation that presents system permission dialog
- Returns true if approved

### 2. `getAuthorizationStatus() -> String`
- Returns current authorization status: 'approved', 'denied', or 'notDetermined'

### 3. `presentAppPicker() -> bool`
- Presents FamilyActivityPicker for app selection
- **TODO**: Needs SwiftUI integration for FamilyActivityPicker
- Currently returns placeholder

### 4. `startSession(sessionId, durationMinutes) -> bool`
- Starts a monitoring session
- Writes session data to App Group shared storage
- **TODO**: Schedule DeviceActivity monitoring
- **TODO**: Apply ManagedSettings shields

### 5. `stopSession(sessionId) -> bool`
- Stops an active session
- Clears App Group session data
- **TODO**: Remove ManagedSettings shields
- **TODO**: Cancel DeviceActivity monitoring

### 6. `checkSessionStatus(sessionId) -> Map`
- Polls session status from App Group storage
- Returns:
  - `isActive`: bool - whether session is running
  - `failed`: bool - whether violation detected
  - `reason`: String? - failure reason if failed

### 7. `getAppGroupState() -> Map`
- Debug utility to view App Group shared data
- Returns all session-related keys

## App Group Configuration

**Identifier**: `group.com.focuspledge.shared`

**Shared Keys**:
- `activeSessionId`: Current session ID
- `sessionStartTime`: Unix timestamp when session started
- `sessionDurationMinutes`: Session duration
- `sessionFailed`: Boolean flag set by DeviceActivity extension
- `failureReason`: String describing why session failed

## Usage Example

```dart
final screenTime = ScreenTimeService();

// Request authorization
final authorized = await screenTime.requestAuthorization();

if (authorized) {
  // Start a 60-minute session
  final started = await screenTime.startSession(
    sessionId: 'sess_123',
    durationMinutes: 60,
  );
  
  // Poll for failures
  Timer.periodic(Duration(seconds: 5), (timer) async {
    final status = await screenTime.checkSessionStatus(
      sessionId: 'sess_123',
    );
    
    if (status['failed'] == true) {
      print('Session failed: ${status['reason']}');
      timer.cancel();
    }
  });
}
```

## Next Steps

### Immediate (Sun Feb 15 - App Group Storage)
1. Test App Group data sharing between app and extension
2. Add debug UI to visualize App Group state
3. Implement utilities for reading/writing App Group data

### Near-term (Mon Feb 16 - DeviceActivity Extension)
1. Create DeviceActivity Monitor Extension target
2. Schedule monitoring intervals aligned with session window
3. Handle intervalDidStart/intervalDidEnd callbacks

### Screen Time Integration (Tue Feb 17 onwards)
1. Apply/remove ManagedSettings shields during active sessions
2. Detect violations in DeviceActivity extension
3. Write failure flags to App Group for Flutter polling

## Xcode Configuration Required

### Signing & Capabilities
1. Open `Runner.xcodeproj` in Xcode
2. Select Runner target → Signing & Capabilities
3. Add capabilities:
   - **Family Controls** (requires Apple approval for production)
   - **App Groups**: `group.com.focuspledge.shared`

### Build Settings
- Ensure `Runner.entitlements` is linked in build settings
- iOS Deployment Target: 16.0+ (recommended for Screen Time APIs)

## Testing

### On-Device Testing Required
Screen Time APIs only work on **physical iOS devices**. Simulators will fail authorization.

### Test Checklist
- [ ] Authorization request shows system dialog
- [ ] Authorization status correctly reflects user choice
- [ ] App Group data persists between app launches
- [ ] Session start/stop writes to App Group correctly
- [ ] checkSessionStatus reads App Group data

## Known Limitations

1. **presentAppPicker()** - Placeholder implementation
   - Needs SwiftUI FamilyActivityPicker integration
   - Selection needs to be stored to App Group
   
2. **DeviceActivity Monitoring** - Not yet implemented
   - Needs extension target creation
   - Scheduling logic to be added

3. **ManagedSettings Shielding** - Not yet implemented
   - Shield application/removal logic needed
   - Must respect session active window

## Security Notes

- App Group is sandboxed to app + extensions only
- No sensitive data should be stored in App Group
- Session IDs should be unpredictable (use UUIDs)
- Authorization is per-device, per-user

## References

- [Apple FamilyControls Documentation](https://developer.apple.com/documentation/familycontrols)
- [DeviceActivity Framework](https://developer.apple.com/documentation/deviceactivity)
- [ManagedSettings Framework](https://developer.apple.com/documentation/managedsettings)
- [iOS Native Bridge Spec](../docs/ios-native-bridge-spec.md)
