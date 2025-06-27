import Foundation
import FirebaseAuth
import RevenueCat
import FirebaseFirestore

class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var user: FirebaseAuth.User?
    @Published var errorMessage: String?

    private var auth = Auth.auth()
    private var db = Firestore.firestore() // Firestore database reference

    private init() {
        // Listen for auth changes to update the 'user' property throughout the app.
        auth.addStateDidChangeListener { [weak self] (auth, user) in
            self?.user = user
        }
    }

    // Handles sign-in with credentials like Apple, Google, etc.
    func signIn(credential: AuthCredential, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        auth.signIn(with: credential) { [weak self] (authResult, error) in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Sign-in failed: \(error.localizedDescription)"
                completion(.failure(error))
                return
            }

            guard let user = authResult?.user else {
                let noUserError = NSError(domain: "AuthService", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not found after sign-in."])
                completion(.failure(noUserError))
                return
            }

            self.errorMessage = nil
            print("Sign in successful for UID: \(user.uid)")

            // Log in to RevenueCat. This triggers the backend 'TRANSFER' event to merge the
            // anonymous user's data with the new permanent account.
            Purchases.shared.logIn(user.uid) { (customerInfo, created, error) in
                if let error = error {
                    print("RevenueCat login failed after sign-in: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                print("RevenueCat login successful. User identity transferred. New user in RC: \(created)")

                // After successful sign-in and RevenueCat login, ensure a user document exists in Firestore.
                self.checkAndCreateUserDocument(for: user) { firestoreError in
                    if let firestoreError = firestoreError {
                        // Log the error, but still consider the sign-in successful for a better user experience.
                        // The app should be resilient to this state.
                        print("Warning: Firestore document creation failed, but sign-in will proceed: \(firestoreError.localizedDescription)")
                    }
                    completion(.success(user))
                }
            }
        }
    }

    // Handles initial anonymous sign-in when the app first launches.
    func signInAnonymously(completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        auth.signInAnonymously { [weak self] (authResult, error) in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Anonymous sign-in failed: \(error.localizedDescription)"
                completion(.failure(error))
                return
            }

            guard let user = authResult?.user else {
                let noUserError = NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user data after anonymous sign-in."])
                completion(.failure(noUserError))
                return
            }

            self.errorMessage = nil
            print("Signed in anonymously with UID: \(user.uid)")
            
            // For anonymous users, create their document in Firestore right away.
            self.checkAndCreateUserDocument(for: user) { firestoreError in
                if let firestoreError = firestoreError {
                    // If the database write fails for a new anonymous user, we should fail the entire operation.
                    print("Critical Error: Failed to create Firestore document for anonymous user. \(firestoreError.localizedDescription)")
                    completion(.failure(firestoreError))
                    return
                }
                // The app's main init() listener handles configuring RevenueCat with this new anonymous ID.
                // We don't need to call logIn here, as this IS the initial identity.
                completion(.success(user))
            }
        }
    }

    func signOut(completion: @escaping (Bool, Error?) -> Void) {
        // Sign out of Firebase first.
        do {
            try auth.signOut()
            self.errorMessage = nil
            print("Successfully signed out of Firebase.")

            // After Firebase sign-out, log out of RevenueCat to clear the user cache.
            Purchases.shared.logOut { (customerInfo, error) in
                if let error = error {
                    print("Error logging out of RevenueCat: \(error.localizedDescription)")
                } else {
                    print("Successfully logged out of RevenueCat.")
                }
                // The operation is successful even if RC logout fails, as Firebase has signed out.
                completion(true, nil)
            }
        } catch let signOutError as NSError {
            self.errorMessage = "Error signing out: \(signOutError.localizedDescription)"
            completion(false, signOutError)
        }
    }

    /// Checks if a user document exists in Firestore for the given user. If not, it creates one.
    /// This ensures that every authenticated user has a corresponding database entry.
    private func checkAndCreateUserDocument(for user: FirebaseAuth.User, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(user.uid)
        
        userRef.getDocument { document, error in
            if let document = document, document.exists {
                print("User document already exists for UID: \(user.uid). No action needed.")
                completion(nil)
                return
            }
            
            print("User document does not exist for UID: \(user.uid). Creating new document...")
            
            // Manually create a dictionary to avoid dependency on FirebaseFirestoreSwift
            let userData: [String: Any] = [
                "uid": user.uid,
                "isPremium": false,
                "subscriptionActive": false,
                "tokens": 1 // Grant 3 free tokens to new users.
            ]
            
            userRef.setData(userData) { error in
                if let error = error {
                    print("Error creating user document: \(error.localizedDescription)")
                    completion(error)
                } else {
                    print("Successfully created user document.")
                    completion(nil)
                }
            }
        }
    }
}
