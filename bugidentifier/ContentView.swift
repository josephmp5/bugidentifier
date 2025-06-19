//
//  ContentView.swift
//  bugidentifier
//
//  Created by Yakup Özmavi on 15.06.2025.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete: Bool = false
    @AppStorage("hasPresentedInitialPaywall") private var hasPresentedInitialPaywall: Bool = false
    @StateObject private var authService = AuthService.shared
    @State private var showPaywall: Bool = false

    var body: some View {
        if isOnboardingComplete {
            MainTabView()
                .onAppear {
                    // Check for and create a user document in Firestore if it doesn't exist.
                    authService.checkAndCreateUserDocumentIfNeeded()

                    // Check if user is signed in (should be anonymous at this point)
                    // and if the initial paywall hasn't been shown yet.
                    if authService.user != nil && !hasPresentedInitialPaywall {
                        showPaywall = true
                        hasPresentedInitialPaywall = true // Mark as presented
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView() // Assuming PaywallView handles its own dismissal or environment
                }
        } else {
            OnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
