import SwiftUI

struct ResultsView: View {
    let identifiedBugName: String
    let confidence: Double
    let description: String // Placeholder for more detailed info
    let habitat: String // Placeholder
    let isPoisonous: Bool // Placeholder
    let imageUrl: UIImage? // To display the image that was analyzed

    init(identifiedBugName: String, confidence: Double, imageUrl: UIImage?, description: String = "This is a placeholder description for the identified bug. More details would come from the API.", habitat: String = "Commonly found in gardens and forests.", isPoisonous: Bool = false) {
        self.identifiedBugName = identifiedBugName
        self.confidence = confidence
        self.imageUrl = imageUrl
        self.description = description
        self.habitat = habitat
        self.isPoisonous = isPoisonous
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bug Identified!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)

                if let imageUrl = imageUrl {
                    Image(uiImage: imageUrl)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(identifiedBugName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        HStack {
                            Text("Confidence:")
                                .font(.headline)
                            ProgressView(value: confidence, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor(confidence)))
                                .frame(height: 10)
                            Text(String(format: "%.0f%%", confidence * 100))
                                .font(.headline)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Description")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(description)
                            .font(.body)
                    }
                }
                
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Habitat")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(habitat)
                            .font(.body)
                    }
                }
                
                CardView {
                    HStack {
                        Text("Poisonous:")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(isPoisonous ? "Yes" : "No")
                            .font(.headline)
                            .foregroundColor(isPoisonous ? .red : .green)
                        Image(systemName: isPoisonous ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .foregroundColor(isPoisonous ? .red : .green)
                    }
                }
                
                Spacer()

                Button(action: {
                    // Action to go back or start a new identification
                    // This might involve a callback or environment object to reset the state
                }) {
                    Text("Identify Another Bug")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Identification Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence > 0.75 {
            return .green
        } else if confidence > 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ResultsView(identifiedBugName: "Ladybug", 
                        confidence: 0.88, 
                        imageUrl: UIImage(systemName: "ladybug"),
                        description: "Ladybugs are generally considered useful insects, as many species prey on aphids or scale insects, which are pests in gardens, agricultural fields, orchards, and similar places.",
                        habitat: "Fields, forests, gardens, and sometimes homes.",
                        isPoisonous: false
            )
        }
    }
}
