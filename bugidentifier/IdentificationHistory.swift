import SwiftUI

struct IdentificationHistory: Codable, Identifiable, Hashable {
    let id: UUID
    let imageData: Data
    let bugName: String
    let identificationDate: Date

    var image: Image {
        Image(uiImage: UIImage(data: imageData) ?? UIImage())
    }
}
