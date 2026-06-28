import UIKit
import SwiftUI
import GoogleSignIn
import UniformTypeIdentifiers
import UserNotifications

extension Notification.Name {
    static let shokoFormsOpenFileURL = Notification.Name("shokoFormsOpenFileURL")
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    private static var pendingOpenFileURLs: [URL] = []
    private static var pendingReminderDocumentIDs: [UUID] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        FormReminderNotificationService.shared.registerNotificationCategories()
        if let url = launchOptions?[.url] as? URL {
            _ = Self.handleOpenURL(url)
        }

        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let documentID = FormReminderNotificationService.pendingDocumentID(from: response) {
            Self.queueReminderDocumentID(documentID)
        }
        completionHandler()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }

        return Self.handleOpenURL(url)
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    static func handleOpenURL(_ url: URL) -> Bool {
        guard Self.canOpenFileURL(url) else {
            return false
        }

        Self.queueOpenFileURL(url)
        return true
    }

    private static func canOpenFileURL(_ url: URL) -> Bool {
        if url.scheme == "shokoforms" {
            return true
        }
        let extensionName = url.pathExtension.lowercased()
        if ["shokoform", "shokobackup", "json"].contains(extensionName) {
            return true
        }
        let type = UTType(filenameExtension: extensionName)
        return type?.conforms(to: .pdf) == true || type?.conforms(to: .image) == true
    }

    static func consumePendingOpenFileURLs() -> [URL] {
        let urls = pendingOpenFileURLs
        pendingOpenFileURLs.removeAll()
        return urls
    }

    static func consumePendingReminderDocumentIDs() -> [UUID] {
        let ids = pendingReminderDocumentIDs
        pendingReminderDocumentIDs.removeAll()
        return ids
    }

    private static func queueOpenFileURL(_ url: URL) {
        pendingOpenFileURLs.append(url)
        NotificationCenter.default.post(name: .shokoFormsOpenFileURL, object: nil)
    }

    private static func queueReminderDocumentID(_ documentID: UUID) {
        pendingReminderDocumentIDs.append(documentID)
        NotificationCenter.default.post(name: .shokoFormsOpenReminderDocument, object: nil)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}
