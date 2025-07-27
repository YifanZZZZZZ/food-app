import SwiftUI
import Charts
import Foundation

struct DashboardView: View {
    @ObservedObject var session = SessionManager.shared
    @ObservedObject var profileManager = ProfileManager.shared
    @State private var meals: [Meal] = []
    @State private var waterIntake: [WaterEntry] = []
    @State private var exerciseEntries: [ExerciseEntry] = []
    @State private var weightEntries: [WeightEntry] = []
    
    // Today's stats
    @State private var todayCalories: Int = 0
    @State private var todayWater: Double = 0.0
    @State private var todayExercise: Int = 0
    @State private var currentWeight: Double = 0.0
    
    // Monthly stats
    @State private var monthlyCalories: Int = 0
    @State private var monthlyAvgCalories: Int = 0
    @State private var monthlyWater: Double = 0.0
    @State private var monthlyExercise: Int = 0
    
    // Weekly stats
    @State private var weeklyExercise: Int = 0
    @State private var weeklyAvgWater: Double = 0.0
    @State private var weeklyMeals: Int = 0
    
    @State private var isLoading = false
    @State private var scrollToLatest = false
    @State private var showMealHistory = false
    @State private var showUploadMeal = false
    @State private var showProfile = false
    @State private var showWaterTracking = false
    @State private var showExerciseTracking = false
    @State private var showWeightTracking = false
    @State private var errorMessage = ""
    @State private var selectedTimeFilter = "Today"
    @State private var animateCalories = false
    @State private var calorieGoal: Int = 2000
    @State private var hasInitialized = false
    @State private var showNetworkAlert = false
    @State private var networkError: NetworkError?
    
    // Nutrition breakdown
    @State private var totalProtein: Int = 0
    @State private var totalCarbs: Int = 0
    @State private var totalFat: Int = 0
    @State private var totalFiber: Int = 0
    @State private var totalSugar: Int = 0
    @State private var totalSodium: Int = 0
    
    // Streaks and achievements
    @State private var currentStreak: Int = 0
    @State private var weeklyGoalProgress: Double = 0.0
    
    let timeFilters = ["Today", "This Week", "This Month"]
    
    // Network error handling
    enum NetworkError: Identifiable {
        case noInternet
        case serverError
        case profileSyncFailed
        case dataLoadFailed
        
        var id: String {
            switch self {
            case .noInternet: return "no_internet"
            case .serverError: return "server_error"
            case .profileSyncFailed: return "profile_sync_failed"
            case .dataLoadFailed: return "data_load_failed"
            }
        }
        
        var title: String {
            switch self {
            case .noInternet: return "No Internet Connection"
            case .serverError: return "Server Error"
            case .profileSyncFailed: return "Profile Sync Failed"
            case .dataLoadFailed: return "Data Load Failed"
            }
        }
        
        var message: String {
            switch self {
            case .noInternet: return "Please check your internet connection and try again."
            case .serverError: return "Our servers are experiencing issues. Please try again later."
            case .profileSyncFailed: return "Unable to sync your profile. Some features may be limited."
            case .dataLoadFailed: return "Failed to load your data. Pull to refresh to try again."
            }
        }
    }
    
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
        session.userName.isEmpty ? "Friend" : session.userName
    }
    
    // Dynamic calorie goal from ProfileManager
    var dynamicCalorieGoal: Int {
        profileManager.userProfile?.calorieTarget ?? calorieGoal
    }
    
    var displayedCalories: Int {
        switch selectedTimeFilter {
        case "Today": return todayCalories
        case "This Week": return Int(Double(todayCalories) * 7) // Simplified weekly calc
        case "This Month": return monthlyCalories
        default: return todayCalories
        }
    }
    
    var displayedGoal: Int {
        switch selectedTimeFilter {
        case "Today": return dynamicCalorieGoal
        case "This Week": return dynamicCalorieGoal * 7
        case "This Month": return dynamicCalorieGoal * daysInCurrentMonth()
        default: return dynamicCalorieGoal
        }
    }
    
    var calorieProgress: Double {
        let goal = displayedGoal
        guard goal > 0 else { return 0 }
        return min(Double(displayedCalories) / Double(goal), 1.0)
    }
    
    var calorieProgressColor: Color {
        if calorieProgress < 0.5 { return .green }
        else if calorieProgress < 0.8 { return .yellow }
        else if calorieProgress < 1.0 { return .orange }
        else { return .red }
    }
    
    var waterProgressColor: Color {
        let progress = todayWater / 2000.0
        if progress < 0.5 { return .red }
        else if progress < 0.8 { return .orange }
        else { return .blue }
    }
    
    var exerciseProgressColor: Color {
        let progress = Double(weeklyExercise) / 150.0 // WHO recommendation
        if progress < 0.5 { return .red }
        else if progress < 0.8 { return .orange }
        else { return .green }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Enhanced gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.black.opacity(0.98),
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Enhanced Header Section
                        headerSection
                        
                        // Enhanced Time Filter
                        timeFilterSection
                        
                        // Network/Profile Status
                        if let networkError = networkError {
                            networkErrorSection(networkError)
                        } else if profileManager.isLoading && profileManager.userProfile == nil {
                            profileLoadingSection
                        } else if let errorMessage = profileManager.errorMessage {
                            profileErrorSection(errorMessage)
                        }
                        
                        // Main Stats Cards with Enhanced UI
                        enhancedMainStatsSection
                        
                        // Quick Actions with More Options
                        enhancedQuickActionsSection
                        
                        // Enhanced Today's Summary
                        enhancedTodaySummarySection
                        
                        // Weekly Overview (New)
                        weeklyOverviewSection
                        
                        // Recent Meals Section
                        recentMealsSection
                        
                        // Enhanced Nutrition Breakdown
                        if !meals.isEmpty {
                            enhancedNutritionBreakdownSection
                        }
                        
                        // Health Insights (New)
                        healthInsightsSection
                        
                        // Spacing for floating button
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .refreshable {
                    await refreshDashboard()
                }

                // Enhanced Floating Upload Button
                enhancedFloatingUploadButton
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .onAppear {
                initializeDashboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MealSaved"))) { _ in
                print("🔔 Meal saved notification received")
                fetchAllData()
                scrollToLatest = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WaterAdded"))) { _ in
                print("💧 Water added notification received")
                fetchWaterData()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ExerciseAdded"))) { _ in
                print("🏃‍♂️ Exercise added notification received")
                fetchExerciseData()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("WeightAdded"))) { _ in
                print("⚖️ Weight added notification received")
                fetchWeightData()
            }
            .onReceive(profileManager.$userProfile) { newProfile in
                if let profile = newProfile {
                    withAnimation {
                        calorieGoal = profile.calorieTarget
                    }
                    print("🔄 Dashboard updated with new profile data: \(profile.calorieTarget) kcal")
                }
            }
            .onReceive(session.$shouldNavigateToLogin) { shouldNavigate in
                if shouldNavigate {
                    print("🚪 Logout navigation triggered")
                }
            }
            .sheet(isPresented: $showMealHistory) {
                MealHistoryView()
            }
            .sheet(isPresented: $showUploadMeal) {
                UploadMealView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .onDisappear {
                        print("👤 Profile view closed, refreshing data")
                        profileManager.fetchProfile(force: true)
                    }
            }
            .sheet(isPresented: $showWaterTracking) {
                WaterTrackingView()
            }
            .sheet(isPresented: $showExerciseTracking) {
                ExerciseTrackingView()
            }
            .sheet(isPresented: $showWeightTracking) {
                WeightTrackingView()
            }
            .alert(networkError?.title ?? "Error", isPresented: $showNetworkAlert) {
                Button("Retry") {
                    handleNetworkErrorRetry()
                }
                Button("Cancel", role: .cancel) {
                    networkError = nil
                }
            } message: {
                Text(networkError?.message ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Enhanced View Components
    
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                
                // Enhanced Profile Circle with status indicator
                ZStack {
                    ProfileCircle(
                        userName: userName,
                        size: 44,
                        showBorder: true,
                        borderColor: .orange
                    ) {
                        showProfile = true
                    }
                    
                    // Status indicator
                    if profileManager.isLoading {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 12, height: 12)
                            .offset(x: 16, y: -16)
                    } else if profileManager.userProfile != nil {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .offset(x: 16, y: -16)
                    }
                }
            }
            
            // Enhanced Date with streak
            HStack {
                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                if currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(currentStreak) day streak")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                }
            }
        }
    }
    
    var timeFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(timeFilters, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedTimeFilter = filter
                        }
                    }) {
                        Text(filter)
                            .font(.subheadline)
                            .fontWeight(selectedTimeFilter == filter ? .semibold : .regular)
                            .foregroundColor(selectedTimeFilter == filter ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(selectedTimeFilter == filter ? Color.orange : Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(selectedTimeFilter == filter ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    func networkErrorSection(_ error: NetworkError) -> some View {
        HStack {
            Image(systemName: "wifi.exclamationmark")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Text(error.message)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Retry") {
                handleNetworkErrorRetry()
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    var profileLoadingSection: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                .scaleEffect(0.8)
            
            Text("Loading your profile...")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    func profileErrorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Profile Error")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Retry") {
                profileManager.fetchProfile(force: true)
            }
            .font(.caption)
            .foregroundColor(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    var enhancedMainStatsSection: some View {
        VStack(spacing: 16) {
            // Enhanced Main Calorie Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Calories")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(selectedTimeFilter)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                            
                            if profileManager.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                    .scaleEffect(0.6)
                            }
                        }
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(animateCalories ? displayedCalories : 0)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayedCalories)
                            
                            Text("/ \(displayedGoal) kcal")
                                .font(.callout)
                                .foregroundColor(.gray)
                                .padding(.bottom, 6)
                                .animation(.easeInOut, value: displayedGoal)
                        }
                        
                        // Enhanced progress text
                        HStack {
                            if selectedTimeFilter == "This Month" {
                                Text("Avg: \(monthlyAvgCalories) kcal/day")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.8))
                            } else if selectedTimeFilter == "This Week" {
                                Text("Daily avg this week")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Text("\(Int(calorieProgress * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(calorieProgressColor)
                        }
                        
                        // Profile sync status
                        if let lastSync = profileManager.lastSyncDate {
                            Text("Goal synced \(formatRelativeTime(lastSync))")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    // Enhanced Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: animateCalories ? calorieProgress : 0)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [calorieProgressColor, calorieProgressColor.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.0), value: calorieProgress)
                        
                        Text("\(Int(calorieProgress * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
                
                // Enhanced Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [calorieProgressColor, calorieProgressColor.opacity(0.7)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
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
            
            // Enhanced Macro Stats
            HStack(spacing: 12) {
                MacroCard(
                    title: "Protein",
                    value: totalProtein,
                    unit: "g",
                    color: .blue,
                    icon: "flame.fill",
                    goal: calculateProteinGoal()
                )
                
                MacroCard(
                    title: "Carbs",
                    value: totalCarbs,
                    unit: "g",
                    color: .orange,
                    icon: "leaf.fill",
                    goal: calculateCarbGoal()
                )
                
                MacroCard(
                    title: "Fat",
                    value: totalFat,
                    unit: "g",
                    color: .purple,
                    icon: "drop.fill",
                    goal: calculateFatGoal()
                )
            }
        }
    }
    
    var enhancedQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.white)
            
            // First row
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Water",
                    icon: "drop.fill",
                    color: waterProgressColor,
                    subtitle: "\(Int(todayWater))ml",
                    progress: todayWater / 2000.0
                ) {
                    showWaterTracking = true
                }
                
                QuickActionButton(
                    title: "Exercise",
                    icon: "figure.run",
                    color: exerciseProgressColor,
                    subtitle: "\(todayExercise) min",
                    progress: Double(todayExercise) / 30.0
                ) {
                    showExerciseTracking = true
                }
            }
            
            // Second row
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Weight",
                    icon: "scalemass.fill",
                    color: .purple,
                    subtitle: currentWeight > 0 ? String(format: "%.1f kg", currentWeight) : "Add",
                    progress: currentWeight > 0 ? 1.0 : 0.0
                ) {
                    showWeightTracking = true
                }
                
                QuickActionButton(
                    title: "Profile",
                    icon: "person.fill",
                    color: .orange,
                    subtitle: profileManager.userProfile != nil ? "Synced" : "Setup",
                    progress: profileManager.userProfile != nil ? 1.0 : 0.0
                ) {
                    showProfile = true
                }
            }
        }
    }
    
    var enhancedTodaySummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Summary")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                SummaryRow(
                    icon: "drop.fill",
                    title: "Water Intake",
                    value: "\(Int(todayWater)) ml",
                    target: "2000 ml",
                    progress: todayWater / 2000.0,
                    color: waterProgressColor
                )
                
                SummaryRow(
                    icon: "figure.run",
                    title: "Exercise",
                    value: "\(todayExercise) min",
                    target: "30 min",
                    progress: Double(todayExercise) / 30.0,
                    color: exerciseProgressColor
                )
                
                SummaryRow(
                    icon: "fork.knife",
                    title: "Meals",
                    value: "\(meals.filter { isSameDay($0.saved_at) }.count) meals",
                    target: "3-4 meals",
                    progress: Double(meals.filter { isSameDay($0.saved_at) }.count) / 3.0,
                    color: .orange
                )
                
                if currentWeight > 0 {
                    SummaryRow(
                        icon: "scalemass.fill",
                        title: "Weight",
                        value: String(format: "%.1f kg", currentWeight),
                        target: "Tracked",
                        progress: 1.0,
                        color: .purple
                    )
                }
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
    }
    
    var weeklyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Overview")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                WeeklyStatCard(
                    title: "Exercise",
                    value: weeklyExercise,
                    unit: "min",
                    goal: 150,
                    color: .green,
                    icon: "figure.run"
                )
                
                WeeklyStatCard(
                    title: "Avg Water",
                    value: Int(weeklyAvgWater),
                    unit: "ml",
                    goal: 2000,
                    color: .blue,
                    icon: "drop.fill"
                )
                
                WeeklyStatCard(
                    title: "Meals Logged",
                    value: weeklyMeals,
                    unit: "meals",
                    goal: 21,
                    color: .orange,
                    icon: "fork.knife"
                )
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
                    Text("Loading meals...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if meals.isEmpty {
                EmptyStateCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(meals.prefix(5))) { meal in
                            EnhancedMealCard(meal: meal)
                                .onTapGesture {
                                    print("🍽️ Meal tapped: \(meal.dish_name)")
                                    // Navigate to detail
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
    
    var enhancedNutritionBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Nutrition")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                NutritionBar(
                    nutrient: "Protein",
                    current: totalProtein,
                    goal: calculateProteinGoal(),
                    color: .blue
                )
                
                NutritionBar(
                    nutrient: "Carbohydrates",
                    current: totalCarbs,
                    goal: calculateCarbGoal(),
                    color: .orange
                )
                
                NutritionBar(
                    nutrient: "Fat",
                    current: totalFat,
                    goal: calculateFatGoal(),
                    color: .purple
                )
                
                NutritionBar(
                    nutrient: "Fiber",
                    current: totalFiber,
                    goal: 25,
                    color: .green
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    var healthInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Insights")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                if calorieProgress > 1.2 {
                    InsightCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Calorie Intake High",
                        message: "You've exceeded your daily calorie goal. Consider lighter meals.",
                        color: .red
                    )
                }
                
                if todayWater < 1000 {
                    InsightCard(
                        icon: "drop.fill",
                        title: "Stay Hydrated",
                        message: "You're behind on your water intake. Drink more water!",
                        color: .blue
                    )
                }
                
                if todayExercise == 0 {
                    InsightCard(
                        icon: "figure.run",
                        title: "Get Moving",
                        message: "You haven't logged any exercise today. Try a short walk!",
                        color: .green
                    )
                }
                
                if currentStreak >= 7 {
                    InsightCard(
                        icon: "star.fill",
                        title: "Great Streak!",
                        message: "You've been consistent for \(currentStreak) days. Keep it up!",
                        color: .orange
                    )
                }
            }
        }
    }
    
    var enhancedFloatingUploadButton: some View {
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
    
    func initializeDashboard() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        print("🏠 Dashboard initializing...")
        
        // Load user preferences first
        loadUserPreferences()
        
        // Fetch profile only if not cached
        if profileManager.userProfile == nil {
            profileManager.fetchProfile()
        }
        
        // Fetch all data
        fetchAllData()
        
        // Calculate streak
        calculateStreak()
        
        // Animate calories
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                animateCalories = true
            }
        }
    }
    
    func fetchAllData() {
        fetchMeals()
        fetchWaterData()
        fetchExerciseData()
        fetchWeightData()
    }
    
    func loadUserPreferences() {
        // Load from ProfileManager first (MongoDB source of truth)
        if let profile = profileManager.userProfile {
            calorieGoal = profile.calorieTarget
            print("📊 Loaded calorie goal from profile: \(calorieGoal)")
        } else {
            // Fallback to UserDefaults if profile not loaded yet
            if let saved = UserDefaults.standard.object(forKey: "calorie_target") as? Int {
                calorieGoal = saved
                print("📱 Loaded calorie goal from UserDefaults: \(calorieGoal)")
            }
        }
    }
    
    func fetchMeals() {
        guard let userId = getCurrentUserId(),
              let url = URL(string: "https://food-app-recipe.onrender.com/user-meals?user_id=\(userId)") else {
            networkError = .noInternet
            return
        }

        isLoading = true
        errorMessage = ""
        print("🔄 Fetching meals for user: \(userId)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.networkError = .dataLoadFailed
                    print("❌ Meal fetch error: \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.networkError = .dataLoadFailed
                }
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([Meal].self, from: data)
                DispatchQueue.main.async {
                    self.meals = decoded.sorted { meal1, meal2 in
                        guard let date1 = ISO8601DateFormatter().date(from: meal1.saved_at ?? ""),
                              let date2 = ISO8601DateFormatter().date(from: meal2.saved_at ?? "") else {
                            return false
                        }
                        return date1 > date2
                    }
                    
                    print("✅ Loaded \(self.meals.count) meals")
                    self.calculateStats()
                    self.calculateWeeklyStats()
                }
            } catch {
                DispatchQueue.main.async {
                    self.networkError = .dataLoadFailed
                }
                print("❌ Meal decode error: \(error)")
            }
        }.resume()
    }
    
    func fetchWaterData() {
        guard let userId = getCurrentUserId(),
              let url = URL(string: "https://food-app-recipe.onrender.com/user-water?user_id=\(userId)") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Water fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([WaterEntry].self, from: data)
                DispatchQueue.main.async {
                    self.waterIntake = decoded
                    self.calculateWaterStats()
                    print("✅ Loaded \(decoded.count) water entries")
                }
            } catch {
                print("❌ Water decode error: \(error)")
            }
        }.resume()
    }
    
    func fetchExerciseData() {
        guard let userId = getCurrentUserId(),
              let url = URL(string: "https://food-app-recipe.onrender.com/user-exercise?user_id=\(userId)") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Exercise fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([ExerciseEntry].self, from: data)
                DispatchQueue.main.async {
                    self.exerciseEntries = decoded
                    self.calculateExerciseStats()
                    print("✅ Loaded \(decoded.count) exercise entries")
                }
            } catch {
                print("❌ Exercise decode error: \(error)")
            }
        }.resume()
    }
    
    func fetchWeightData() {
        guard let userId = getCurrentUserId(),
              let url = URL(string: "https://food-app-recipe.onrender.com/user-weight?user_id=\(userId)") else {
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Weight fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([WeightEntry].self, from: data)
                DispatchQueue.main.async {
                    self.weightEntries = decoded.sorted { $0.recorded_at > $1.recorded_at }
                    self.calculateWeightStats()
                    print("✅ Loaded \(decoded.count) weight entries")
                }
            } catch {
                print("❌ Weight decode error: \(error)")
            }
        }.resume()
    }
    
    func calculateStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? today
        
        var todayCalories = 0
        var todayProtein = 0
        var todayCarbs = 0
        var todayFat = 0
        var todayFiber = 0
        var todaySugar = 0
        var todaySodium = 0
        
        var monthlyCalories = 0
        var monthlyDaysWithMeals = Set<String>()
        
        for meal in meals {
            guard let savedAt = meal.saved_at,
                  let mealDate = ISO8601DateFormatter().date(from: savedAt) else {
                continue
            }
            
            let mealCalories = meal.nutrition_facts.calories
            let mealProtein = meal.nutrition_facts.protein
            let mealCarbs = meal.nutrition_facts.carbs
            let mealFat = meal.nutrition_facts.fat
            let mealFiber = meal.nutrition_facts.fiber ?? 0
            let mealSugar = meal.nutrition_facts.sugar ?? 0
            let mealSodium = meal.nutrition_facts.sodium ?? 0

            // Today's stats
            if calendar.isDate(mealDate, inSameDayAs: today) {
                todayCalories += Int(mealCalories)
                todayProtein += Int(mealProtein)
                todayCarbs += Int(mealCarbs)
                todayFat += Int(mealFat)
                todayFiber += Int(mealFiber)
                todaySugar += Int(mealSugar)
                todaySodium += Int(mealSodium)
            }
            
            // Monthly stats
            if mealDate >= startOfMonth {
                monthlyCalories += Int(mealCalories)
                let dayKey = calendar.dateComponents([.year, .month, .day], from: mealDate)
                monthlyDaysWithMeals.insert("\(dayKey.year!)-\(dayKey.month!)-\(dayKey.day!)")
            }
        }
        
        withAnimation {
            self.todayCalories = todayCalories
            self.totalProtein = todayProtein
            self.totalCarbs = todayCarbs
            self.totalFat = todayFat
            self.totalFiber = todayFiber
            self.totalSugar = todaySugar
            self.totalSodium = todaySodium
            self.monthlyCalories = monthlyCalories
            self.monthlyAvgCalories = monthlyDaysWithMeals.count > 0 ? monthlyCalories / monthlyDaysWithMeals.count : 0
        }
        
        print("📊 Today's stats: \(todayCalories)kcal, \(todayProtein)g protein")
        print("📊 Monthly stats: \(monthlyCalories)kcal total, \(monthlyAvgCalories)kcal avg")
    }
    
    func calculateWaterStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        
        var todayWater = 0.0
        var weeklyWaterEntries: [Double] = []
        
        for entry in waterIntake {
            if let entryDate = ISO8601DateFormatter().date(from: entry.recorded_at) {
                if calendar.isDate(entryDate, inSameDayAs: today) {
                    todayWater += entry.amount
                }
                if entryDate >= startOfWeek {
                    weeklyWaterEntries.append(entry.amount)
                }
            }
        }
        
        withAnimation {
            self.todayWater = todayWater
            self.weeklyAvgWater = weeklyWaterEntries.isEmpty ? 0 : weeklyWaterEntries.reduce(0, +) / Double(weeklyWaterEntries.count)
        }
    }
    
    func calculateExerciseStats() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        
        var todayExercise = 0
        var weeklyExercise = 0
        
        for entry in exerciseEntries {
            if let entryDate = ISO8601DateFormatter().date(from: entry.recorded_at) {
                if calendar.isDate(entryDate, inSameDayAs: today) {
                    todayExercise += entry.duration
                }
                if entryDate >= startOfWeek {
                    weeklyExercise += entry.duration
                }
            }
        }
        
        withAnimation {
            self.todayExercise = todayExercise
            self.weeklyExercise = weeklyExercise
        }
    }
    
    func calculateWeightStats() {
        if let latestWeight = weightEntries.first {
            withAnimation {
                self.currentWeight = latestWeight.weight
            }
        }
    }
    
    func calculateWeeklyStats() {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        weeklyMeals = meals.filter { meal in
            guard let savedAt = meal.saved_at,
                  let mealDate = ISO8601DateFormatter().date(from: savedAt) else {
                return false
            }
            return mealDate >= startOfWeek
        }.count
    }
    
    func calculateStreak() {
        // Simple streak calculation - count consecutive days with meals
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for _ in 0..<30 { // Check last 30 days
            let hasMealOnDay = meals.contains { meal in
                guard let savedAt = meal.saved_at,
                      let mealDate = ISO8601DateFormatter().date(from: savedAt) else {
                    return false
                }
                return calendar.isDate(mealDate, inSameDayAs: currentDate)
            }
            
            if hasMealOnDay {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        withAnimation {
            self.currentStreak = streak
        }
    }
    
    func handleNetworkErrorRetry() {
        networkError = nil
        fetchAllData()
        profileManager.fetchProfile(force: true)
    }
    
    func getCurrentUserId() -> String? {
        if !session.userID.isEmpty {
            return session.userID
        }
        return UserDefaults.standard.string(forKey: "user_id")
    }
    
    func isSameDay(_ dateString: String?) -> Bool {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return false
        }
        return Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    func daysInCurrentMonth() -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: Date())
        return range?.count ?? 30
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
    
    func refreshDashboard() async {
        print("🔄 Dashboard refresh triggered")
        await withCheckedContinuation { continuation in
            hasInitialized = false
            networkError = nil
            profileManager.fetchProfile(force: true)
            fetchAllData()
            calculateStreak()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                continuation.resume()
            }
        }
    }
    
    func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Macro goal calculations based on calorie target
    func calculateProteinGoal() -> Int {
        return Int(Double(dynamicCalorieGoal) * 0.2 / 4)
    }
    
    func calculateCarbGoal() -> Int {
        return Int(Double(dynamicCalorieGoal) * 0.5 / 4)
    }
    
    func calculateFatGoal() -> Int {
        return Int(Double(dynamicCalorieGoal) * 0.3 / 9)
    }
}

// MARK: - Enhanced Supporting Views

struct MacroCard: View {
    let title: String
    let value: Int
    let unit: String
    let color: Color
    let icon: String
    let goal: Int
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }
    
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
            
            // Progress indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
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
    let subtitle: String
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(color)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

struct WeeklyStatCard: View {
    let title: String
    let value: Int
    let unit: String
    let goal: Int
    let color: Color
    let icon: String
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text("\(value) \(unit)")
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("of \(goal)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EnhancedMealCard: View {
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
                Text(meal.dish_name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(meal.nutrition_facts.calories, specifier: "%.0f") kcal", systemImage: "flame.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)


                    
                    if let mealType = meal.meal_type {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(mealType)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if let savedAt = meal.saved_at,
                   let date = ISO8601DateFormatter().date(from: savedAt) {
                    Text(formatMealTime(date))
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
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
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
    
    func formatMealTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    let target: String
    let progress: Double
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
                
                HStack {
                    Text("Target: \(target)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(Int(min(progress, 1.0) * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
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
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

