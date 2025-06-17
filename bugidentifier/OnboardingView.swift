import SwiftUI

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
            backgroundImageName: "metallic_green_bee_placeholder", // Replace with actual asset name
            headline1: "Your Digital Field Guide.",
            subheadline1: "Instantly identify insects and explore the wonders of the natural world."
        ),
        // Page 2: Snap, Identify, Discover
        OnboardingPage(
            type: .identify,
            headline2: "Point, Snap, and Identify.",
            phoneGraphicImageName: "phone_camera_graphic_placeholder", // Replace
            lineArtBugImageName: "dragonfly_line_art_placeholder",   // Replace
            idCardImageName: "blue_dasher_real_photo_placeholder", // Replace
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
                ("ladybug_card_placeholder", "Ladybug"), 
                ("beetle_card_placeholder", "Stag Beetle"), 
                ("moth_card_placeholder", "Luna Moth")
            ],
            startButtonText: "Start Exploring",
            startButtonBackgroundColor: ThemeColors.accent, // Warm Tan (#D4B79E)
            startButtonTextColor: ThemeColors.primaryText // Deep Forest Green (#2C3D34)
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingScreenView(page: pages[index], currentPage: $currentPage, isOnboardingComplete: $isOnboardingComplete)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Hide default page dots

            CustomProgressIndicator(numberOfPages: pages.count, currentPage: currentPage)
                .padding(.bottom, 20)
        }
        .background(Color.themeBackground.edgesIgnoringSafeArea(.all))
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

// MARK: - Screen 1: Welcome to the Field
struct WelcomeScreen: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            // Background Image
            Image(page.backgroundImageName ?? "photo") // Use placeholder if name is nil
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
                .overlay(Color.black.opacity(0.2)) // Dimming for text contrast

            VStack(spacing: 20) {
                Spacer()
                VStack(spacing: 15) {
                    SerifText(page.headline1 ?? "", size: 36, color: .white) // Text color white for dark bg
                        .multilineTextAlignment(.center)
                    
                    Text(page.subheadline1 ?? "")
                        .font(.system(.body, design: .default))
                        .foregroundColor(Color.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(30)
                .background(.regularMaterial) // Frosted glass effect
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 30)
                
                Spacer()
                Spacer() 
            }
        }
    }
}

// MARK: - Screen 2: Snap, Identify, Discover
struct IdentifyScreen: View {
    let page: OnboardingPage
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text(page.headline2 ?? "")
                .font(.custom("Georgia-Bold", size: 28)) // Serif headline
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(alignment: .center, spacing: 15) {
                // Left: Stylized phone graphic + line art bug
                VStack {
                    Image(systemName: page.phoneGraphicImageName ?? "iphone.gen2") // Placeholder
                        .font(.system(size: 80))
                        .foregroundColor(ThemeColors.primaryText)
                    Image(systemName: page.lineArtBugImageName ?? "ant") // Placeholder
                        .font(.system(size: 40))
                        .foregroundColor(ThemeColors.primaryText.opacity(0.7))
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ThemeColors.accent)

                // Right: Finished Identification Card
                IdentificationCardPreview(page: page)
            }
            .padding(.horizontal)
            
            Spacer()
            
            OnboardingButton(
                title: page.continueButtonText ?? "Continue",
                backgroundColor: ThemeColors.primaryText, // Deep forest green
                textColor: ThemeColors.background // Off-white text
            ) {
                withAnimation {
                    if currentPage < 2 { currentPage += 1 }
                }
            }
            Spacer().frame(height: 20) // Space from bottom edge for button
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background.edgesIgnoringSafeArea(.all)) // Off-white background
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

// MARK: - Screen 3: Build Your Collection
struct CollectScreen: View {
    let page: OnboardingPage
    @Binding var isOnboardingComplete: Bool

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text(page.headline3 ?? "")
                .font(.custom("Georgia-Bold", size: 28)) // Authoritative serif font
                .foregroundColor(ThemeColors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Collage of Identification Cards
            ZStack {
                ForEach(0..<(page.collageCardDetails?.count ?? 0), id: \.self) { index in
                    SmallIdCardView(detail: page.collageCardDetails![index])
                        .rotationEffect(.degrees(Double(index * 10 - 10))) // Slight rotation for collage effect
                        .offset(x: CGFloat(index * 20 - 20), y: CGFloat(index * 15 - 15)) // Staggered offset
                }
            }
            .frame(height: 200) // Adjust height for collage visibility

            Text(page.body3 ?? "")
                .font(.system(.body, design: .default))
                .foregroundColor(ThemeColors.primaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            OnboardingButton(
                title: page.startButtonText ?? "Start Exploring",
                backgroundColor: page.startButtonBackgroundColor ?? ThemeColors.accent,
                textColor: page.startButtonTextColor ?? ThemeColors.primaryText
            ) {
                isOnboardingComplete = true
            }
            Spacer().frame(height: 20) // Space from bottom edge for button
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background.edgesIgnoringSafeArea(.all)) // Off-white background
    }
}

// Helper for Small ID Card in Collage on Page 3
struct SmallIdCardView: View {
    let detail: (imageName: String, bugName: String)
    var body: some View {
        VStack(spacing: 4) {
            Image(detail.imageName) // Placeholder
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 70)
                .clipped()
                .cornerRadius(6)
            SerifText(detail.bugName, size: 14, color: ThemeColors.primaryText)
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: ThemeColors.primaryText.opacity(0.15), radius: 6, x: 0, y: 3)
        .frame(width: 120, height: 110)
    }
}

// MARK: - Generic Onboarding Button (Modified to accept text color)
struct OnboardingButton: View {
    let title: String
    let backgroundColor: Color
    let textColor: Color // Added for Page 3 button
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

// MARK: - Custom Progress Indicator (Updated Styling)
struct CustomProgressIndicator: View {
    let numberOfPages: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 10) { // Increased spacing for better visual separation
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? ThemeColors.primaryText : ThemeColors.primaryText.opacity(0.3))
                    .frame(width: 10, height: 10) // Slightly larger dots
                    .animation(.spring(), value: currentPage) // Animate dot change
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
