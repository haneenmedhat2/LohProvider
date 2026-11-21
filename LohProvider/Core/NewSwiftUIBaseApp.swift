import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    @MainActor static var pendingNotificationDestination: MerchantNotificationDestination?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("[FCM] Notification permission request failed: \(error.localizedDescription)")
            } else {
                print("[FCM] Notification permission granted: \(granted)")
            }
        }
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("[FCM] APNs registration succeeded; requesting FCM token")
        fetchFCMToken()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[FCM] APNs registration failed: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else {
            print("[FCM] Registration token is unavailable")
            return
        }
        UserDefaults.pushNotificationToken = fcmToken
        print("[FCM] Registration token: \(fcmToken)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NotificationCenter.default.post(name: .notificationsShouldRefresh, object: nil)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let destination = MerchantNotificationDestination.fromPush(response.notification.request.content.userInfo)
        Task { @MainActor in
            Self.pendingNotificationDestination = destination
            NotificationCenter.default.post(name: .pushDidTap, object: destination)
            completionHandler()
        }
    }

    private func fetchFCMToken() {
        Messaging.messaging().token { token, error in
            if let error {
                print("[FCM] Failed to fetch registration token: \(error.localizedDescription)")
                return
            }
            guard let token, !token.isEmpty else {
                print("[FCM] Registration token is unavailable")
                return
            }
            UserDefaults.pushNotificationToken = token
            print("[FCM] Registration token: \(token)")
        }
    }
}

@main
struct NewSwiftUIBaseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var language = AppLanguageManager.shared

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.locale, Locale(identifier: language.selectedLanguage))
                .environment(\.layoutDirection, language.layoutDirection)
                .preferredColorScheme(.light)
                .onAppear { language.refreshSystemLanguage() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { language.refreshSystemLanguage() }
                }
        }
    }
}
