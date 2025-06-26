import SwiftUI
import GoogleGenerativeAI

// Defines the data structure for the bug identification result.
// This struct is Decodable to be easily parsed from the JSON response.
struct BugIdentificationResult: Decodable, Identifiable {
    var id = UUID()
    let name: String
    let description: String
    let family: String?
    let scientificName: String?
    let order: String?
    let habitat: String?
    let diet: String?
    let lifeCycle: String?
    let isPoisonous: Bool

    enum CodingKeys: String, CodingKey {
        case name, description, family, scientificName, order, habitat, diet, lifeCycle, isPoisonous
    }
}

// Defines the errors that can occur during the API interaction.
// Conforming to LocalizedError provides user-friendly descriptions.
enum APIError: Error, LocalizedError {
    case apiKeyMissing
    case requestFailed(Error)
    case noContent
    case imageProcessingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "The Gemini API key is missing. Please check Firebase Remote Config."
        case .requestFailed(let error):
            return "The API request to Gemini failed: \(error.localizedDescription)"
        case .noContent:
            return "The API response from Gemini contained no content."
        case .imageProcessingFailed:
            return "Failed to process the image data for Gemini."
        case .decodingFailed:
            return "Failed to decode the JSON response from Gemini."
        }
    }
}

// This service class handles all interactions with the Google Gemini API.
// It is a singleton to ensure a single point of interaction.
class GeminiAPIService {
    static let shared = GeminiAPIService()
    private var apiKey: String? // A cache for the API key to improve performance.

    private init() {}

    // Main public function to identify a bug from image data.
    // It orchestrates fetching the API key and performing the identification.
    func identifyBug(imageData: Data, completion: @escaping (Result<BugIdentificationResult, Error>) -> Void) {
        fetchKeyIfNeeded { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let key):
                // Once the key is confirmed, perform the actual API call.
                self.performIdentification(with: key, imageData: imageData, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // Performs the actual network request to the Gemini API.
    private func performIdentification(with apiKey: String, imageData: Data, completion: @escaping (Result<BugIdentificationResult, Error>) -> Void) {
        guard let image = UIImage(data: imageData) else {
            completion(.failure(APIError.imageProcessingFailed))
            return
        }

        // Configure the model with safety settings to be less restrictive.
        // This can prevent the API from blocking responses for benign content.
        let safetySettings = [
            SafetySetting(harmCategory: .harassment, threshold: .blockOnlyHigh),
            SafetySetting(harmCategory: .hateSpeech, threshold: .blockOnlyHigh),
            SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockOnlyHigh),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockOnlyHigh),
        ]

        let generativeModel = GenerativeModel(name: "gemini-2.5-flash-preview-05-20", apiKey: apiKey, safetySettings: safetySettings)
        let prompt = """
        Identify the insect in this image. Provide its common name, a brief description of its key features, its typical habitat, and whether it is poisonous to humans.
        Format the response as a single, clean JSON object with the following keys: 'name' (string), 'description' (string), 'family' (string), 'scientificName' (string), 'order' (string), 'habitat' (string), 'diet' (string), 'lifeCycle' (string), and 'isPoisonous' (boolean). All keys except for name, description, habitat, and isPoisonous are optional if the information is not available.
        If the image does not contain an insect, the 'name' field should be 'Not an insect' and all other fields should be empty strings or false for the boolean.
        """
        
        Task {
            do {
                let response = try await generativeModel.generateContent(prompt, image)
                if var text = response.text {
                    // The model may wrap the JSON in markdown backticks. We need to strip them.
                    text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

                    // Attempt to decode the cleaned JSON text from the response.
                    do {
                        let result = try JSONDecoder().decode(BugIdentificationResult.self, from: Data(text.utf8))
                        DispatchQueue.main.async {
                            completion(.success(result))
                        }
                    } catch {
                        print("GeminiAPIService: JSON Decoding Error: \(error.localizedDescription)")
                        print("GeminiAPIService: Raw text from Gemini that failed to decode: \(text)")
                        DispatchQueue.main.async {
                            completion(.failure(APIError.decodingFailed))
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(APIError.noContent))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(APIError.requestFailed(error)))
                }
            }
        }
    }

    // Fetches the API key from RemoteConfigManager and caches it.
    // If the key is already cached, it returns immediately.
    private func fetchKeyIfNeeded(completion: @escaping (Result<String, Error>) -> Void) {
        // If we already have a valid key, use it.
        if let apiKey = self.apiKey, !apiKey.isEmpty {
            completion(.success(apiKey))
            return
        }

        // Otherwise, fetch it from our robust Remote Config service.
        RemoteConfigManager.shared.fetchGeminiApiKey { [weak self] fetchedKey in
            guard let self = self else { return }
            
            if let key = fetchedKey, !key.isEmpty {
                self.apiKey = key // Cache the key for next time.
                completion(.success(key))
            } else {
                completion(.failure(APIError.apiKeyMissing))
            }
        }
    }
}
