import SwiftUI

struct ProfileSetupView: View {
    @State private var age: Double = 25
    @State private var gender: String = "Select"
    @State private var activityLevel = "2"
    @State private var calorieTarget: Double = 2200
    @State private var isVegetarian = false
    @State private var isKeto = false
    @State private var isGlutenFree = false
    @State private var navigateToDashboard = false

    let genderOptions = ["Male", "Female", "Other"]
    let activityOptions = ["1", "2", "3", "4"]
    let activityLegend = [
        "1": "Least Active",
        "2": "Lightly Active",
        "3": "Active",
        "4": "Very Active"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.45))
                    .blur(radius: 4)

                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 4) {
                        Text("Step 2 of 3")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.caption)

                        Text("Customize Your Profile")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 30)

                    // Personal Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Age
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Age: \(Int(age))")
                                .foregroundColor(.white.opacity(0.85))
                                .font(.subheadline)
                            Slider(value: $age, in: 10...80, step: 1)
                                .accentColor(.orange)
                        }

                        // Gender Picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Gender")
                                .foregroundColor(.white.opacity(0.85))
                                .font(.subheadline)

                            Picker("Gender", selection: $gender) {
                                Text("Select").tag("Select")
                                ForEach(genderOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.18))
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .frame(width: 280)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(16)

                    // Numeric Activity Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activity Level (1–4)")
                            .foregroundColor(.white.opacity(0.85))
                            .font(.subheadline)

                        HStack(spacing: 6) {
                            ForEach(activityOptions, id: \.self) { option in
                                Button(action: {
                                    activityLevel = option
                                }) {
                                    Text(option)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(activityLevel == option ? .black : .white)
                                        .frame(width: 56, height: 40)
                                        .background(activityLevel == option ? Color.orange : Color.white.opacity(0.2))
                                        .cornerRadius(10)
                                }
                            }
                        }

                        if let legend = activityLegend[activityLevel] {
                            Text("You selected: \(legend)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .frame(width: 280)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(16)

                    // Nutrition Section
                    VStack(alignment: .leading, spacing: 16) {
                        // Calorie Slider
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Daily Calorie Target: \(Int(calorieTarget)) kcal")
                                .foregroundColor(.white.opacity(0.85))
                                .font(.subheadline)
                            Slider(value: $calorieTarget, in: 1000...4000, step: 50)
                                .accentColor(.orange)
                        }

                        // Preferences
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Vegetarian", isOn: $isVegetarian)
                            Toggle("Keto", isOn: $isKeto)
                            Toggle("Gluten-Free", isOn: $isGlutenFree)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .foregroundColor(.white)
                    }
                    .padding()
                    .frame(width: 280)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(16)

                    // CTA
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        navigateToDashboard = true
                    }) {
                        Text("Save & Continue")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 280)
                            .background(Color.orange)
                            .cornerRadius(14)
                            .shadow(radius: 3)
                    }

                    Spacer(minLength: 30)
                }
            }
            .navigationDestination(isPresented: $navigateToDashboard) {
                DashboardView()
            }
            .preferredColorScheme(.dark)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}
