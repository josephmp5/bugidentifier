import SwiftUI
import FirebaseAuth // Added for AuthService

// MARK: - Data Model for Onboarding Pages
enum OnboardingPageType {
    case welcome, identify, collect
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let type: OnboardingPageType
    
    // Page 1: Welcome
    var backgroundImageName: String? // For full-screen image
    var headline1: String? 
    var subheadline1: String?

    // Page 2: Snap, Identify, Discover
    var headline2: String?
    var phoneGraphicImageName: String? // Stylized phone
    var lineArtBugImageName: String?   // Line art bug
    var idCardImageName: String?       // Real photo for ID card
    var idCardBugName: String?
    // Minimalist data points for ID card can be an array of (String, String) for label and value
    var idCardData: [(label: String, value: String)]?
    var continueButtonText: String? 

    // Page 3: Build Your Collection
    var headline3: String?
    var body3: String?
    // For collage - can be an array of simplified card data (image name, bug name)
    var collageCardDetails: [(imageName: String, bugName: String)]?
    var startButtonText: String?
    var startButtonBackgroundColor: Color?
    var startButtonTextColor: Color?
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0

    // Define pages based on the new model and prompts
    let pages: [OnboardingPage] = [
        // Page 1: Welcome to the Field
        OnboardingPage(
            type: .welcome,
            backgroundImageName: "onboarding_background_bee",
            headline1: "Your Digital Field Guide.",
            subheadline1: "Instantly identify insects and explore the wonders of the natural world."
        ),
        // Page 2: Snap, Identify, Discover
        OnboardingPage(
            type: .identify,
            headline2: "Point, Snap, and Identify.",
            phoneGraphicImageName: "onboarding_graphic_phone",
            lineArtBugImageName: "onboarding_graphic_dragonfly_lineart",
            idCardImageName: "onboarding_photo_dragonfly",
            idCardBugName: "Blue Dasher",
            idCardData: [
                ("Family", "Libellulidae"), 
                ("Habitat", "Ponds, Marshes")
            ],
            continueButtonText: "Continue"
        ),
        // Page 3: Build Your Collection
        OnboardingPage(
            type: .collect,
            headline3: "Curate Your Personal Collection.",
            body3: "Every insect you identify is saved to your personal, browsable journal.",
            collageCardDetails: [
                ("onboarding_card_ladybug", "Ladybug"), 
                ("onboarding_card_beetle", "Stag Beetle"), 
                ("onboarding_card_moth", "Luna Moth")
            ],
            startButtonText: "Start Exploring",
            startButtonBackgroundColor: ThemeColors.accent, // Warm Tan (#D4B79E)
            startButtonTextColor: ThemeColors.primaryText // Deep Forest Green (#2C3D34)
        )
    ]

    var body: some View {
        ZStack {
            // The TabView now acts as the base layer and can fill the whole screen
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingScreenView(page: pages[index], currentPage: $currentPage, isOnboardingComplete: $isOnboardingComplete)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.all) // Allow TabView content to go edge-to-edge

            // Overlay the progress indicator at the bottom
            VStack {
                Spacer()
                CustomProgressIndicator(numberOfPages: pages.count, currentPage: currentPage)
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Individual Onboarding Screen View
struct OnboardingScreenView: View {
    let page: OnboardingPage
    @Binding var currentPage: Int
    @Binding var isOnboardingComplete: Bool

    var body: some View {
        Group {
            switch page.type {
            case .welcome:
                WelcomeScreen(page: page)
            case .identify:
                IdentifyScreen(page: page, currentPage: $currentPage)
            case .collect:
                CollectScreen(page: page, isOnboardingComplete: $isOnboardingComplete)
            }
        }
    }
}

// MARK: - Screen 1: Welcome to the Field (Redesigned)
struct WelcomeScreen: View {
    let page: OnboardingPage
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Central Image
            if let imageName = page.backgroundImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200) // Adjust size as needed
                    .clipShape(Circle()) // Example styling
                    .shadow(color: ThemeColors.primaryText.opacity(0.2), radius: 10, x: 0, y: 5)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeIn(duration: 0.8).delay(0.2), value: showContent)
            }

            // Text Content
            VStack(spacing: 15) {
                SerifText(page.headline1 ?? "", size: 32, color: ThemeColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                
                Text(page.subheadline1 ?? "")
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(ThemeColors.primaryText.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeIn(duration: 0.8).delay(0.4), value: showContent)
            
            Spacer()
            Spacer() // Add more space at the bottom if needed, or adjust main Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            showContent = false // Reset for re-entry if view is reused
            withAnimation {
                showContent = true
            }
        }
    }
}

// MARK: - Screen 2: Snap, Identify, Discover (Redesigned)
struct IdentifyScreen: View {
    let page: OnboardingPage
    @Binding var currentPage: Int

    // Animation states
    @State private var showHeadline = false
    @State private var showLineArt = false
    @State private var scanLinePosition: CGFloat = -180
    @State private var showIdCard = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text(page.headline2 ?? "")
                .font(.custom("Georgia-Bold", size: 28))
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(showHeadline ? 1 : 0)

            // Animation Zone
            ZStack {
                // 1. The final ID card, initially hidden
                IdentificationCardPreview(page: page)
                    .opacity(showIdCard ? 1 : 0)

                // 2. The line art, which gets replaced by the ID card
                Image(page.lineArtBugImageName ?? "onboarding_graphic_dragonfly_lineart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(ThemeColors.primaryText.opacity(0.6))
                    .opacity(showLineArt && !showIdCard ? 1 : 0)

                // 3. The animated scan line
                if !showIdCard {
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: [ThemeColors.accent.opacity(0), ThemeColors.accent, ThemeColors.accent.opacity(0)]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 200, height: 5)
                        .shadow(color: ThemeColors.accent, radius: 10, y: 0)
                        .offset(y: scanLinePosition)
                }
            }
            .frame(height: 280) // Give the ZStack a fixed height

            Spacer()

            OnboardingButton(
                title: page.continueButtonText ?? "Continue",
                backgroundColor: ThemeColors.primaryText,
                textColor: ThemeColors.background
            ) {
                withAnimation {
                    if currentPage < 2 { currentPage += 1 }
                }
            }
            .opacity(showIdCard ? 1 : 0) // Button appears after animation

            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background.edgesIgnoringSafeArea(.all))
        .onAppear(perform: startAnimation)
    }

    private func startAnimation() {
        // Reset state for re-entry
        showHeadline = false
        showLineArt = false
        scanLinePosition = -180
        showIdCard = false

        // Animation sequence
        withAnimation(.easeIn(duration: 0.5)) {
            showHeadline = true
        }

        withAnimation(.easeIn(duration: 0.5).delay(0.5)) {
            showLineArt = true
        }

        withAnimation(.easeInOut(duration: 1.0).delay(1.2)) {
            scanLinePosition = 180
        }

        withAnimation(.easeIn(duration: 0.5).delay(2.0)) {
            showIdCard = true
        }
    }
}

// Helper for ID Card Preview on Page 2
struct IdentificationCardPreview: View {
    let page: OnboardingPage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(page.idCardImageName ?? "photo") // Placeholder for real bug photo
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
            
            SerifText(page.idCardBugName ?? "Bug Name", size: 20, color: ThemeColors.primaryText)
            
            ForEach(page.idCardData ?? [], id: \.label) { dataPoint in
                HStack {
                    Text(dataPoint.label + ":")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundColor(ThemeColors.primaryText.opacity(0.8))
                    Text(dataPoint.value)
                        .font(.system(size: 12, design: .default))
                        .foregroundColor(ThemeColors.primaryText.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: ThemeColors.primaryText.opacity(0.1), radius: 5, x: 0, y: 2)
        .frame(width: 170) // Fixed width for the card preview
    }
}

// MARK: - Screen 3: Build Your Collection (Redesigned)
struct CollectScreen: View {
    let page: OnboardingPage
    @Binding var isOnboardingComplete: Bool
    
    @State private var authError: String?
    @State private var showAlert = false
    @State private var isSigningIn = false // To show activity indicator

    // Animation states
    @State private var showText = false
    @State private var showCards = [false, false, false]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Animated Text
            VStack(spacing: 15) {
                SerifText(page.headline3 ?? "", size: 28)
                Text(page.body3 ?? "")
                    .font(.system(.body, design: .default))
                    .foregroundColor(ThemeColors.primaryText.opacity(0.8))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .opacity(showText ? 1 : 0)

            // Animated Card Stack
            ZStack {
                if let details = page.collageCardDetails, details.count == 3 {
                    // Card 3 (Bottom)
                    createCardView(details[2].imageName, rotation: 6, offset: 50, show: showCards[2])

                    // Card 2 (Middle)
                    createCardView(details[1].imageName, rotation: -3, offset: 0, show: showCards[1])

                    // Card 1 (Top)
                    createCardView(details[0].imageName, rotation: 2, offset: -50, show: showCards[0])
                }
            }
            .frame(height: 350)

            Spacer()

            Group {
                if isSigningIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: page.startButtonTextColor ?? ThemeColors.primaryText))
                        .padding(.vertical, 15) // Match button padding
                        .frame(maxWidth: .infinity)
                        .background(page.startButtonBackgroundColor ?? ThemeColors.accent)
                        .cornerRadius(12)
                        .shadow(color: ThemeColors.primaryText.opacity(0.1), radius: 5, x: 0, y: 2)
                } else {
                    OnboardingButton(
                        title: page.startButtonText ?? "Start Exploring",
                        backgroundColor: page.startButtonBackgroundColor ?? ThemeColors.accent,
                        textColor: page.startButtonTextColor ?? ThemeColors.primaryText
                    ) {
                        // Check if a user session already exists
                        if AuthService.shared.user != nil {
                            print("User already authenticated. Completing onboarding.")
                            // The user is already logged in, so just complete the onboarding.
                            // The check in ContentView's onAppear will handle Firestore document creation.
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isOnboardingComplete = true
                            }
                        } else {
                            // No user, proceed with anonymous sign-in
                            isSigningIn = true
                            AuthService.shared.signInAnonymously { success, error in
                                isSigningIn = false
                                if success {
                                    print("Anonymous sign-in successful from Onboarding.")
                                    // The signInAnonymously function now handles document creation.
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        isOnboardingComplete = true
                                    }
                                } else {
                                    print("Anonymous sign-in failed: \(error?.localizedDescription ?? "Unknown error")")
                                    self.authError = error?.localizedDescription ?? "An unknown error occurred during sign-in."
                                    self.showAlert = true
                                }
                            }
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Sign-In Failed"),
                    message: Text(authError ?? "An unknown error occurred."),
                    dismissButton: .default(Text("OK"))
                )
            }.opacity(showCards.allSatisfy { $0 } ? 1 : 0) // Appear when cards are shown
            .animation(.easeIn.delay(1.5), value: showCards.allSatisfy { $0 })

            Spacer().frame(height: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background.edgesIgnoringSafeArea(.all))
        .onAppear(perform: startAnimation)
    }

    private func createCardView(_ imageName: String, rotation: Double, offset: CGFloat, show: Bool) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 180)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .rotationEffect(.degrees(show ? rotation : rotation + 10))
            .offset(y: show ? offset : offset + 500) // Animate from bottom
            .opacity(show ? 1 : 0)
    }

    private func startAnimation() {
        // Reset
        showText = false
        showCards = [false, false, false]

        // Animate
        withAnimation(.easeIn(duration: 0.8)) {
            showText = true
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
            showCards[0] = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7)) {
            showCards[1] = true
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.9)) {
            showCards[2] = true
        }
    }
}

// MARK: - Generic Onboarding Button
struct OnboardingButton: View {
    let title: String
    let backgroundColor: Color
    let textColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
                .cornerRadius(12)
                .shadow(color: backgroundColor.opacity(0.4), radius: 8, y: 4)
        }
        .padding(.horizontal, 50)
    }
}

// MARK: - Custom Progress Indicator (Redesigned for Visibility)
struct CustomProgressIndicator: View {
    let numberOfPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? .white : Color.white.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: currentPage)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.black.opacity(0.3))
        .clipShape(Capsule())
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingComplete: .constant(false))
    }
}
