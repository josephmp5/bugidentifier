//
//  ContentView.swift
//  bugidentifier
//
//  Created by Yakup Özmavi on 15.06.2025.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete: Bool = false

    var body: some View {
        if isOnboardingComplete {
            CameraGalleryView()
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
