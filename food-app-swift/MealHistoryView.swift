import SwiftUI

struct MealHistoryView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedMeal: Meal? = nil
    @State private var selectedFilter = "All"
    @State private var searchText = ""
    
    let filters = ["All", "Breakfast", "Lunch", "Dinner", "Snacks"]

    var filteredMeals: [Meal] {
        meals.filter { meal in
            let matchesFilter = selectedFilter == "All" || meal.meal_type == selectedFilter
            let matchesSearch = searchText.isEmpty || meal.dish_prediction.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }
    
    var groupedMeals: [(String, [Meal])] {
        Dictionary(grouping: filteredMeals) { meal in
            if let savedAt = meal.saved_at,
               let date = ISO8601DateFormatter().date(from: savedAt) {
                return formatDateHeader(date)
            }
            return "Unknown Date"
        }
        .sorted { $0.key > $1.key }
        .map { ($0.key, $0.value) }
    }

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

                VStack(spacing: 0) {
                    // Custom Navigation Bar
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Meal History")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            
                            Text("\(meals.count) meals tracked")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        // Stats Card
                        VStack(spacing: 4) {
                            Text("\(totalCalories)")
                                .font(.title2.bold())
                                .foregroundColor(.orange)
                            Text("Total kcal")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search meals...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(filters, id: \.self) { filter in
                                FilterPill(
                                    title: filter,
                                    isSelected: selectedFilter == filter,
                                    action: { selectedFilter = filter }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)

                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView("Loading meals...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .foregroundColor(.white)
                        Spacer()
                    } else if !errorMessage.isEmpty {
                        Spacer()
                        ErrorStateView(message: errorMessage, retry: fetchMeals)
                        Spacer()
                    } else if meals.isEmpty {
                        Spacer()
                        EmptyHistoryState()
                        Spacer()
                    } else if filteredMeals.isEmpty {
                        Spacer()
                        NoResultsView()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                                ForEach(groupedMeals, id: \.0) { date, meals in
                                    Section {
                                        ForEach(meals) { meal in
                                            MealHistoryCard(meal: meal)
                                                .onTapGesture {
                                                    selectedMeal = meal
                                                }
                                        }
                                    } header: {
                                        DateHeader(date: date, count: meals.count)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100)
                        }
                    }
                }
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
    
    // Components
    
    func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    func fetchMeals() {
        guard let userID = UserDefaults.standard.string(forKey: "user_id"),
              !userID.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userID)") else {
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
            
            do {
                let decoded = try JSONDecoder().decode([Meal].self, from: data)
                DispatchQueue.main.async {
                    var uniqueMeals: [Meal] = []
                    var seenTimestamps: Set<String> = []
                    
                    for meal in decoded {
                        if let timestamp = meal.saved_at, !seenTimestamps.contains(timestamp) {
                            seenTimestamps.insert(timestamp)
                            uniqueMeals.append(meal)
                        }
                    }
                    
                    self.meals = uniqueMeals.sorted { meal1, meal2 in
                        guard let date1 = ISO8601DateFormatter().date(from: meal1.saved_at ?? ""),
                              let date2 = ISO8601DateFormatter().date(from: meal2.saved_at ?? "") else {
                            return false
                        }
                        return date1 > date2
                    }
                    
                    self.totalCalories = self.meals.compactMap {
                        extractCalories(from: $0.nutrition_info)
                    }.reduce(0, +)
                }
            } catch {
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
}

// Supporting Views

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.orange : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct DateHeader: View {
    let date: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(date)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(count) meals")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.black.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct MealHistoryCard: View {
    let meal: Meal
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            if let base64 = meal.image_thumb ?? meal.image_full,
               !base64.isEmpty,
               let data = Data(base64Encoded: base64),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(16)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange.opacity(0.3), .orange.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.title2)
                    )
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                Text(meal.dish_prediction)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 16) {
                    // Calories
                    if let cal = extractCalories(from: meal.nutrition_info) {
                        Label("\(cal) kcal", systemImage: "flame.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    
                    // Meal Type
                    if let mealType = meal.meal_type {
                        Text(mealType)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.2))
                            )
                            .foregroundColor(.blue)
                    }
                }
                
                // Time
                if let savedAt = meal.saved_at,
                   let date = ISO8601DateFormatter().date(from: savedAt) {
                    Text(formattedTime(date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Arrow
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
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
    
    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct EmptyHistoryState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No meals yet")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("Start tracking your nutrition journey")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No meals found")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Button(action: retry) {
                Label("Try Again", systemImage: "arrow.clockwise")
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
