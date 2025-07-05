// PATCHED: MealHistoryView.swift with lenient parsing fallback and nutrition display
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

    func mealCard(for meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let base64 = meal.image_thumb,
               let data = Data(base64Encoded: base64),
               let image = UIImage(data: data) {
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

            let lines = parseNutritionLinesFallback(meal.nutrition_info)
            ForEach(lines, id: \.self) { line in
                Text("• \(line)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .shadow(radius: 2)
    }

    func fetchMeals() {
        guard let userID = UserDefaults.standard.string(forKey: "user_id"),
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userID)") else {
            print("❌ Invalid user_id")
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }

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

    func extractCalories(from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|")
            if parts.count >= 2, parts[0].lowercased().contains("calories") {
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    func parseNutritionLinesFallback(_ text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|")
            if parts.count >= 2 {
                return "\(parts[0].trimmingCharacters(in: .whitespaces)) — \(parts[1].trimmingCharacters(in: .whitespaces))"
            } else {
                return String(line)
            }
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}
