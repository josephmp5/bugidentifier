import SwiftUI

struct MainTabView: View {
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            TabView {
                CameraGalleryView()
                    .tabItem {
                        Label("Identify", systemImage: "camera.viewfinder")
                    }

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.fill")
                    }
            }
            .navigationTitle("Bug Identifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showPaywall = true
                    }) {
                        Image(systemName: "crown.fill")
                    }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .accentColor(.appThemePrimary)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(PurchasesManager.shared) // For previewing
    }
}
