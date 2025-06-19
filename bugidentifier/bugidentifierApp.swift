import SwiftUI
import FirebaseCore

// AppDelegate for Firebase initialization
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    // Initialize Remote Config Manager to start fetching the key
    _ = RemoteConfigManager.shared
    _ = PurchasesManager.shared // Ensure RevenueCat SDK is configured early
    return true
  }
}

@main
struct BugIdentifierApp: App { // Changed to UpperCamelCase
    // Inject the app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @StateObject private var purchasesManager = PurchasesManager.shared
    @StateObject private var userManager = UserManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchasesManager)
                .environmentObject(userManager)
        }
    }
}
