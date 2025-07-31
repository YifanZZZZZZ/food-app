//
//  ContentView.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/17/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var session = SessionManager.shared
    @ObservedObject var profileManager = ProfileManager.shared
    @State private var checkingProfile = true
    @State private var needsProfileSetup = false
    
    var body: some View {
        NavigationStack {
            Group {
                if session.isLoggedIn {
                    if checkingProfile {
                        // Loading state while checking profile
                        LoadingView()
                    } else if needsProfileSetup {
                        // Redirect to profile setup for new users
                        ProfileSetupView()
                            .navigationBarHidden(true)
                    } else {
                        // Normal dashboard for users with profiles
                        DashboardView()
                            .navigationBarHidden(true)
                    }
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
        .onAppear {
            checkProfileStatus()
        }
    }
    
    func checkProfileStatus() {
        guard session.isLoggedIn else {
            checkingProfile = false
            return
        }
        
        // Check if profile exists
        profileManager.fetchProfile(force: true)
        
        // Wait a moment for the fetch to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkingProfile = false
            needsProfileSetup = profileManager.userProfile == nil && !profileManager.isLoading
        }
    }
}

#Preview {
    ContentView()
}
