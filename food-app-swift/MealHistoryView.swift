import SwiftUI

struct MealHistoryView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedMeal: Meal? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Meal History")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            fetchMeals()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)

                    // Stats
                    if !isLoading && !meals.isEmpty {
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(meals.count)")
                                    .font(.title.bold())
                                    .foregroundColor(.orange)
                                Text("Total Meals")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text("\(totalCalories)")
                                    .font(.title.bold())
                                    .foregroundColor(.yellow)
                                Text("Total Calories")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }

                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView("Loading meals...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .foregroundColor(.white)
                        Spacer()
                    } else if !errorMessage.isEmpty {
                        Spacer()
                        Text("⚠️ \(errorMessage)")
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    } else if meals.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No meals found")
                                .foregroundColor(.white.opacity(0.7))
                            Text("Upload your first dish!")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(meals) { meal in
                                    mealCard(for: meal)
                                        .onTapGesture {
                                            selectedMeal = meal
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .preferredColorScheme(.dark)
            .onAppear(perform: fetchMeals)
            .refreshable {
                await fetchMealsAsync()
            }
            .sheet(item: $selectedMeal) { meal in
                MealDetailView(meal: meal)
            }
        }
    }

    func mealCard(for meal: Meal) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let base64 = meal.image_thumb ?? meal.image_full,
               !base64.isEmpty,
               let data = Data(base64Encoded: base64),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                Text(meal.dish_prediction)
                    .foregroundColor(.white)
                    .font(.headline)
                    .lineLimit(1)
                
                // Always show calories with unit
                if let cal = extractCalories(from: meal.nutrition_info) {
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("\(cal) kcal")
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("🔥")
                        Text("200 kcal")  // Default if missing
                            .foregroundColor(.orange.opacity(0.7))
                            .font(.subheadline)
                    }
                }
                
                if let savedAt = meal.saved_at,
                   !savedAt.isEmpty,
                   let date = ISO8601DateFormatter().date(from: savedAt) {
                    Text("🕒 \(formattedDate(date))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .shadow(radius: 2)
    }

    func fetchMeals() {
        guard let userID = UserDefaults.standard.string(forKey: "user_id"),
              !userID.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userID)") else {
            print("❌ Invalid user_id")
            errorMessage = "Please log in to view meal history"
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
            
            // Debug response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📋 Meal history response: \(jsonString.prefix(300))...")
            }
            
            do {
                let decoded = try JSONDecoder().decode([Meal].self, from: data)
                DispatchQueue.main.async {
                    // Remove duplicates based on saved_at timestamp
                    var uniqueMeals: [Meal] = []
                    var seenTimestamps: Set<String> = []
                    
                    for meal in decoded {
                        if let timestamp = meal.saved_at, !seenTimestamps.contains(timestamp) {
                            seenTimestamps.insert(timestamp)
                            uniqueMeals.append(meal)
                        } else if meal.saved_at == nil || meal.saved_at?.isEmpty == true {
                            // Include meals without timestamps (shouldn't happen but just in case)
                            uniqueMeals.append(meal)
                        }
                    }
                    
                    // Sort by date, newest first
                    self.meals = uniqueMeals.sorted { meal1, meal2 in
                        guard let date1 = ISO8601DateFormatter().date(from: meal1.saved_at ?? ""),
                              let date2 = ISO8601DateFormatter().date(from: meal2.saved_at ?? "") else {
                            return false
                        }
                        return date1 > date2
                    }
                    
                    // Calculate total calories
                    self.totalCalories = self.meals.compactMap {
                        extractCalories(from: $0.nutrition_info)
                    }.reduce(0, +)
                    
                    print("✅ Loaded \(self.meals.count) unique meals (from \(decoded.count) total)")
                }
            } catch {
                print("❌ Decode error in meal history: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load meal history"
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
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE, h:mm a"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}
