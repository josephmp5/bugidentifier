import SwiftUI

import SwiftUI

// Re-using SerifText or defining a similar one if preferred for local context
// For consistency, ensure this matches the one in ResultsView or move to a shared location.
// For this example, I'll assume SerifText is accessible or redefine a similar local one if needed.
// Let's assume SerifText from Color+Theme.swift or ResultsView.swift is available.

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared

    // Define the grid layout: 2 columns, flexible spacing
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                if historyManager.history.isEmpty {
                    emptyStateView
                        .padding(.top, 50) // Give some space from the nav bar
                } else {
                    historyGridView
                }
            }
            .background(ThemeColors.background.edgesIgnoringSafeArea(.all))
            .navigationTitle("My Collection")
            .navigationBarTitleDisplayMode(.inline) // Or .large for a different feel
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !historyManager.history.isEmpty {
                        Button {
                            // Action for Sort
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .foregroundColor(ThemeColors.primaryText)
                        }

                        Button {
                            // Action for Filter
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(ThemeColors.primaryText)
                        }
                        Button {
                            historyManager.clearHistory()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(ThemeColors.accent) // Use accent for destructive potentially
                        }
                    }
                }
            }
            .onAppear {
                 // Set navigation bar appearance for this view
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(ThemeColors.background) // Off-white background
                appearance.titleTextAttributes = [.foregroundColor: UIColor(ThemeColors.primaryText)] // Deep green title
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(ThemeColors.primaryText)]

                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance // For inline
            }
        }
        .accentColor(ThemeColors.primaryText) // Sets default tint for controls like back button
    }

    private var historyGridView: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(historyManager.history) { item in
                VStack(spacing: 8) {
                    item.image
                        .resizable()
                        .scaledToFill()
                        .frame(width: (UIScreen.main.bounds.width / 2) - 32, height: (UIScreen.main.bounds.width / 2) - 32) // Maintain aspect ratio for circle
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ThemeColors.primaryText.opacity(0.2), lineWidth: 1))
                        .shadow(color: ThemeColors.primaryText.opacity(0.1), radius: 3, y: 2)

                    SerifText(item.bugName, size: 16, color: ThemeColors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
//                    Text(item.identificationDate, style: .date)
//                        .font(.caption)
//                        .foregroundColor(ThemeColors.primaryText.opacity(0.7))
                }
            }
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill") // Thematic icon
                .font(.system(size: 60))
                .foregroundColor(ThemeColors.accent)
            SerifText("Your Collection is Empty", size: 22, color: ThemeColors.primaryText)
            Text("Identified insects will appear here. Start exploring!")
                .font(.system(.body, design: .default))
                .foregroundColor(ThemeColors.primaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal)
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
