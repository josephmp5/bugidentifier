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
                    // When the main view appears, check if the user is authenticated.
                    // If they are, and we haven't shown them the paywall yet, present it.
                    if authService.user != nil && !hasPresentedInitialPaywall {
                        showPaywall = true
                        hasPresentedInitialPaywall = true // Ensure it only shows once per install.
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    // The paywall is presented modally and cannot be dismissed by swiping.
                    PaywallView(isModal: true)
                        .interactiveDismissDisabled()
                }
        } else {
            // If onboarding is not complete, show the OnboardingView.
            OnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
