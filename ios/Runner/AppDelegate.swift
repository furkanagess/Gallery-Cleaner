import AdServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "apple_search_ads",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "getAttributionToken" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self.fetchAttributionToken(result: result)
      }
    }

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  private func fetchAttributionToken(result: @escaping FlutterResult) {
    guard #available(iOS 14.3, *) else {
      result(
        FlutterError(
          code: "NOT_AVAILABLE",
          message: "AdServices framework requires iOS 14.3 or later",
          details: nil
        )
      )
      return
    }

    if #available(iOS 15.0, *) {
      Task {
        do {
          let token = try await AAAttribution.attributionToken()
          DispatchQueue.main.async {
            result(token)
          }
        } catch {
          DispatchQueue.main.async {
            result(nil)
          }
        }
      }
    } else {
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let token = try AAAttribution.attributionToken()
          DispatchQueue.main.async {
            result(token)
          }
        } catch {
          DispatchQueue.main.async {
            result(nil)
          }
        }
      }
    }
  }
}
