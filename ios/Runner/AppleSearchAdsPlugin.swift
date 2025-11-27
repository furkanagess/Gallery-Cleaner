import Flutter
import UIKit
import AdServices

/// Flutter plugin for Apple Search Ads attribution
///
/// This plugin retrieves the attribution token from Apple's AdServices framework
/// and makes it available to Flutter code for RevenueCat integration.
@objc public class AppleSearchAdsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "apple_search_ads",
      binaryMessenger: registrar.messenger()
    )
    let instance = AppleSearchAdsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAttributionToken":
      getAttributionToken(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Get attribution token from AdServices framework
  ///
  /// This method retrieves the attribution token from Apple's AdServices framework.
  /// The token is only available if the user clicked on an Apple Search Ad.
  /// If no token is available (user didn't click an ad), returns null.
  private func getAttributionToken(result: @escaping FlutterResult) {
    // Check if AdServices framework is available (iOS 14.3+)
    if #available(iOS 14.3, *) {
      // Get attribution token asynchronously
      // This is the recommended way to get the token
      if #available(iOS 15.0, *) {
        // iOS 15+ method
        Task {
          do {
            let attributionToken = try await AAAttribution.attributionToken()
            DispatchQueue.main.async {
              result(attributionToken)
            }
          } catch {
            // No attribution token available (user didn't click an ad)
            // This is normal and not an error
            DispatchQueue.main.async {
              result(nil)
            }
          }
        }
      } else {
        // iOS 14.3-14.x method (deprecated but still works)
        var attributionToken: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            attributionToken = try AAAttribution.attributionToken()
          } catch {
            // No attribution token available
            attributionToken = nil
          }
          semaphore.signal()
        }
        
        // Wait for result with timeout (5 seconds)
        let timeoutResult = semaphore.wait(timeout: .now() + 5.0)
        
        if timeoutResult == .timedOut {
          result(FlutterError(
            code: "TIMEOUT",
            message: "Attribution token request timed out",
            details: nil
          ))
        } else {
          result(attributionToken)
        }
      }
    } else {
      // AdServices framework not available (iOS < 14.3)
      result(FlutterError(
        code: "NOT_AVAILABLE",
        message: "AdServices framework requires iOS 14.3 or later",
        details: nil
      ))
    }
  }
}

