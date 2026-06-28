import UIKit
import SwiftUI
import GoogleSignIn

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: ShokoFormsRootView())
        window.backgroundColor = .systemBackground
        self.window = window
        window.makeKeyAndVisible()

        for urlContext in connectionOptions.urlContexts {
            handle(urlContext.url)
        }

        for userActivity in connectionOptions.userActivities {
            if let url = userActivity.webpageURL {
                handle(url)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handle(context.url)
        }
    }

    private func handle(_ url: URL) {
        if GIDSignIn.sharedInstance.handle(url) {
            return
        }

        _ = AppDelegate.handleOpenURL(url)
    }
}
