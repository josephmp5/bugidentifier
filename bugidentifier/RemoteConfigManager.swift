import Foundation
import FirebaseRemoteConfig
import Combine

class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    @Published var geminiAPIKey: String?

    private var remoteConfig: RemoteConfig
    private let geminiAPIKeyKey = "gemini_api_key"

    private init() {
        self.remoteConfig = RemoteConfig.remoteConfig()
        setupConfigSettings()
        setupDefaults()
        fetchAndActivate()
    }

    private func setupConfigSettings() {
        let settings = RemoteConfigSettings()
        // Lower fetch interval for development; increase for production
        settings.minimumFetchInterval = 0 // Fetches every time in debug
        self.remoteConfig.configSettings = settings
    }

    private func setupDefaults() {
        // Provide a default value. This is crucial for when the app
        // is launched for the first time or has no network connection.
        // The value here could be an empty string or a non-functional key.
        let defaults: [String: NSObject] = [
            geminiAPIKeyKey: "" as NSObject
        ]
        self.remoteConfig.setDefaults(defaults)
    }

    func fetchAndActivate() {
        remoteConfig.fetchAndActivate { [weak self] (status, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching Remote Config: \(error.localizedDescription)")
                return
            }
            
            switch status {
            case .successFetchedFromRemote, .successUsingPreFetchedData:
                let fetchedKey = self.remoteConfig[self.geminiAPIKeyKey].stringValue ?? ""
                DispatchQueue.main.async {
                    self.geminiAPIKey = fetchedKey
                    print("Remote Config: Successfully fetched API key.")
                }
            case .error:
                print("Remote Config: Error activating fetched configs.")
            @unknown default:
                print("Remote Config: Unknown status after fetch.")
            }
        }
    }
}
