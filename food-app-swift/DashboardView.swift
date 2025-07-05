import SwiftUI

struct DashboardView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0
    @State private var isLoading = false
    @State private var scrollToLatest = false
    @State private var showMealHistory = false
    @State private var showUploadMeal = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome Back 👋")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    Text("Total Calories Consumed Today")
                        .foregroundColor(.gray)

                    Text("\(totalCalories) kcal")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.yellow)

                    Divider().background(Color.white.opacity(0.3))

                    HStack {
                        Text("Past Meals")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()

                        Button(action: {
                            showMealHistory = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                Text("View All")
                            }
                            .font(.caption)
                            .padding(6)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        }
                    }

                    if isLoading {
                        ProgressView("Loading meals...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    } else if meals.isEmpty {
                        Spacer()
                        Text("No meals yet. Upload your first one!")
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(meals.indices, id: \.self) { index in
                                        mealCard(for: meals[index])
                                            .id(index)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .onChange(of: scrollToLatest) { newValue in
                                if newValue {
                                    withAnimation {
                                        proxy.scrollTo(meals.count - 1, anchor: .center)
                                    }
                                    scrollToLatest = false
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding()

                // ✅ Floating Upload Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showUploadMeal = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.orange)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear(perform: fetchMeals)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MealSaved"))) { _ in
                fetchMeals()
                scrollToLatest = true
            }
            .sheet(isPresented: $showMealHistory) {
                MealHistoryView()
            }
            .sheet(isPresented: $showUploadMeal) {
                UploadMealView()
            }
        }
    }

    @ViewBuilder
    func mealCard(for meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let base64 = meal.image_thumb,
               let img = decodeBase64ToUIImage(base64String: base64) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 140)
                    .clipped()
                    .cornerRadius(12)
            }

            Text(meal.dish_prediction)
                .foregroundColor(.white)
                .font(.headline)

            if let cal = extractCalories(from: meal.nutrition_info) {
                Text("\(cal) kcal")
                    .foregroundColor(.orange)
            }

            if let savedAt = meal.saved_at,
               let date = ISO8601DateFormatter().date(from: savedAt) {
                Text("🕒 \(formattedDate(date))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .shadow(radius: 2)
    }

    func fetchMeals() {
        guard let userId = UserDefaults.standard.string(forKey: "user_id"),
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else {
            print("⚠️ Invalid user ID or URL")
            return
        }

        isLoading = true
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async { isLoading = false }
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
