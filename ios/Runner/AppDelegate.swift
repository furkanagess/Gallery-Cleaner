import AdServices
import Flutter
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase initialization
    FirebaseApp.configure()

    // Notification setup - delegate'i ayarla ama izin isteme (FCMService halledecek)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      // İzin isteğini FCMService'e bırakıyoruz, burada sadece delegate ayarlıyoruz
    } else {
      // iOS 10 öncesi için eski yöntem (artık desteklenmiyor ama yine de)
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }

    application.registerForRemoteNotifications()

    // Firebase Messaging delegate
    Messaging.messaging().delegate = self

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

  // APNS token alındığında FCM'e gönder
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
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

// MARK: - UNUserNotificationCenterDelegate
@available(iOS 10, *)
extension AppDelegate {
  // Foreground notification handler
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📱 [AppDelegate] Notification received in foreground: \(userInfo)")
    
    // iOS 14+ için banner göster
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }

  // Notification'a tıklandığında
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("📱 [AppDelegate] Notification tapped: \(userInfo)")
    completionHandler()
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("📱 [AppDelegate] FCM registration token: \(String(describing: fcmToken))")
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
