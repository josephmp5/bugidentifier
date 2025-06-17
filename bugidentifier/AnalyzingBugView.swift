import SwiftUI

struct AnalyzingBugView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(Color.themeAccent)
                .rotationEffect(.degrees(isAnimating ? 15 : -15))
                .animation(
                    Animation.easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("Analyzing Image...")
                .font(.headline)
                .foregroundColor(Color.themeText)
            
            Text("Please wait a moment.")
                .font(.subheadline)
                .foregroundColor(Color.themeSecondaryText)
        }
        .padding(40)
        .background(Color.themeBackground.opacity(0.95))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .onAppear {
            isAnimating = true
        }
    }
}

struct AnalyzingBugView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3).edgesIgnoringSafeArea(.all)
            AnalyzingBugView()
        }
    }
}
