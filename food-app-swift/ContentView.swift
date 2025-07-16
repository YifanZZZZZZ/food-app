//
//  ContentView.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/17/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var session = SessionManager.shared
    
    var body: some View {
        NavigationStack {
            Group {
                if session.isLoggedIn {
                    DashboardView()
                        .navigationBarHidden(true)
                } else {
                    OnboardingView()
                        .navigationBarHidden(true)
                }
            }
            .navigationDestination(isPresented: $session.shouldNavigateToLogin) {
                OnboardingView()
                    .navigationBarBackButtonHidden(true)
                    .onAppear {
                        session.resetNavigationFlag()
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
