import SwiftUI

struct MealHistoryView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Meal History")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Text("📊 Total Calories: \(totalCalories)")
                        .foregroundColor(.yellow)
                        .font(.headline)

                    if meals.isEmpty {
                        Spacer()
                        ProgressView("Fetching Meals...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
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
        let userId = SessionManager.shared.userID
        guard !userId.isEmpty else { return }

        guard let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
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
}
