import Foundation
import FirebaseFirestoreSwift

struct UserModel: Codable, Identifiable {
    // By using the @DocumentID property wrapper, Firestore will automatically
    // populate this field with the document's ID.
    @DocumentID var id: String? = UUID().uuidString
    let uid: String
    let isPremium: Bool?
    let subscriptionActive: Bool?
    let tokens: Int?

    // We can add a computed property for convenience to check if the user has access.
    var hasAccess: Bool {
        return isPremium == true || subscriptionActive == true || (tokens ?? 0) > 0
    }

    enum CodingKeys: String, CodingKey {
        case uid
        case isPremium
        case subscriptionActive
        case tokens
    }
}
