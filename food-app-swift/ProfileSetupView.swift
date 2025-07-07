import SwiftUI

struct ProfileSetupView: View {
    @ObservedObject var session = SessionManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var age: Double = 25
    @State private var gender: String = "Select"
    @State private var activityLevel = "2"
    @State private var calorieTarget: Double = 2200
    @State private var isVegetarian = false
    @State private var isKeto = false
    @State private var isGlutenFree = false
    @State private var navigateToDashboard = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showLoadingOverlay = false
    @State private var loadingMessage = "Setting up your profile..."

    let genderOptions = ["Male", "Female", "Other"]
    let activityOptions = [
        ("1", "Sedentary", "Little to no exercise"),
        ("2", "Lightly Active", "Exercise 1-3 days/week"),
        ("3", "Active", "Exercise 3-5 days/week"),
        ("4", "Very Active", "Exercise 6-7 days/week")
    ]

    var body: some View {
        NavigationStack {
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

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            // Progress Indicator
                            HStack(spacing: 8) {
                                ForEach(1...3, id: \.self) { step in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(step <= 2 ? Color.orange : Color.white.opacity(0.2))
                                        .frame(height: 6)
                                }
                            }
                            .padding(.horizontal, 80)
                            
                            VStack(spacing: 8) {
                                Text("Complete Your Profile")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Help us personalize your nutrition journey")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 20)

                        // Personal Info Section
                        VStack(alignment: .leading, spacing: 20) {
                            SectionHeader(title: "Personal Information", icon: "person.fill", color: Color.orange)
                            
                            // Age Slider
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Age")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Text("\(Int(age)) years")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Slider(value: $age, in: 10...80, step: 1)
                                    .accentColor(.orange)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )

                            // Gender Selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Gender")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack(spacing: 12) {
                                    ForEach(genderOptions, id: \.self) { option in
                                        GenderButton(
                                            title: option,
                                            isSelected: gender == option,
                                            action: { gender = option }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Activity Level Section
                        VStack(alignment: .leading, spacing: 20) {
                            SectionHeader(title: "Activity Level", icon: "figure.run", color: Color.green)
                            
                            VStack(spacing: 12) {
                                ForEach(activityOptions, id: \.0) { option in
                                    ActivityLevelCard(
                                        level: option.0,
                                        title: option.1,
                                        description: option.2,
                                        isSelected: activityLevel == option.0,
                                        action: { activityLevel = option.0 }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Nutrition Goals Section
                        VStack(alignment: .leading, spacing: 20) {
                            SectionHeader(title: "Nutrition Goals", icon: "target", color: Color.purple)
                            
                            // Calorie Target
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Daily Calorie Target")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Spacer()
                                    
                                    Text("\(Int(calorieTarget)) kcal")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                                
                                Slider(value: $calorieTarget, in: 1000...4000, step: 50)
                                    .accentColor(.orange)
                                
                                HStack {
                                    Text("1000")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("4000")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )

                            // Dietary Preferences
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Dietary Preferences")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                VStack(spacing: 12) {
                                    DietaryToggle(
                                        title: "Vegetarian",
                                        description: "No meat or fish",
                                        icon: "leaf.fill",
                                        isOn: $isVegetarian
                                    )
                                    
                                    DietaryToggle(
                                        title: "Keto",
                                        description: "Low carb, high fat",
                                        icon: "drop.fill",
                                        isOn: $isKeto
                                    )
                                    
                                    DietaryToggle(
                                        title: "Gluten-Free",
                                        description: "No gluten products",
                                        icon: "exclamationmark.triangle.fill",
                                        isOn: $isGlutenFree
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Save Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            saveProfile()
                        }) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Complete Setup")
                                        .fontWeight(.semibold)
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSaving || gender == "Select")
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationDestination(isPresented: $navigateToDashboard) {
                DashboardView()
                    .navigationBarBackButtonHidden(true)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay(
                // Loading overlay
                ZStack {
                    if showLoadingOverlay {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text(loadingMessage)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("This may take a moment...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                }
                .animation(.easeInOut, value: showLoadingOverlay)
            )
        }
    }

    func saveProfile() {
        guard gender != "Select" else {
            errorMessage = "Please select your gender"
            showError = true
            return
        }
        
        isSaving = true
        showLoadingOverlay = true
        loadingMessage = "Setting up your profile..."
        
        // Save to UserDefaults for dashboard
        UserDefaults.standard.set(Int(calorieTarget), forKey: "calorie_target")
        
        // Add a timeout timer
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            if self.showLoadingOverlay {
                self.showLoadingOverlay = false
                self.isSaving = false
                self.errorMessage = "Request timed out. The server might be starting up. Please try again in a moment."
                self.showError = true
            }
        }
        
        let payload: [String: Any] = [
            "user_id": session.userID,
            "age": Int(age),
            "gender": gender,
            "activity_level": activityLevel,
            "calorie_target": Int(calorieTarget),
            "is_vegetarian": isVegetarian,
            "is_keto": isKeto,
            "is_gluten_free": isGlutenFree
        ]

        guard let url = URL(string: "https://food-app-swift.onrender.com/save-profile"),
              let json = try? JSONSerialization.data(withJSONObject: payload) else {
            isSaving = false
            showLoadingOverlay = false
            errorMessage = "Failed to prepare data"
            showError = true
            timeoutTimer.invalidate()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json
        request.timeoutInterval = 30

        // First, ping the server to wake it up if needed
        if let pingURL = URL(string: "https://food-app-swift.onrender.com/ping") {
            var pingRequest = URLRequest(url: pingURL)
            pingRequest.timeoutInterval = 5
            
            loadingMessage = "Waking up server..."
            
            URLSession.shared.dataTask(with: pingRequest) { _, _, _ in
                // After ping, proceed with profile save
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadingMessage = "Saving your profile..."
                    self.performProfileSave(request: request, timeoutTimer: timeoutTimer)
                }
            }.resume()
        } else {
            performProfileSave(request: request, timeoutTimer: timeoutTimer)
        }
    }
    
    private func performProfileSave(request: URLRequest, timeoutTimer: Timer) {
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                timeoutTimer.invalidate()
                self.isSaving = false
                self.showLoadingOverlay = false
                
                if error != nil {
                    self.errorMessage = "Network error: \(error?.localizedDescription ?? "Unknown error")"
                    self.showError = true
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Profile save response code: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        // Success - navigate to dashboard
                        self.navigateToDashboard = true
                    } else if httpResponse.statusCode == 500 {
                        self.errorMessage = "Server error. Please try again."
                        self.showError = true
                    } else {
                        // Try to parse error message from response
                        if let data = data,
                           let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = errorDict["error"] as? String {
                            self.errorMessage = message
                        } else {
                            self.errorMessage = "Failed to save profile. Please try again."
                        }
                        self.showError = true
                    }
                } else {
                    self.errorMessage = "No response from server. Please try again."
                    self.showError = true
                }
            }
        }.resume()
    }
}

// Supporting Views

struct GenderButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.orange : Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }
}

struct ActivityLevelCard: View {
    let level: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Level indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.orange : Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Text(level)
                        .font(.headline)
                        .foregroundColor(isSelected ? .black : .white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct DietaryToggle: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isOn ? .orange : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                .labelsHidden()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
