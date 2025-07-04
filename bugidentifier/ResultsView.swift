import SwiftUI

import SwiftUI

// Helper for Serif Font (if not using a custom font added to project)
// For a true "sharp, black serif" feel, you might need to embed a specific font file.
// Georgia is a commonly available serif font.
struct SerifText: View {
    let text: String
    let size: CGFloat
    let color: Color

    init(_ text: String, size: CGFloat = 28, color: Color = ThemeColors.serifText) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.custom("Georgia-Bold", size: size)) // Example serif font
            .foregroundColor(color)
    }
}

struct ResultsView: View {
    @Environment(\.presentationMode) var presentationMode
    let result: BugIdentificationResult
    let imageUrl: UIImage? // To display the image that was analyzed

    init(result: BugIdentificationResult, imageUrl: UIImage?) {
        self.result = result
        self.imageUrl = imageUrl
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Layer 1: Background Image (extends to top edge)
            if let imageUrl = imageUrl {
                Image(uiImage: imageUrl)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width)
                    .ignoresSafeArea()
            } else {
                ThemeColors.background.ignoresSafeArea()
            }

            // Layer 2: Scrollable Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    // This spacer creates the hero image area, pushing the card down.
                    // The height determines how much of the image is shown above the card.
                    Spacer()
                        .frame(height: 250)

                    // Information Card
                    VStack(alignment: .leading, spacing: 15) {
                        SerifText(result.name, size: 32)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        Text(result.description)
                            .font(.system(.body, design: .default))
                            .foregroundColor(ThemeColors.primaryText)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                        
                        Divider().padding(.vertical, 5)
                        
                        // Taxonomy Section
                        SectionHeader(title: "Taxonomy")
                        InfoRow(iconName: "text.book.closed.fill", title: "Scientific Name", value: result.scientificName)
                        InfoRow(iconName: "person.3.sequence.fill", title: "Family", value: result.family)
                        InfoRow(iconName: "list.bullet.indent", title: "Order", value: result.order)
                        
                        Divider().padding(.vertical, 5)
                        
                        // Ecology & Behavior Section
                        SectionHeader(title: "Ecology & Behavior")
                        InfoRow(iconName: "leaf.fill", title: "Habitat", value: result.habitat)
                        InfoRow(iconName: "fork.knife", title: "Diet", value: result.diet)
                        InfoRow(iconName: "arrow.2.circlepath", title: "Life Cycle", value: result.lifeCycle)

                        Divider().padding(.vertical, 5)

                        // Human Interaction Section
                        SectionHeader(title: "Human Interaction")
                        InfoRow(iconName: result.isPoisonous ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                                title: "Poisonous to Humans",
                                value: result.isPoisonous ? "Yes" : "No",
                                valueColor: result.isPoisonous ? .red : ThemeColors.primaryText)
                    }
                    .padding(25)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ThemeColors.cardBackground)
                    .cornerRadius(20)
                    .shadow(color: ThemeColors.primaryText.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // This spacer pushes the card to the top and the button to the bottom
                    Spacer()
                    
                    // Button is wrapped in a VStack for stable layout
                    VStack {
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Identify Another Bug")
                                .font(.system(.headline, design: .default))
                                .fontWeight(.semibold)
                                .foregroundColor(ThemeColors.background)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(ThemeColors.primaryText)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Custom back button if needed, for better contrast on transparent bar
            ToolbarItem(placement: .navigationBarLeading) {
                // Add custom back button here if default is hard to see
            }
        }
        .onAppear {
            // Save the identification to history
            if let image = imageUrl, let imageData = image.jpegData(compressionQuality: 0.8) {
                HistoryManager.shared.add(imageData: imageData, bugName: result.name)
            }

            // Make navigation bar transparent
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
    }
}

// Helper view for consistent info rows
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(ThemeColors.primaryText)
            .padding(.bottom, 5)
    }
}

struct InfoRow: View {
    let iconName: String
    let title: String
    let value: String?
    var valueColor: Color = ThemeColors.primaryText

    var body: some View {
        if let value = value, !value.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.body)
                        .foregroundColor(ThemeColors.accent)
                        .frame(width: 25, alignment: .center)
                    Text(title)
                        .font(.system(.headline, design: .default))
                        .fontWeight(.medium)
                        .foregroundColor(ThemeColors.primaryText)
                }
                Text(value)
                    .font(.system(.body, design: .default))
                    .foregroundColor(valueColor)
                    .padding(.leading, 35) // Align with text, not icon
            }
            .padding(.bottom, 10)
        }
    }
}

// Remove old confidenceColor and CardView as they are replaced by new theme
// struct CardView<Content: View> ... (Removed)
// private func confidenceColor ... (Removed)


struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
                let sampleResult = BugIdentificationResult(
            id: UUID(),
            name: "Ladybug",
            description: "Ladybugs are generally considered useful insects, as many species prey on aphids or scale insects, which are pests in gardens, agricultural fields, orchards, and similar places.",
            family: "Coccinellidae",
            scientificName: "Coccinella septempunctata",
            order: "Coleoptera",
            habitat: "Fields, forests, gardens, and sometimes homes.",
            diet: "Aphids, scale insects, and other small pests.",
            lifeCycle: "Complete metamorphosis: egg, larva, pupa, and adult.",
            isPoisonous: false
        )
        
        NavigationView {
            ResultsView(result: sampleResult, 
                        imageUrl: UIImage(systemName: "ladybug")
            )
        }
    }
}
