import Foundation
import RevenueCat
import SwiftUI

// Conform to PurchasesDelegate
class PurchasesManager: NSObject, ObservableObject, PurchasesDelegate {
    static let shared = PurchasesManager()

    @Published var offerings: Offerings? = nil
    @Published var isPremiumUser: Bool = false
    @Published var customerInfo: CustomerInfo? = nil

    private let apiKey = "appl_ztIBNdBViKhlozezrxrQyzLlBLc"
    let premiumEntitlementID = "premium"

    private override init() { // Private to ensure singleton, override for NSObject
        super.init()
        Purchases.logLevel = .debug
        // Set Purchases.shared.delegate after configuring Purchases
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self // Set delegate here
        print("RevenueCat SDK Initialized with key: \(apiKey)")
        
        Task {
            await checkUserPremiumStatus()
            await getOfferings()
        }
    }
    
    // MARK: - PurchasesDelegate Methods
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        Task {
            await MainActor.run {
                self.isPremiumUser = customerInfo.entitlements[self.premiumEntitlementID]?.isActive == true
                print("Delegate: Customer info updated. Premium status: \(self.isPremiumUser)")
            }
        }
    }

    @MainActor
    func checkUserPremiumStatus() async {
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
        do {
            let result = try await Purchases.shared.purchase(package: package)
            // The delegate will handle updating the user's premium status.
            if result.customerInfo.entitlements[premiumEntitlementID]?.isActive == true {
                 print("Purchase successful via direct check. User is now premium.")
            }
            return result.customerInfo
        } catch ErrorCode.paymentPendingError {
            print("Payment is pending, usually for 'Ask to Buy'.")
            throw ErrorCode.paymentPendingError // Re-throw the specific error
        } catch {
            print("Error purchasing package: \(error.localizedDescription)")
            throw error
        }
    }

    @MainActor
    func restorePurchases() async throws -> CustomerInfo {
        do {
            let info = try await Purchases.shared.restorePurchases()
            // The delegate will handle updating the user's premium status.
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
