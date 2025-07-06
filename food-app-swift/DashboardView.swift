import SwiftUI
import Charts

struct DashboardView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories: Int = 0
    @State private var isLoading = false
    @State private var scrollToLatest = false
    @State private var showMealHistory = false
    @State private var showUploadMeal = false
    @State private var showProfile = false
    @State private var errorMessage = ""
    @State private var selectedTimeFilter = "Today"
    @State private var animateCalories = false
    @State private var calorieGoal: Int = 2000
    
    // Nutrition breakdown
    @State private var totalProtein: Int = 0
    @State private var totalCarbs: Int = 0
    @State private var totalFat: Int = 0
    
    let timeFilters = ["Today", "This Week", "This Month"]
    
    // Get greeting based on time
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    var userName: String {
        UserDefaults.standard.string(forKey: "user_name") ?? "Friend"
    }
    
    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(totalCalories) / Double(calorieGoal), 1.0)
    }
    
    var calorieProgressColor: Color {
        if calorieProgress < 0.5 { return .green }
        else if calorieProgress < 0.8 { return .yellow }
        else if calorieProgress < 1.0 { return .orange }
        else { return .red }
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Stats Cards
                        statsSection
                        
                        // Quick Actions
                        quickActionsSection
                        
                        // Recent Meals Section
                        recentMealsSection
                        
                        // Nutrition Breakdown
                        if !meals.isEmpty {
                            nutritionBreakdownSection
                        }
                        
                        // Spacing for floating button
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }

                // Floating Upload Button
                floatingUploadButton
            }
            .preferredColorScheme(.dark)
            .onAppear {
                loadUserPreferences()
                fetchMeals()
                withAnimation(.easeOut(duration: 0.8)) {
                    animateCalories = true
                }
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }
    
    // MARK: - View Components
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(userName) 👋")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Profile Button
                Button(action: { showProfile = true }) {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Date
            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    var statsSection: some View {
        VStack(spacing: 16) {
            // Main Calorie Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calories")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(animateCalories ? totalCalories : 0)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: totalCalories)
                            
                            Text("/ \(calorieGoal) kcal")
                                .font(.callout)
                                .foregroundColor(.gray)
                                .padding(.bottom, 6)
                        }
                    }
                    
                    Spacer()
                    
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: animateCalories ? calorieProgress : 0)
                            .stroke(calorieProgressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.0), value: calorieProgress)
                        
                        Text("\(Int(calorieProgress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(calorieProgressColor)
                            .frame(width: animateCalories ? geometry.size.width * calorieProgress : 0, height: 8)
                            .animation(.easeOut(duration: 1.0), value: calorieProgress)
                    }
                }
                .frame(height: 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            // Macro Stats
            HStack(spacing: 12) {
                MacroCard(
                    title: "Protein",
                    value: totalProtein,
                    unit: "g",
                    color: .blue,
                    icon: "flame.fill"
                )
                
                MacroCard(
                    title: "Carbs",
                    value: totalCarbs,
                    unit: "g",
                    color: .orange,
                    icon: "leaf.fill"
                )
                
                MacroCard(
                    title: "Fat",
                    value: totalFat,
                    unit: "g",
                    color: .purple,
                    icon: "drop.fill"
                )
            }
        }
    }
    
    var quickActionsSection: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                title: "Add Water",
                icon: "drop.fill",
                color: .blue
            ) {
                // Add water tracking
            }
            
            QuickActionButton(
                title: "Exercise",
                icon: "figure.run",
                color: .green
            ) {
                // Add exercise
            }
            
            QuickActionButton(
                title: "Weight",
                icon: "scalemass.fill",
                color: .purple
            ) {
                // Log weight
            }
            
            QuickActionButton(
                title: "Goals",
                icon: "target",
                color: .orange
            ) {
                showProfile = true
            }
        }
    }
    
    var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Meals")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showMealHistory = true }) {
                    HStack(spacing: 4) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            
            if isLoading && meals.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if meals.isEmpty {
                EmptyStateCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(meals.prefix(5))) { meal in
                            MealCard(meal: meal)
                                .onTapGesture {
                                    // Navigate to detail
                                }
                        }
                    }
                }
            }
        }
    }
    
    var nutritionBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Nutrition")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                NutritionBar(
                    nutrient: "Protein",
                    current: totalProtein,
                    goal: 50,
                    color: .blue
                )
                
                NutritionBar(
                    nutrient: "Carbohydrates",
                    current: totalCarbs,
                    goal: 250,
                    color: .orange
                )
                
                NutritionBar(
                    nutrient: "Fat",
                    current: totalFat,
                    goal: 65,
                    color: .purple
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    var floatingUploadButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        showUploadMeal = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("Add Meal")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
        }
    }
    
    // MARK: - Functions
    
    func loadUserPreferences() {
        // Load calorie goal from profile
        if let profileCalorieTarget = UserDefaults.standard.object(forKey: "calorie_target") as? Int {
            calorieGoal = profileCalorieTarget
        }
    }
    
    func fetchMeals() {
        guard let userId = UserDefaults.standard.string(forKey: "user_id"),
              !userId.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else {
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
            
            guard let data = data else { return }
            
            do {
                let decoded = try JSONDecoder().decode([Meal].self, from: data)
                DispatchQueue.main.async {
                    // Remove duplicates
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
                    
                    self.calculateTodayStats()
                }
            } catch {
                print("❌ Decode error: \(error)")
            }
        }.resume()
    }
    
    func calculateTodayStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var calories = 0
        var protein = 0
        var carbs = 0
        var fat = 0
        
        for meal in meals {
            guard let savedAt = meal.saved_at,
                  let mealDate = ISO8601DateFormatter().date(from: savedAt),
                  calendar.isDate(mealDate, inSameDayAs: today) else {
                continue
            }
            
            // Extract nutrition values
            calories += extractCalories(from: meal.nutrition_info) ?? 0
            protein += extractNutrient(name: "protein", from: meal.nutrition_info) ?? 0
            carbs += extractNutrient(name: "carbohydrates", from: meal.nutrition_info) ?? 0
            fat += extractNutrient(name: "fat", from: meal.nutrition_info) ?? 0
        }
        
        withAnimation {
            self.totalCalories = calories
            self.totalProtein = protein
            self.totalCarbs = carbs
            self.totalFat = fat
        }
    }
    
    func extractNutrient(name: String, from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, parts[0].lowercased().contains(name.lowercased()) {
                return Int(parts[1])
            }
        }
        return nil
    }
    
    func extractCalories(from text: String) -> Int? {
        extractNutrient(name: "calories", from: text)
    }
    
    func fetchMealsAsync() async {
        await withCheckedContinuation { continuation in
            fetchMeals()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                continuation.resume()
            }
        }
    }
}

// MARK: - Supporting Views

struct MacroCard: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("\(value)\(unit)")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }
}

struct MealCard: View {
    let meal: Meal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            if let base64 = meal.image_thumb ?? meal.image_full,
               !base64.isEmpty,
               let data = Data(base64Encoded: base64),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 120)
                    .clipped()
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 160, height: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.dish_prediction)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if let calories = extractCalories(from: meal.nutrition_info) {
                    Text("\(calories) kcal")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if let mealType = meal.meal_type {
                    Text(mealType)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
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
}

struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No meals yet")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Start tracking by adding your first meal")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(.white.opacity(0.1))
                )
        )
    }
}

struct NutritionBar: View {
    let nutrient: String
    let current: Int
    let goal: Int
    let color: Color
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(nutrient)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(current)g / \(goal)g")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// Placeholder ProfileView
struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ProfileSetupView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
