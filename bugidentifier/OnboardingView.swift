import SwiftUI
import FirebaseAuth

// MARK: - Data Model for Onboarding Pages
enum OnboardingPageType {
    case welcome, identify, collect
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let type: OnboardingPageType
    
    // Page 1: Welcome
    var backgroundImageName: String?
    var headline1: String?
    var subheadline1: String?

    // Page 2: Snap, Identify, Discover
    var headline2: String?
    var lineArtBugImageName: String?
    var idCardImageName: String?
    var idCardBugName: String?
    var idCardData: [(label: String, value: String)]?
    var continueButtonText: String?

    // Page 3: Build Your Collection
    var headline3: String?
    var body3: String?
    var cardImageNames: [String]?
    var startButtonText: String?
    var startButtonBackgroundColor: Color?
    var startButtonTextColor: Color?
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0

    let pages: [OnboardingPage] = [
        OnboardingPage(
            type: .welcome,
            backgroundImageName: "onboarding_background_bee",
            headline1: "Your Digital Field Guide.",
            subheadline1: "Instantly identify insects and explore the wonders of the natural world."
        ),
        OnboardingPage(
            type: .identify,
            headline2: "Point, Snap, and Identify.",
            lineArtBugImageName: "onboarding_graphic_dragonfly_lineart",
            idCardImageName: "onboarding_photo_dragonfly",
            idCardBugName: "Blue Dasher",
            idCardData: [("Family", "Libellulidae"), ("Habitat", "Ponds, Marshes")],
            continueButtonText: "Continue"
        ),
        OnboardingPage(
            type: .collect,
            headline3: "Curate Your Personal Collection.",
            body3: "Every insect you identify is saved to your personal, browsable journal.",
            cardImageNames: ["onboarding_card_moth", "onboarding_card_ladybug", "onboarding_card_beetle"],
            startButtonText: "Start Exploring",
            startButtonBackgroundColor: ThemeColors.accent,
            startButtonTextColor: ThemeColors.primaryText
        )
    ]

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingScreenView(page: pages[index], currentPage: $currentPage, isOnboardingComplete: $isOnboardingComplete)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                CustomProgressIndicator(numberOfPages: pages.count, currentPage: currentPage)
                    .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Individual Onboarding Screen Router
struct OnboardingScreenView: View {
    let page: OnboardingPage
    @Binding var currentPage: Int
    @Binding var isOnboardingComplete: Bool

    var body: some View {
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

// MARK: - Screen 1: Welcome
struct WelcomeScreen: View {
    let page: OnboardingPage
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            if let imageName = page.backgroundImageName {
                Image(imageName)
                    .resizable().scaledToFit().frame(width: 200, height: 200)
                    .clipShape(Circle()).shadow(color: ThemeColors.primaryText.opacity(0.2), radius: 10, y: 5)
                    .opacity(showContent ? 1 : 0).animation(.easeIn(duration: 0.8).delay(0.2), value: showContent)
            }
            VStack(spacing: 15) {
                SerifText(page.headline1 ?? "", size: 32, color: ThemeColors.primaryText)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.75)
                Text(page.subheadline1 ?? "")
                    .font(.system(size: 17)).foregroundColor(ThemeColors.primaryText.opacity(0.7))
                    .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 40).opacity(showContent ? 1 : 0).animation(.easeIn(duration: 0.8).delay(0.4), value: showContent)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(ThemeColors.background.edgesIgnoringSafeArea(.all))
        .onAppear { showContent = false; withAnimation { showContent = true } }
    }
}

// MARK: - Screen 2: Identify
struct IdentifyScreen: View {
    let page: OnboardingPage
    @Binding var currentPage: Int
    @State private var showHeadline = false
    @State private var showLineArt = false
    @State private var showIdCard = false
    @State private var scanLinePosition: CGFloat = -180

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            Text(page.headline2 ?? "").font(.custom("Georgia-Bold", size: 28)).foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center).padding(.horizontal).opacity(showHeadline ? 1 : 0)
            ZStack {
                IdentificationCardPreview(page: page).opacity(showIdCard ? 1 : 0)
                Image(page.lineArtBugImageName ?? "").resizable().scaledToFit().frame(width: 150, height: 150)
                    .foregroundColor(ThemeColors.primaryText.opacity(0.6)).opacity(showLineArt && !showIdCard ? 1 : 0)
                if !showIdCard {
                    Capsule().fill(LinearGradient(colors: [.clear, ThemeColors.accent, .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 200, height: 5).shadow(color: ThemeColors.accent, radius: 10, y: 0).offset(y: scanLinePosition)
                }
            }.frame(height: 280)
            Spacer()
            OnboardingButton(title: page.continueButtonText ?? "Continue", backgroundColor: ThemeColors.primaryText, textColor: ThemeColors.background) {
                withAnimation { if currentPage < 2 { currentPage += 1 } }
            }.opacity(showIdCard ? 1 : 0)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(ThemeColors.background.edgesIgnoringSafeArea(.all))
        .onAppear(perform: startAnimation)
    }

    private func startAnimation() {
        showHeadline = false
        showLineArt = false
        scanLinePosition = -180
        showIdCard = false
        withAnimation(.easeIn(duration: 0.5)) { showHeadline = true }
        withAnimation(.easeIn(duration: 0.5).delay(0.5)) { showLineArt = true }
        withAnimation(.easeInOut(duration: 1.0).delay(1.2)) { scanLinePosition = 180 }
        withAnimation(.easeIn(duration: 0.5).delay(2.0)) { showIdCard = true }
    }
}

// MARK: - Screen 3: Collect
struct CollectScreen: View {
    let page: OnboardingPage
    @Binding var isOnboardingComplete: Bool
    @State private var showContent = false
    @State private var showCards = false
    @State private var isSigningIn = false
    @State private var showAlert = false
    @State private var authError: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 15) {
                SerifText(page.headline3 ?? "", size: 28, color: ThemeColors.primaryText).multilineTextAlignment(.center)
                Text(page.body3 ?? "").font(.system(size: 17)).foregroundColor(ThemeColors.primaryText.opacity(0.7)).multilineTextAlignment(.center)
            }.padding(.horizontal, 40)

            if let cardNames = page.cardImageNames {
                CardDeckView(cardImageNames: cardNames, showCards: $showCards)
            }
            
            Spacer()

            if isSigningIn {
                ProgressView()
            } else {
                OnboardingButton(title: page.startButtonText ?? "Start Exploring", backgroundColor: page.startButtonBackgroundColor ?? .blue, textColor: page.startButtonTextColor ?? .white, action: handleSignIn)
            }
            
            Spacer().frame(height: 80) // This provides the necessary space for the progress indicator below
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(ThemeColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            showContent = false
            showCards = false
            withAnimation(.easeIn(duration: 0.5)) { showContent = true }
            withAnimation { showCards = true }
        }
        .alert("Sign-In Failed", isPresented: $showAlert, presenting: authError) { _ in
            Button("OK") {}
        } message: { error in
            Text(error)
        }
    }

    private func handleSignIn() {
        isSigningIn = true
        AuthService.shared.signInAnonymously { result in
            isSigningIn = false
            if case .failure(let error) = result {
                self.authError = error.localizedDescription
                self.showAlert = true
            } else {
                isOnboardingComplete = true
            }
        }
    }
}

// MARK: - Helper Views
struct CardDeckView: View {
    let cardImageNames: [String]
    @Binding var showCards: Bool

    var body: some View {
        ZStack {
            ForEach(Array(zip(cardImageNames.indices, cardImageNames)), id: \.0) { index, imageName in
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    .rotationEffect(.degrees((Double(index) - 1.0) * 15.0))
                    .offset(x: CGFloat(index - 1) * 50, y: 0)
                    .opacity(showCards ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0).delay(0.1 * Double(index)), value: showCards)
            }
        }
        .frame(height: 300)
    }
}

struct IdentificationCardPreview: View {
    let page: OnboardingPage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(page.idCardImageName ?? "").resizable().aspectRatio(contentMode: .fill)
                .frame(height: 120).clipped().cornerRadius(8)
            SerifText(page.idCardBugName ?? "", size: 20, color: ThemeColors.primaryText)
            ForEach(page.idCardData ?? [], id: \.label) { dataPoint in
                HStack {
                    Text(dataPoint.label + ":").font(.system(size: 12, weight: .semibold)).foregroundColor(ThemeColors.primaryText.opacity(0.8))
                    Text(dataPoint.value).font(.system(size: 12)).foregroundColor(ThemeColors.primaryText.opacity(0.7))
                }
            }
        }
        .padding(12).background(Color.white).cornerRadius(10)
        .shadow(color: ThemeColors.primaryText.opacity(0.1), radius: 5, y: 2).frame(width: 170)
    }
}

struct OnboardingButton: View {
    let title: String, backgroundColor: Color, textColor: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).fontWeight(.bold).foregroundColor(textColor)
                .padding().frame(maxWidth: .infinity).background(backgroundColor)
                .cornerRadius(12).shadow(color: backgroundColor.opacity(0.4), radius: 8, y: 4)
        }.padding(.horizontal, 50)
    }
}

struct CustomProgressIndicator: View {
    let numberOfPages: Int, currentPage: Int

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? ThemeColors.accent : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .animation(.spring(), value: currentPage)
            }
        }
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingComplete: .constant(false))
    }
}
