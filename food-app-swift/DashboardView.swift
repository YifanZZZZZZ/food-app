import SwiftUI

struct DashboardView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories = 0
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Greeting
                        VStack(alignment: .leading, spacing: 6) {
                            Text("👋 Welcome Back!")
                                .font(.title2)
                                .foregroundColor(.white)

                            Text("Here’s your nutrition overview for today")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.footnote)
                        }
                        .padding(.horizontal)
                        .padding(.top, 40)

                        // Meals Section
                        VStack(alignment: .leading) {
                            Text("Today's Meals")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal)

                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                    .frame(maxWidth: .infinity)
                            } else if meals.isEmpty {
                                Text("No meals logged yet.")
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(meals) { meal in
                                            VStack(alignment: .leading, spacing: 6) {
                                                if let uiImage = decodeBase64ToUIImage(meal.image_thumb ?? "") {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 140, height: 90)
                                                        .clipped()
                                                        .cornerRadius(12)
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.orange.opacity(0.9))
                                                        .frame(width: 140, height: 90)
                                                        .cornerRadius(12)
                                                }

                                                Text(meal.dish_prediction)
                                                    .foregroundColor(.white)
                                                    .font(.subheadline)

                                                Text("\(extractCalories(from: meal.nutrition_info) ?? 0) kcal")
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .font(.caption2)
                                            }
                                            .padding()
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // Total Calories
                        if totalCalories > 0 {
                            Text("🔥 Total Calories Today: \(totalCalories) kcal")
                                .foregroundColor(.yellow)
                                .padding(.horizontal)
                        }

                        // Progress Bars
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Daily Nutrients")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(["Calories", "Protein", "Carbs", "Fat"], id: \.self) { nutrient in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nutrient)
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.caption)

                                    ProgressView(value: 0.5)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                        .frame(height: 8)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Suggestions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Add breakfast for a better start", systemImage: "sunrise.fill")
                                    .foregroundColor(.white.opacity(0.8))

                                Label("Low protein so far", systemImage: "bolt.fill")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // FAB Buttons
                VStack(spacing: 14) {
                    NavigationLink(destination: UploadMealView()) {
                        Label("Upload Meal", systemImage: "plus")
                            .padding()
                            .frame(width: 160)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: MealHistoryView()) {
                        Label("View Summary", systemImage: "chart.bar")
                            .padding()
                            .frame(width: 160)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                fetchMeals()
            }
        }
    }

    // MARK: - Networking
    func fetchMeals() {
        guard let userId = Optional(SessionManager.shared.userID), !userId.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else {
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, _, _ in
            isLoading = false
            guard let data = data else { return }

            if let fetchedMeals = try? JSONDecoder().decode([Meal].self, from: data) {
                DispatchQueue.main.async {
                    self.meals = fetchedMeals
                    self.totalCalories = fetchedMeals.reduce(0) {
                        $0 + (extractCalories(from: $1.nutrition_info) ?? 0)
                    }
                }
            }
        }.resume()
    }

    func decodeBase64ToUIImage(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    func extractCalories(from nutritionText: String) -> Int? {
        for line in nutritionText.split(separator: "\n") {
            let parts = line.split(separator: "|")
            if parts.count == 4, parts[0].lowercased().contains("calories") {
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
}

struct Meal: Codable, Identifiable {
    var id = UUID()
    let user_id: String
    let dish_prediction: String
    let image_description: String
    let nutrition_info: String
    let image_thumb: String?        // for dashboard and history
    let image_full: String?         // for full-resolution detail view
    let hidden_ingredients: String?
}

