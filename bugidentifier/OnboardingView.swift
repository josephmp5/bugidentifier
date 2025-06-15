import SwiftUI

// Define an enum for user interests
enum UserInterest: String, CaseIterable, Identifiable {
    case generalCuriosity = "General Curiosity"
    case gardening = "Gardening & Plants"
    case pestControl = "Pest Control"
    case learning = "Learning & Education"

    var id: String { self.rawValue }
}

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @AppStorage("userInterest") private var storedInterest: String = ""
    @State private var selectedInterest: UserInterest? = nil

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "ladybug.circle.fill") // Changed icon for a bit more flair
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green) // Changed color
                .padding(.bottom, 20)

            Text("Welcome to Bug Identifier!")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Help us personalize your experience. What's your primary interest in identifying bugs?")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 15)

            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(UserInterest.allCases) { interest in
                    Button(action: {
                        selectedInterest = interest
                    }) {
                        Text(interest.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedInterest == interest ? .white : .primary)
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(selectedInterest == interest ? Color.blue : Color(UIColor.systemGray5))
                            .cornerRadius(10)
                            .shadow(color: selectedInterest == interest ? Color.blue.opacity(0.3) : Color.clear, radius: 5, y: 3)
                    }
                }
            }
            .padding(.horizontal, 30)

            Spacer()

            Button(action: {
                if let interest = selectedInterest {
                    storedInterest = interest.rawValue
                }
                isOnboardingComplete = true
            }) {
                Text("Get Started")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedInterest == nil ? Color.gray : Color.green) // Changed color
                    .cornerRadius(10)
                    .padding(.horizontal, 50)
            }
            .disabled(selectedInterest == nil)
            
            Spacer()
        }
        .padding()
        .onAppear {
            // If an interest was previously stored, pre-select it
            if let existingInterest = UserInterest(rawValue: storedInterest) {
                selectedInterest = existingInterest
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingComplete: .constant(false))
    }
}
