import Foundation
import RevenueCat
import SwiftUI
import FirebaseFirestore // For database updates
import FirebaseAuth     // To get the current user's ID

// Conform to PurchasesDelegate
class PurchasesManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = PurchasesManager()

    @Published var offerings: Offerings? = nil
    @Published var isPremiumUser: Bool = false
    @Published var customerInfo: CustomerInfo? = nil
    @Published var isSDKConfigured: Bool = false

    let premiumEntitlementID = "premium"
    private var db = Firestore.firestore()

    private override init() { // Private to ensure singleton, override for NSObject
        super.init()
        // Initializer is now inert and does not touch the Purchases SDK.
        print("PurchasesManager instance created.")
    }

    /// This method should be called only after the Purchases SDK has been configured.
    func initializeData() {
        print("SDK configured. Setting delegate and initializing PurchasesManager data.")
        // It is now safe to set the delegate and interact with the SDK.
        Purchases.shared.delegate = self
        
        Task {
            await MainActor.run {
                self.isSDKConfigured = true
            }
            await checkUserPremiumStatus()
            await getOfferings()
        }
    }
    
    // MARK: - PurchasesDelegate Methods
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        let premiumStatus = customerInfo.entitlements[self.premiumEntitlementID]?.isActive == true
        Task {
            await MainActor.run {
                self.isPremiumUser = premiumStatus
                print("Delegate: Customer info updated. Premium status: \(self.isPremiumUser)")
            }
        }
        updateUserSubscriptionStatus(isPremium: premiumStatus)
    }

    private func updateUserSubscriptionStatus(isPremium: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("Error: Cannot update subscription status because no user is logged in.")
            return
        }
        let userRef = db.collection("users").document(uid)
        print("Updating Firestore for user \(uid) with premium status: \(isPremium)")
        userRef.setData(["isPremium": isPremium, "subscriptionActive": isPremium], merge: true) { error in
            if let error = error {
                print("Error updating user subscription status in Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully updated user's premium status in Firestore.")
            }
        }
    }

    @MainActor
    func checkUserPremiumStatus() async {
        guard isSDKConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            self.isPremiumUser = info.entitlements[premiumEntitlementID]?.isActive == true
            print("Checked premium status on init/foreground: \(self.isPremiumUser)")
        } catch {
            print("Error fetching customer info for premium status: \(error.localizedDescription)")
            self.isPremiumUser = false
        }
    }

    @MainActor
    func getOfferings() async {
        guard isSDKConfigured else { return }
        do {
            let fetchedOfferings = try await Purchases.shared.offerings()
            self.offerings = fetchedOfferings
            if let current = fetchedOfferings.current {
                print("Fetched current offering: \(current.identifier) with \(current.availablePackages.count) packages.")
            } else {
                print("No current offering found.")
            }
        } catch {
            print("Error fetching offerings: \(error.localizedDescription)")
            self.offerings = nil
        }
    }

    @MainActor
    func purchasePackage(_ package: Package) async throws -> CustomerInfo {
        guard isSDKConfigured else { 
            print("SDK not configured, purchase cancelled.")
            throw NSError(domain: "PurchasesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDK not ready"])
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.customerInfo.entitlements[premiumEntitlementID]?.isActive == true {
                 print("Purchase successful via direct check. User is now premium.")
            }
            return result.customerInfo
        } catch ErrorCode.paymentPendingError {
            print("Payment is pending, usually for 'Ask to Buy'.")
            throw ErrorCode.paymentPendingError
        } catch {
            print("Error purchasing package: \(error.localizedDescription)")
            throw error
        }
    }

    @MainActor
    func restorePurchases() async throws -> CustomerInfo {
        guard isSDKConfigured else { 
            print("SDK not configured, restore cancelled.")
            throw NSError(domain: "PurchasesManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDK not ready"])
        }
        do {
            let info = try await Purchases.shared.restorePurchases()
            if info.entitlements[premiumEntitlementID]?.isActive == true {
                print("Restore successful via direct check. User is premium.")
            } else {
                print("Restore successful via direct check, but user is not premium.")
            }
            return info
        } catch {
            print("Error restoring purchases: \(error.localizedDescription)")
            throw error
        }
    }
}
