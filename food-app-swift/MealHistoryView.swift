// MARK: - MealHistoryView.swift
import SwiftUI

struct MealHistoryView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Meal History")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    if isLoading {
                        ProgressView("Fetching Meals...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    } else {
                        Text("📊 Total Calories: \(totalCalories)")
                            .foregroundColor(.yellow)
                            .font(.headline)
                    }

                    if meals.isEmpty && !isLoading {
                        Spacer()
                        Text("No meals found. Upload your first dish!")
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(meals) { meal in
                                    mealCard(for: meal)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .preferredColorScheme(.dark)
            .onAppear(perform: fetchMeals)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MealSaved"))) { _ in
                fetchMeals()
            }
        }
    }

    // MARK: - Meal Card View
    @ViewBuilder
    func mealCard(for meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imgBase64 = meal.image_thumb,
               let image = decodeBase64ToUIImage(base64String: imgBase64) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(12)
            }

            Text("🍽️ \(meal.dish_prediction)")
                .foregroundColor(.white)
                .font(.headline)

            if let cal = extractCalories(from: meal.nutrition_info) {
                Text("🔥 \(cal) kcal")
                    .foregroundColor(.orange)
            }

            if let savedAt = meal.saved_at,
               let date = ISO8601DateFormatter().date(from: savedAt) {
                Text("🕒 \(formattedDate(date))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }

            Text(meal.image_description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .shadow(radius: 2)
    }

    // MARK: - API Call
    func fetchMeals() {
        guard !SessionManager.shared.userID.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(SessionManager.shared.userID)") else {
            print("⚠️ Invalid user ID or URL")
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, _, error in
            defer { DispatchQueue.main.async { isLoading = false } }

            guard let data = data, error == nil,
                  let decoded = try? JSONDecoder().decode([Meal].self, from: data) else {
                print("❌ Failed to decode meals")
                return
            }

            DispatchQueue.main.async {
                self.meals = decoded
                self.totalCalories = decoded.compactMap { extractCalories(from: $0.nutrition_info) }.reduce(0, +)
            }
        }.resume()
    }

    // MARK: - Helpers
    func decodeBase64ToUIImage(base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    func extractCalories(from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|")
            if parts.count == 4, parts[0].lowercased().contains("calories") {
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}
