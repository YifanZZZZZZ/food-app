import SwiftUI

struct DashboardView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0
    @State private var isLoading = false
    @State private var scrollToLatest = false
    @State private var showMealHistory = false
    @State private var showUploadMeal = false
    @State private var errorMessage = ""

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
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            Text("Loading meals...")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    } else if !errorMessage.isEmpty {
                        Text("⚠️ \(errorMessage)")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if meals.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.orange.opacity(0.5))
                            Text("No meals yet. Upload your first one!")
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
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
                                if newValue && !meals.isEmpty {
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
            .onAppear {
                fetchMeals()
            }
            .refreshable {
                await fetchMealsAsync()
            }
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
            // Image
            if let base64 = meal.image_thumb ?? meal.image_full,
               !base64.isEmpty,
               let img = decodeBase64ToUIImage(base64String: base64) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 140)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 240, height: 140)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.largeTitle)
                    )
            }

            // Dish name
            Text(meal.dish_prediction)
                .foregroundColor(.white)
                .font(.headline)
                .lineLimit(1)

            // Calories
            if let cal = extractCalories(from: meal.nutrition_info) {
                Text("\(cal) kcal")
                    .foregroundColor(.orange)
                    .font(.subheadline)
            } else {
                Text("Calories unknown")
                    .foregroundColor(.gray)
                    .font(.caption)
            }

            // Time
            if let savedAt = meal.saved_at,
               !savedAt.isEmpty,
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
              !userId.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else {
            print("⚠️ Invalid user ID or URL")
            errorMessage = "Please log in to view meals"
            return
        }

        isLoading = true
        errorMessage = ""
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }
            
            // Debug: Print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📋 Raw response: \(jsonString.prefix(500))...")
            }
            
            do {
                let decoded = try JSONDecoder().decode([Meal].self, from: data)
                DispatchQueue.main.async {
                    self.meals = decoded.sorted { meal1, meal2 in
                        // Sort by saved_at date, newest first
                        guard let date1 = ISO8601DateFormatter().date(from: meal1.saved_at ?? ""),
                              let date2 = ISO8601DateFormatter().date(from: meal2.saved_at ?? "") else {
                            return false
                        }
                        return date1 > date2
                    }
                    
                    // Calculate today's calories
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    
                    self.totalCalories = self.meals.compactMap { meal in
                        guard let savedAt = meal.saved_at,
                              let mealDate = ISO8601DateFormatter().date(from: savedAt),
                              calendar.isDate(mealDate, inSameDayAs: today) else {
                            return nil
                        }
                        return extractCalories(from: meal.nutrition_info)
                    }.reduce(0, +)
                    
                    print("✅ Loaded \(self.meals.count) meals")
                }
            } catch {
                print("❌ Decode error: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load meals. Please try again."
                }
            }
        }.resume()
    }
    
    func fetchMealsAsync() async {
        await withCheckedContinuation { continuation in
            fetchMeals()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                continuation.resume()
            }
        }
    }

    func decodeBase64ToUIImage(base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    func extractCalories(from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, parts[0].lowercased().contains("calories") {
                return Int(parts[1])
            }
        }
        return nil
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today, " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday, " + formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}
