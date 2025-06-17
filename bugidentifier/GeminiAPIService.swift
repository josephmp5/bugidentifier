import SwiftUI

// MARK: - Bug Identification Result Model

struct BugIdentificationResult: Decodable {
    let name: String
    let description: String
    let habitat: String
    let isPoisonous: Bool
}

// MARK: - Gemini API Service

import Combine

class GeminiAPIService: ObservableObject {
    static let shared = GeminiAPIService()
    
    @Published private var apiKey: String?

    private let modelName = "gemini-2.5-flash-preview-05-20"

    private func getAPIKey(timeoutSeconds: TimeInterval = 10) async throws -> String {
        if let key = self.apiKey, !key.isEmpty {
            return key
        }

        // Wait for the apiKey publisher to emit a non-nil, non-empty value
        return try await withCheckedThrowingContinuation { continuation in
            var cancellableStore: AnyCancellable?
            var timeoutTask: Task<Void, Never>?

            timeoutTask = Task {
                // Sleep for the timeout duration
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                // If the task hasn't been cancelled by then, the timeout has occurred
                if !Task.isCancelled {
                    cancellableStore?.cancel() // Cancel the Combine subscription
                    continuation.resume(throwing: APIError.apiKeyFetchTimeout)
                }
            }

            cancellableStore = self.$apiKey
                .compactMap { $0 } // Ensure key is not nil
                .filter { !$0.isEmpty } // Ensure key is not empty
                .first() // Take the first valid key emitted
                .sink(receiveCompletion: { completionStatus in
                    timeoutTask?.cancel() // Cancel the timeout task as we've received a completion
                    if case .failure(let error) = completionStatus {
                        // This might happen if the $apiKey publisher itself emits an error.
                        continuation.resume(throwing: error)
                    } else if self.apiKey == nil || self.apiKey?.isEmpty == true {
                        // If sink completes without a valid key (e.g. publisher finishes before emitting one)
                        // and timeout didn't fire first, throw timeout.
                        // This path is less likely with .first() but good for robustness.
                         if !(timeoutTask?.isCancelled ?? true) { // Check if timeout already fired
                            continuation.resume(throwing: APIError.apiKeyFetchTimeout)
                         }
                    }
                }, receiveValue: { key in
                    timeoutTask?.cancel() // Key received, cancel timeout task
                    continuation.resume(returning: key)
                })
        }
    }
    private var cancellables = Set<AnyCancellable>()

    private var apiUrl: URL? {
        guard let key = apiKey, !key.isEmpty else { return nil }
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(key)")
    }

    private init() {
        // Subscribe to changes from RemoteConfigManager
        RemoteConfigManager.shared.$geminiAPIKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fetchedKey in
                self?.apiKey = fetchedKey
                if let key = fetchedKey, !key.isEmpty {
                    print("GeminiAPIService: Successfully received API key.")
                } else {
                    print("GeminiAPIService: Received nil or empty API key.")
                }
            }
            .store(in: &cancellables)
    }

    func identifyBug(from image: UIImage) async throws -> BugIdentificationResult {
        let currentApiKey = try await getAPIKey()
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(currentApiKey)") else {
            // This should ideally not happen if the key is valid and modelName is correct.
            throw APIError.invalidURL
        }

        // 1. Convert UIImage to Base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()

        // 2. Construct the request body
        let prompt = """
        Identify the insect in this image. Provide its common name, a brief description of its key features, its typical habitat, and whether it is poisonous to humans.
        Format the response as a single, clean JSON object with the following keys: 'name' (string), 'description' (string), 'habitat' (string), and 'isPoisonous' (boolean).
        Do not include any other text or markdown formatting like ```json before or after the JSON object.
        """
        
        let requestBody = GeminiAPIRequest(
            contents: [
                GeminiAPIContent(parts: [
                    GeminiAPIPart(text: prompt),
                    GeminiAPIPart(inlineData: GeminiAPIInlineData(mimeType: "image/jpeg", data: base64Image))
                ])
            ]
        )

        // 3. Create and send the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError(response: response, data: data)
        }

        // 4. Decode the response and the nested JSON
        let geminiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        
        guard let textPart = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw APIError.noContentReceived
        }
        
        guard let responseData = textPart.data(using: .utf8) else {
            throw APIError.decodingFailed
        }
        
        let finalResult = try JSONDecoder().decode(BugIdentificationResult.self, from: responseData)
        return finalResult
    }
}

// MARK: - API Error Enum

enum APIError: Error, LocalizedError {
    case invalidURL
    case apiKeyNotAvailable
    case invalidAPIKey
    case imageConversionFailed
    case apiKeyFetchTimeout
    case networkError(response: URLResponse?, data: Data?)
    case decodingFailed
    case noContentReceived

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API URL is invalid."
        case .apiKeyNotAvailable:
            return "API key is not available. It might still be loading or failed to fetch from Remote Config."
        case .invalidAPIKey:
            return "The fetched API key is invalid or empty. Please check your Firebase Remote Config setup."
        case .imageConversionFailed:
            return "Failed to convert the image to a suitable format."
        case .networkError(let response, let data):
            if let httpResponse = response as? HTTPURLResponse {
                var details = "Network request failed with status code \(httpResponse.statusCode)."
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    details += "\nResponse: \(errorBody)"
                }
                return details
            }
            return "An unknown network error occurred."
        case .decodingFailed:
            return "Failed to decode the response from the API."
        case .apiKeyFetchTimeout:
            return "Could not fetch the API key in time. Please check your internet connection and try again."
        case .noContentReceived:
            return "The API response did not contain any usable content."
        }
    }
}

// MARK: - Gemini API Request/Response Structs

private struct GeminiAPIRequest: Encodable {
    let contents: [GeminiAPIContent]
}

private struct GeminiAPIContent: Encodable, Decodable {
    let parts: [GeminiAPIPart]
}

private struct GeminiAPIPart: Encodable, Decodable {
    var text: String? = nil
    var inlineData: GeminiAPIInlineData? = nil
}

private struct GeminiAPIInlineData: Encodable, Decodable {
    let mimeType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

private struct GeminiAPIResponse: Decodable {
    let candidates: [GeminiAPICandidate]
}

private struct GeminiAPICandidate: Decodable {
    let content: GeminiAPIContent
}
