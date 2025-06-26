import SwiftUI
import FirebaseCore
import RevenueCat
import FirebaseAuth

// The AppDelegate is now responsible for all app-level setup.
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // This listener ensures we have a Firebase UID before configuring RevenueCat.
    // It guarantees that the RevenueCat appUserID and Firebase UID are always synchronized.
    Auth.auth().addStateDidChangeListener { [weak self] auth, user in
        guard let self = self else { return }
        if let user = user {
            // User is signed in (anonymously or with credentials).
            // Now, it's safe to configure RevenueCat.
            self.configureRevenueCat(for: user.uid)
        } else {
            // User is signed out. This is normal. Firebase will automatically
            // sign in anonymously on the next launch, which will trigger this listener again.
            print("No Firebase user detected. Waiting for anonymous sign-in.")
        }
    }
    
    return true
  }

  private func configureRevenueCat(for appUserID: String) {
      print("AppDelegate: Starting RevenueCat configuration for user ID: \(appUserID)")

      // The RevenueCat API key is now hardcoded for reliability, removing the dependency on Remote Config.
      let revenueCatApiKey = "appl_ztIBNdBViKhlozezrxrQyzLlBLc"

      print("AppDelegate: Configuring RevenueCat SDK with App User ID: \(appUserID)")
      Purchases.logLevel = .debug
      
      // Configure RevenueCat with the Firebase UID as the appUserID.
      // This is the key to synchronizing identities.
      Purchases.configure(withAPIKey: revenueCatApiKey, appUserID: appUserID)
      print("AppDelegate: RevenueCat SDK configured.")

      // Signal the PurchasesManager that the SDK is ready so it can fetch data.
      print("AppDelegate: Initializing PurchasesManager...")
      PurchasesManager.shared.initializeData()
      print("AppDelegate: PurchasesManager initialization called.")
  }
}

@main
struct BugIdentifierApp: App {
    // Inject the app delegate to run the setup logic.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var userManager = UserManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userManager)
                .environmentObject(PurchasesManager.shared)
        }
    }
}
