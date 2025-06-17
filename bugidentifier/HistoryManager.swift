import Foundation
import Combine

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    private let historyKey = "identificationHistory"

    @Published var history: [IdentificationHistory] = [] {
        didSet {
            saveHistory()
        }
    }

    private init() {
        loadHistory()
    }

    func add(imageData: Data, bugName: String) {
        let newEntry = IdentificationHistory(
            id: UUID(),
            imageData: imageData,
            bugName: bugName,
            identificationDate: Date()
        )
        history.insert(newEntry, at: 0)
    }

    private func saveHistory() {
        if let encodedData = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encodedData, forKey: historyKey)
        }
    }

    private func loadHistory() {
        if let savedData = UserDefaults.standard.data(forKey: historyKey),
           let decodedHistory = try? JSONDecoder().decode([IdentificationHistory].self, from: savedData) {
            self.history = decodedHistory
        }
    }
    
    func clearHistory() {
        history.removeAll()
    }
}
