import Foundation
import FirebaseFirestore
import FirebaseFunctions
import Combine

class UserManager: ObservableObject {
    @Published var user: UserModel?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var db = Firestore.firestore()
    private lazy var functions = Functions.functions() // Use lazy var for functions
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Listen for changes in the authenticated user from AuthService
        AuthService.shared.$user
            .compactMap { $0?.uid }
            .sink { [weak self] uid in
                self?.listenForUserChanges(uid: uid)
            }
            .store(in: &cancellables)
    }

    deinit {
        // Clean up the listener when the object is deallocated
        listener?.remove()
    }

    private func listenForUserChanges(uid: String) {
        listener?.remove() // Remove old listener to avoid duplicates
        let userRef = db.collection("users").document(uid)

        listener = userRef.addSnapshotListener { [weak self] documentSnapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.errorMessage = "Error fetching user data: \(error.localizedDescription)"
                print(self.errorMessage!)
                return
            }

            guard let document = documentSnapshot else {
                self.errorMessage = "User document not found."
                print(self.errorMessage!)
                return
            }

            do {
                // Decode the Firestore document into our UserModel struct
                self.user = try document.data(as: UserModel.self)
                print("User data updated: \(self.user?.tokens ?? -1) tokens")
            } catch {
                self.errorMessage = "Failed to decode user data: \(error.localizedDescription)"
                print(self.errorMessage!)
            }
        }
    }

    func consumeToken(completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        errorMessage = nil

        functions.httpsCallable("consumeToken").call { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error as NSError? {
                    let nsError = error as NSError
                    // Extract the user-friendly message from the HttpsError details
                    let message = nsError.userInfo[FunctionsErrorDetailsKey] as? String ?? nsError.localizedDescription
                    self?.errorMessage = message
                    print("Error consuming token: \(message)")
                    completion(.failure(nsError))
                    return
                }

                guard let data = result?.data as? [String: Any],
                      let success = data["success"] as? Bool, success else {
                    let genericError = NSError(domain: "AppError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Token consumption failed due to an unknown server error."])
                    self?.errorMessage = "Token consumption failed."
                    completion(.failure(genericError))
                    return
                }
                
                // Success! The token was consumed (or user is premium).
                // The local user model will update automatically via the Firestore listener.
                completion(.success(()))
            }
        }
    }
}
