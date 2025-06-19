import Foundation
import FirebaseAuth
import FirebaseFirestore
import RevenueCat

class AuthService: ObservableObject {
    static let shared = AuthService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    @Published var user: FirebaseAuth.User?
    @Published var errorMessage: String?

    private init() {
        auth.addStateDidChangeListener { [weak self] (_, user) in
            self?.user = user
        }
    }

    func signInAnonymously(completion: @escaping (Bool, Error?) -> Void) {
        auth.signInAnonymously { [weak self] (authResult, error) in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Anonymous sign-in failed: \(error.localizedDescription)"
                print("Error signing in anonymously: \(error.localizedDescription)")
                completion(false, error)
                return
            }

            if let user = authResult?.user {
                self.user = user
                self.errorMessage = nil
                print("Signed in anonymously with UID: \(user.uid)")
                // Link Firebase UID with RevenueCat to ensure webhooks update the correct user
                print("[AuthService] Firebase UID for login: \(user.uid)")
                print("[AuthService] Current RevenueCat App User ID (before login): \(Purchases.shared.appUserID)")

                Purchases.shared.logIn(user.uid) { (customerInfo, created, error) in
                    if let error = error {
                        print("[AuthService] RevenueCat login FAILED for Firebase UID \(user.uid): \(error.localizedDescription)")
                        print("[AuthService] RevenueCat App User ID (after failed login): \(Purchases.shared.appUserID)")
                        if let customerInfo = customerInfo {
                            print("[AuthService] CustomerInfo after failed login - Original App User ID: \(customerInfo.originalAppUserId). Current global RC App User ID: \(Purchases.shared.appUserID)")
                        }
                    } else {
                        print("[AuthService] RevenueCat login SUCCEEDED for Firebase UID \(user.uid). New RC user created: \(created)")
                        print("[AuthService] RevenueCat App User ID (after successful login): \(Purchases.shared.appUserID)")
                        if let customerInfo = customerInfo {
                            print("[AuthService] CustomerInfo after successful login - Original App User ID: \(customerInfo.originalAppUserId). Current global RC App User ID: \(Purchases.shared.appUserID)")
                        }
                    }
                }

                self.createUserDocument(for: user) { success in
                    if success {
                        print("Firestore user document check/creation successful.")
                        completion(true, nil)
                    } else {
                        let creationError = NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create user document in Firestore."])
                        self.errorMessage = creationError.localizedDescription
                        completion(false, creationError)
                    }
                }
            } else {
                self.errorMessage = "Anonymous sign-in failed: No user data received."
                print("Error: No user data received after anonymous sign-in attempt.")
                completion(false, nil)
            }
        }
    }

    func checkAndCreateUserDocumentIfNeeded() {
        guard let currentUser = auth.currentUser else {
            print("No current user to check for Firestore document.")
            return
        }
        // Call the existing logic to create the document if it's missing.
        createUserDocument(for: currentUser) { _ in
            // Completion handler can be empty if no specific action is needed after the check.
            print("Completed Firestore document check for existing user.")
        }
    }

    private func createUserDocument(for user: FirebaseAuth.User, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(user.uid)
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                print("User document already exists for UID: \(user.uid)")
                completion(true)
                return
            }
            // Document does not exist, create it.
            let userData: [String: Any] = [
                "uid": user.uid,
                "createdAt": Timestamp(date: Date()),
                "isPremium": false,
                "tokens": 1
            ]
            userRef.setData(userData) { error in
                if let error = error {
                    print("Error creating user document: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }

    func signOut(completion: @escaping (Bool, Error?) -> Void) {
        do {
            try auth.signOut()
            self.user = nil
            self.errorMessage = nil
            completion(true, nil)
        } catch let signOutError as NSError {
            self.errorMessage = "Error signing out: \(signOutError.localizedDescription)"
            print("Error signing out: \(signOutError.localizedDescription)")
            completion(false, signOutError)
        }
    }
}
