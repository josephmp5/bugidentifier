import Foundation
import FirebaseRemoteConfig

// Manages fetching configuration values from Firebase Remote Config.
// This is a singleton to ensure a single, consistent source of configuration.
public class RemoteConfigManager {

    public static let shared = RemoteConfigManager()
    private let remoteConfig: RemoteConfig
    
    // Private struct to hold the keys for Remote Config.
    // This prevents magic strings and improves maintainability.
    private struct ConfigKeys {
        static let revenueCatApiKey = "revenuecat_api_key"
        static let geminiApiKey = "gemini_api_key"
    }

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        // Use a low fetch interval for debugging.
        // For production, this should be set to a higher value.
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        // Set default values. This is good practice. An empty string is a safe default.
        remoteConfig.setDefaults([
            ConfigKeys.revenueCatApiKey: "" as NSObject,
            ConfigKeys.geminiApiKey: "" as NSObject
        ])
    }

    // A generic, private function to fetch any string value from Remote Config.
    // This is the core logic that all public fetch methods will use.
    private func fetchConfigValue(forKey key: String, completion: @escaping (String?) -> Void) {
        remoteConfig.fetchAndActivate { (status, error) in
            if let error = error {
                print("RemoteConfigManager: Error fetching and activating config: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            switch status {
            case .successFetchedFromRemote, .successUsingPreFetchedData:
                let value = self.remoteConfig.configValue(forKey: key).stringValue
                // Treat an empty string as a nil value, as an empty key is not useful.
                let result = !value.isEmpty ? value : nil
                print("RemoteConfigManager: Successfully fetched '\(key)'. Result is empty: \(result == nil)")
                DispatchQueue.main.async {
                    completion(result)
                }
            case .error:
                print("RemoteConfigManager: An error occurred while fetching config for key: \(key).")
                DispatchQueue.main.async {
                    completion(nil)
                }
            @unknown default:
                print("RemoteConfigManager: An unknown status was returned for key: \(key).")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // Public method for fetching the RevenueCat API Key.
    public func fetchRevenueCatApiKey(completion: @escaping (String?) -> Void) {
        fetchConfigValue(forKey: ConfigKeys.revenueCatApiKey, completion: completion)
    }

    // Public method for fetching the Gemini API Key.
    public func fetchGeminiApiKey(completion: @escaping (String?) -> Void) {
        fetchConfigValue(forKey: ConfigKeys.geminiApiKey, completion: completion)
    }
}
