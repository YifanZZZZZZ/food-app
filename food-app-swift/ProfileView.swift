//
//  ProfileView.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 7/13/25.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var session = SessionManager.shared
    @ObservedObject var profileManager = ProfileManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var showEditProfile = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color(red: 0.1, green: 0.1, blue: 0.15)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if profileManager.isLoading && profileManager.userProfile == nil {
                    // Loading state
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(1.5)
                        
                        Text("Loading your profile...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else if let profile = profileManager.userProfile {
                    // Profile loaded
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header with Profile Picture
                            profileHeaderSection(profile: profile)
                            
                            // Stats Cards
                            profileStatsSection(profile: profile)
                            
                            // Settings Section
                            settingsSection(profile: profile)
                            
                            // Danger Zone
                            dangerZoneSection()
                            
                            // App Info
                            appInfoSection()
                        }
                        .padding(.horizontal)
                    }
                } else {
                    // No profile found or error state
                    VStack(spacing: 20) {
                        if let errorMessage = profileManager.errorMessage {
                            // Show error with retry option
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Profile Error")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: {
                                print("🔄 Retry button tapped")
                                profileManager.fetchProfile(force: true)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Retry")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        } else {
                            // Profile not found - needs setup
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.orange.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Profile Not Found")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                
                                Text("Complete your profile setup to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: { showEditProfile = true }) {
                                HStack {
                                    Image(systemName: "person.fill.badge.plus")
                                    Text("Complete Profile")
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if profileManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(0.8)
                    } else {
                        Button(action: {
                            print("🔄 Manual refresh button tapped")
                            profileManager.fetchProfile(force: true)
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.orange)
                }
            }
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    print("👤 ProfileView appeared - forcing profile refresh")
                    profileManager.fetchProfile(force: true)
                }
            }
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    performLogout()
                }
            } message: {
                Text("Are you sure you want to logout? You'll need to login again to access your meals.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showEditProfile) {
                ProfileSetupView(existingProfile: profileManager.userProfile)
                    .onDisappear {
                        // Force refresh after profile setup/edit
                        print("📝 Profile setup/edit completed, refreshing profile")
                        profileManager.fetchProfile(force: true)
                    }
            }
            .refreshable {
                await refreshProfile()
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    func profileHeaderSection(profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange, .orange.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Text(session.userName.prefix(1).uppercased())
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .orange.opacity(0.3), radius: 20)
            
            VStack(spacing: 4) {
                Text(session.userName)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("\(profile.age) years old • \(profile.gender)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let lastSync = profileManager.lastSyncDate {
                    Text("Last synced: \(formatSyncDate(lastSync))")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            
            // Edit Profile Button
            Button(action: { showEditProfile = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Profile")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.top, 20)
    }
    
    @ViewBuilder
    func profileStatsSection(profile: UserProfile) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Daily Goal",
                value: "\(profile.calorieTarget)",
                unit: "kcal",
                icon: "target",
                color: .orange
            )
            
            StatCard(
                title: "Activity",
                value: profile.activityLevelText(),
                unit: "",
                icon: "figure.run",
                color: .green
            )
        }
    }
    
    @ViewBuilder
    func settingsSection(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.fill",
                    title: "Personal Information",
                    subtitle: "\(profile.age) years • \(profile.gender) • \(profile.activityLevelText())",
                    action: { showEditProfile = true }
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                SettingsRow(
                    icon: "target",
                    title: "Nutrition Goals",
                    subtitle: "\(profile.calorieTarget) kcal daily target",
                    action: { showEditProfile = true }
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                SettingsRow(
                    icon: "leaf.fill",
                    title: "Dietary Preferences",
                    subtitle: profile.dietaryPreferencesText,
                    action: { showEditProfile = true }
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Meal reminders and tips",
                    action: { /* TODO: Add notifications settings */ }
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "FAQ and contact support",
                    action: { /* TODO: Add help */ }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    func dangerZoneSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "arrow.right.square.fill",
                    title: "Logout",
                    subtitle: "Sign out of your account",
                    titleColor: .red,
                    action: { showLogoutAlert = true }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    func appInfoSection() -> some View {
        VStack(spacing: 8) {
            Text("NutriSnap")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text("Version 1.0.0")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Functions
    
    func formatSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func refreshProfile() async {
        await withCheckedContinuation { continuation in
            print("🔄 Pull-to-refresh triggered")
            profileManager.fetchProfile(force: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                continuation.resume()
            }
        }
    }
    
    func performLogout() {
        isLoggingOut = true
        
        // Clear profile data
        profileManager.clearProfile()
        
        // Clear session
        session.logout()
        
        // Small delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoggingOut = false
            self.dismiss()
        }
    }
}

// MARK: - Supporting Views (StatCard and SettingsRow remain the same)

struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 2) {
                    Text(value)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var titleColor: Color = .white
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(titleColor == .white ? .orange : titleColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(titleColor)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
