import UIKit
import UserNotifications

/// Delegado de aplicación para gestionar el ciclo de vida y la recepción de Device Tokens de APNs.
public final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    public static var shared: AppDelegate?
    
    public var onDeviceTokenReceived: ((String) -> Void)?
    public private(set) var deviceTokenString: String?
    
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AppDelegate.shared = self
        UNUserNotificationCenter.current().delegate = self
        
        // Recuperar token guardado previamente si existe
        if let saved = UserDefaults.standard.string(forKey: "apns_device_token") {
            self.deviceTokenString = saved
        }
        
        return true
    }
    
    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        self.deviceTokenString = token
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        onDeviceTokenReceived?(token)
        NotificationCenter.default.post(name: .didReceiveAPNsToken, object: token)
        print("✅ APNs Device Token registrado: \(token)")
    }
    
    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ Registro APNs no disponible o simulador: \(error.localizedDescription)")
    }
    
    // Permitir ver banners y escuchar sonido de notificación incluso con la app en primer plano
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}

extension Notification.Name {
    public static let didReceiveAPNsToken = Notification.Name("didReceiveAPNsToken")
}
