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
                            .onDisappear {
                                // Clear the new registration flag after profile setup
                                SessionManager.shared.clearNewRegistrationFlag()
                            }
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
                        SessionManager.shared.resetNavigationFlag()
                    }
            }
        }
        .onAppear {
            performInitialChecks()
        }
    }
    
    func performInitialChecks() {
        // Validate session on app launch
        if SessionManager.shared.isLoggedIn {
            let isValid = SessionManager.shared.validateSession()
            if !isValid {
                print("❌ Invalid session detected on app launch")
                // Session validation failed, user will be logged out
            } else {
                // Session is valid, check profile status
                checkProfileStatus()
            }
        } else {
            // Not logged in, no need to check profile
            checkingProfile = false
        }
    }
    
    func checkProfileStatus() {
        guard SessionManager.shared.isLoggedIn else {
            checkingProfile = false
            return
        }
        
        print("🔍 Checking profile status...")
        print("🆕 Is new registration: \(SessionManager.shared.isNewRegistration)")
        
        // Only force profile setup for NEW registrations
        if SessionManager.shared.isNewRegistration {
            print("🆕 New registration detected - forcing profile setup")
            checkingProfile = false
            needsProfileSetup = true
            return
        }
        
        // For existing users, just go to dashboard
        // The dashboard will show the welcome card if they don't have a profile
        print("👤 Existing user - proceeding to dashboard")
        checkingProfile = false
        needsProfileSetup = false
        
        // Let ProfileManager fetch the profile in the background
        // Dashboard will handle showing the welcome card if needed
        profileManager.fetchProfile(force: false)
    }
}

#Preview {
    ContentView()
}
