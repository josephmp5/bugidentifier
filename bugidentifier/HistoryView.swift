import SwiftUI

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showingClearAlert = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                if historyManager.history.isEmpty {
                    emptyStateView
                        .padding(.top, 50)
                } else {
                    historyGridView
                }
            }
            .background(ThemeColors.background.edgesIgnoringSafeArea(.all))
            .navigationTitle("My Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !historyManager.history.isEmpty {
                        Button {
                            showingClearAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(ThemeColors.accent)
                        }
                    }
                }
            }
            .alert(isPresented: $showingClearAlert) {
                Alert(
                    title: Text("Clear History"),
                    message: Text("Are you sure you want to delete all identification history? This action cannot be undone."),
                    primaryButton: .destructive(Text("Clear")) {
                        historyManager.clearHistory()
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(ThemeColors.background)
                appearance.titleTextAttributes = [.foregroundColor: UIColor(ThemeColors.primaryText)]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(ThemeColors.primaryText)]

                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
        }
        .accentColor(ThemeColors.primaryText)
    }

    private var historyGridView: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(historyManager.history) { item in
                VStack(spacing: 8) {
                    item.image
                        .resizable()
                        .scaledToFill()
                        .frame(width: (UIScreen.main.bounds.width / 2) - 32, height: (UIScreen.main.bounds.width / 2) - 32)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ThemeColors.primaryText.opacity(0.2), lineWidth: 1))
                        .shadow(color: ThemeColors.primaryText.opacity(0.1), radius: 3, y: 2)

                    SerifText(item.bugName, size: 16, color: ThemeColors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(item.identificationDate, style: .date)
                        .font(.caption)
                        .foregroundColor(ThemeColors.primaryText.opacity(0.7))
                }
                .contextMenu {
                    Button(role: .destructive) {
                        delete(item: item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding()
    }

    private func delete(item: IdentificationHistory) {
        if let index = historyManager.history.firstIndex(where: { $0.id == item.id }) {
            historyManager.history.remove(at: index)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
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
