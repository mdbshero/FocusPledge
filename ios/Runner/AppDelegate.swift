import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let screenTimeChannel = "com.focuspledge/screen_time"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Set up MethodChannel for Screen Time communication
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: screenTimeChannel,
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call: call, result: result)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let bridge = ScreenTimeBridge.shared
    
    switch call.method {
    case "requestAuthorization":
      bridge.requestAuthorization { authorized in
        result(authorized)
      }
      
    case "getAuthorizationStatus":
      let status = bridge.getAuthorizationStatus()
      result(status)
      
    case "presentAppPicker":
      bridge.presentAppPicker { success in
        result(success)
      }
      
    case "startSession":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let durationMinutes = args["durationMinutes"] as? Int else {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing sessionId or durationMinutes",
          details: nil
        ))
        return
      }
      let success = bridge.startSession(sessionId: sessionId, durationMinutes: durationMinutes)
      result(success)
      
    case "stopSession":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String else {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing sessionId",
          details: nil
        ))
        return
      }
      let success = bridge.stopSession(sessionId: sessionId)
      result(success)
      
    case "checkSessionStatus":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String else {
        result(FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing sessionId",
          details: nil
        ))
        return
      }
      let status = bridge.checkSessionStatus(sessionId: sessionId)
      result(status)
      
    case "getAppGroupState":
      let state = bridge.getAppGroupState()
      result(state)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
