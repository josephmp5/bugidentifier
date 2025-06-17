import SwiftUI

struct MainTabView: View {
    var body: some View {
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
        .accentColor(.appThemePrimary)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
