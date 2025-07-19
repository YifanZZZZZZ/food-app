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
    @State private var showProfileAlert = false
    
    // Summary toggle state
    @State private var selectedSummaryTab = 0 // 0 = Today's, 1 = Weekly
    
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
                        
                        // Profile completion alert
                        if profileManager.userProfile == nil && !profileManager.isLoading {
                            profileIncompleteSection
                        }
                        
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
                        
                        // Recent Meals Section (moved up)
                        if !meals.isEmpty {
                            recentMealsSection
                        }
                        
                        // Summary Section with Toggle
                        summaryToggleSection
                        
                        // Today's Nutrients Section
                        if !meals.isEmpty {
                            enhancedNutritionBreakdownSection
                        }
                        
                        // Quick Actions with More Options
                        enhancedQuickActionsSection
                        
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
            .alert("Complete Your Profile", isPresented: $showProfileAlert) {
                Button("Complete Now") {
                    showProfile = true
                }
                Button("Later", role: .cancel) { }
            } message: {
                Text("Set up your profile to get personalized nutrition goals and better tracking.")
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
                    } else {
                        Circle()
                            .fill(Color.red)
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
    
    var profileIncompleteSection: some View {
        HStack {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Complete Your Profile")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Set up your nutrition goals for personalized tracking")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button("Setup") {
                showProfile = true
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.orange)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
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
        // Enhanced Main Calorie Card - More Catchy & Compact
        HStack(spacing: 0) {
            // Left Content Section
            VStack(alignment: .leading, spacing: 12) {
                // Header with dynamic icon
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(calorieProgressColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: getCalorieStatusIcon())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(calorieProgressColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Calories")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text(selectedTimeFilter)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }
                    
                    if profileManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(0.7)
                    }
                }
                
                // Main Calorie Display with Animation
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(animateCalories ? displayedCalories : 0)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: displayedCalories)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("/ \(displayedGoal)")
                            .font(.callout)
                            .foregroundColor(.gray)
                        
                        Text("kcal")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .padding(.bottom, 4)
                }
                
                // Dynamic Status Message
                HStack {
                    Text(getCalorieStatusMessage())
                        .font(.caption)
                        .foregroundColor(calorieProgressColor)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Right Circular Progress Section
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                // Progress Circle with Gradient
                Circle()
                    .trim(from: 0, to: animateCalories ? calorieProgress : 0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: calorieProgressColor, location: 0.0),
                                .init(color: calorieProgressColor.opacity(0.8), location: 0.5),
                                .init(color: calorieProgressColor, location: 1.0)
                            ]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.2), value: calorieProgress)
                
                // Center Content
                VStack(spacing: 2) {
                    Text("\(Int(calorieProgress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Image(systemName: getTrendIcon())
                        .font(.system(size: 8))
                        .foregroundColor(calorieProgressColor)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Base Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.06))
                
                // Dynamic Accent Border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                calorieProgressColor.opacity(0.3),
                                calorieProgressColor.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                
                // Subtle Glow Effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                calorieProgressColor.opacity(0.03),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
    }
    
    // MARK: - Dynamic Helper Functions for Enhanced Card
    
    private func getCalorieStatusIcon() -> String {
        if calorieProgress < 0.3 { return "arrow.up.circle.fill" }
        else if calorieProgress < 0.7 { return "checkmark.circle.fill" }
        else if calorieProgress < 1.0 { return "exclamationmark.circle.fill" }
        else { return "xmark.circle.fill" }
    }
    
    private func getCalorieStatusMessage() -> String {
        if calorieProgress < 0.3 { return "Great start! Keep it up" }
        else if calorieProgress < 0.7 { return "On track for your goal" }
        else if calorieProgress < 1.0 { return "Almost there!" }
        else if calorieProgress < 1.2 { return "Goal achieved!" }
        else { return "Over goal - consider lighter options" }
    }
    
    private func getTrendIcon() -> String {
        if calorieProgress < 0.5 { return "arrow.up" }
        else if calorieProgress < 1.0 { return "arrow.right" }
        else { return "arrow.down" }
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
                EmptyMealsStateCard()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(meals.prefix(6))) { meal in
                            FixedSizeMealCard(meal: meal)
                                .onTapGesture {
                                    print("🍽️ Meal tapped: \(meal.dish_prediction)")
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    var summaryToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Toggle Header
            HStack {
                Text("Summary")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                // Toggle Buttons
                HStack(spacing: 0) {
                    Button(action: { withAnimation { selectedSummaryTab = 0 } }) {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(selectedSummaryTab == 0 ? .semibold : .regular)
                            .foregroundColor(selectedSummaryTab == 0 ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedSummaryTab == 0 ? Color.orange : Color.clear)
                            )
                    }
                    
                    Button(action: { withAnimation { selectedSummaryTab = 1 } }) {
                        Text("Weekly")
                            .font(.caption)
                            .fontWeight(selectedSummaryTab == 1 ? .semibold : .regular)
                            .foregroundColor(selectedSummaryTab == 1 ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedSummaryTab == 1 ? Color.orange : Color.clear)
                            )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
            }
            
            // Summary Content
            if selectedSummaryTab == 0 {
                todaySummaryContent
            } else {
                weeklySummaryContent
            }
        }
    }
    
    var todaySummaryContent: some View {
        VStack(spacing: 12) {
            DashboardSummaryRow(
                icon: "drop.fill",
                title: "Water Intake",
                value: "\(Int(todayWater)) ml",
                target: "2000 ml",
                progress: todayWater / 2000.0,
                color: waterProgressColor
            )
            
            DashboardSummaryRow(
                icon: "figure.run",
                title: "Exercise",
                value: "\(todayExercise) min",
                target: "30 min",
                progress: Double(todayExercise) / 30.0,
                color: exerciseProgressColor
            )
            
            DashboardSummaryRow(
                icon: "fork.knife",
                title: "Meals",
                value: "\(meals.filter { isSameDay($0.saved_at) }.count) meals",
                target: "3-4 meals",
                progress: Double(meals.filter { isSameDay($0.saved_at) }.count) / 3.0,
                color: .orange
            )
            
            if currentWeight > 0 {
                DashboardSummaryRow(
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
    
    var weeklySummaryContent: some View {
        VStack(spacing: 12) {
            DashboardWeeklyStatCard(
                title: "Exercise",
                value: weeklyExercise,
                unit: "min",
                goal: 150,
                color: .green,
                icon: "figure.run"
            )
            
            DashboardWeeklyStatCard(
                title: "Avg Water",
                value: Int(weeklyAvgWater),
                unit: "ml",
                goal: 2000,
                color: .blue,
                icon: "drop.fill"
            )
            
            DashboardWeeklyStatCard(
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
    
    var enhancedNutritionBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Nutrition")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            let todaysNutritionText = createTodaysNutritionText()
            
            if !todaysNutritionText.isEmpty {
                CompactNutritionView(nutritionText: todaysNutritionText)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text("No nutrition data yet")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Add a meal to see your breakdown")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
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
    }
    
    var enhancedQuickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            // Compact 2x2 Grid
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    CompactActionButton(
                        title: "Water",
                        icon: "drop.fill",
                        color: waterProgressColor,
                        subtitle: "\(Int(todayWater))ml",
                        progress: todayWater / 2000.0
                    ) {
                        showWaterTracking = true
                    }
                    
                    CompactActionButton(
                        title: "Exercise",
                        icon: "figure.run",
                        color: exerciseProgressColor,
                        subtitle: "\(todayExercise) min",
                        progress: Double(todayExercise) / 30.0
                    ) {
                        showExerciseTracking = true
                    }
                }
                
                HStack(spacing: 10) {
                    CompactActionButton(
                        title: "Weight",
                        icon: "scalemass.fill",
                        color: .purple,
                        subtitle: currentWeight > 0 ? String(format: "%.1f kg", currentWeight) : "Add",
                        progress: currentWeight > 0 ? 1.0 : 0.0
                    ) {
                        showWeightTracking = true
                    }
                    
                    CompactActionButton(
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
    }
    
    var healthInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Insights")
                .font(.title3.bold())
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                if calorieProgress > 1.2 {
                    DashboardInsightCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Calorie Intake High",
                        message: "You've exceeded your daily calorie goal. Consider lighter meals.",
                        color: .red
                    )
                }
                
                if todayWater < 1000 {
                    DashboardInsightCard(
                        icon: "drop.fill",
                        title: "Stay Hydrated",
                        message: "You're behind on your water intake. Drink more water!",
                        color: .blue
                    )
                }
                
                if todayExercise == 0 {
                    DashboardInsightCard(
                        icon: "figure.run",
                        title: "Get Moving",
                        message: "You haven't logged any exercise today. Try a short walk!",
                        color: .green
                    )
                }
                
                if currentStreak >= 7 {
                    DashboardInsightCard(
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
    
    // MARK: - Helper Functions
    
    func createTodaysNutritionText() -> String {
        let todaysMeals = meals.filter { isSameDay($0.saved_at) }
        
        if todaysMeals.isEmpty {
            return ""
        }
        
        var totalCalories = 0
        var totalProtein = 0
        var totalCarbs = 0
        var totalFat = 0
        var totalFiber = 0
        var totalSugar = 0
        var totalSodium = 0
        
        print("🔍 Processing \(todaysMeals.count) meals for today's nutrition")
        
        for meal in todaysMeals {
            print("📊 Processing meal: \(meal.dish_prediction)")
            print("📄 Nutrition text: \(meal.nutrition_info)")
            
            let mealCalories = extractNutrient(name: "calories", from: meal.nutrition_info) ?? 0
            let mealProtein = extractNutrient(name: "protein", from: meal.nutrition_info) ?? 0
            let mealCarbs = extractNutrient(name: "carbohydrates", from: meal.nutrition_info) ?? 0
            let mealFat = extractNutrient(name: "fat", from: meal.nutrition_info) ?? 0
            let mealFiber = extractNutrient(name: "fiber", from: meal.nutrition_info) ?? 0
            let mealSugar = extractNutrient(name: "sugar", from: meal.nutrition_info) ?? 0
            let mealSodium = extractNutrient(name: "sodium", from: meal.nutrition_info) ?? 0
            
            totalCalories += mealCalories
            totalProtein += mealProtein
            totalCarbs += mealCarbs
            totalFat += mealFat
            totalFiber += mealFiber
            totalSugar += mealSugar
            totalSodium += mealSodium
            
            print("📊 Meal totals - Calories: \(mealCalories), Protein: \(mealProtein), Carbs: \(mealCarbs), Fat: \(mealFat)")
        }
        
        print("📊 Final totals - Calories: \(totalCalories), Protein: \(totalProtein), Carbs: \(totalCarbs), Fat: \(totalFat)")
        
        return """
        Calories|\(totalCalories)|kcal
        Protein|\(totalProtein)|g
        Fat|\(totalFat)|g
        Carbohydrates|\(totalCarbs)|g
        Fiber|\(totalFiber)|g
        Sugar|\(totalSugar)|g
        Sodium|\(totalSodium)|mg
        """
    }
    
    // MARK: - All Data Functions
    
    func initializeDashboard() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        print("🏠 Dashboard initializing...")
        
        loadUserPreferences()
        
        if profileManager.userProfile == nil {
            profileManager.fetchProfile()
        }
        
        fetchAllData()
        calculateStreak()
        
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
        if let profile = profileManager.userProfile {
            calorieGoal = profile.calorieTarget
            print("📊 Loaded calorie goal from profile: \(calorieGoal)")
        } else {
            if let saved = UserDefaults.standard.object(forKey: "calorie_target") as? Int {
                calorieGoal = saved
                print("📱 Loaded calorie goal from UserDefaults: \(calorieGoal)")
            }
        }
    }
    
    func fetchMeals() {
        guard let userId = getCurrentUserId(),
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else {
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
              let url = URL(string: "https://food-app-swift.onrender.com/user-water?user_id=\(userId)") else {
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
              let url = URL(string: "https://food-app-swift.onrender.com/user-exercise?user_id=\(userId)") else {
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
              let url = URL(string: "https://food-app-swift.onrender.com/user-weight?user_id=\(userId)") else {
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
    
    // MARK: - Calculation Functions
    
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
            
            let mealCalories = extractNutrient(name: "calories", from: meal.nutrition_info) ?? 0
            let mealProtein = extractNutrient(name: "protein", from: meal.nutrition_info) ?? 0
            let mealCarbs = extractNutrient(name: "carbohydrates", from: meal.nutrition_info) ?? 0
            let mealFat = extractNutrient(name: "fat", from: meal.nutrition_info) ?? 0
            let mealFiber = extractNutrient(name: "fiber", from: meal.nutrition_info) ?? 0
            let mealSugar = extractNutrient(name: "sugar", from: meal.nutrition_info) ?? 0
            let mealSodium = extractNutrient(name: "sodium", from: meal.nutrition_info) ?? 0
            
            if calendar.isDate(mealDate, inSameDayAs: today) {
                todayCalories += mealCalories
                todayProtein += mealProtein
                todayCarbs += mealCarbs
                todayFat += mealFat
                todayFiber += mealFiber
                todaySugar += mealSugar
                todaySodium += mealSodium
            }
            
            if mealDate >= startOfMonth {
                monthlyCalories += mealCalories
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
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for _ in 0..<30 {
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
    
    // MARK: - Utility Functions
    
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
            if parts.count >= 2 {
                let nutrientName = parts[0].lowercased()
                // Check for exact matches and common variations
                if nutrientName.contains(name.lowercased()) ||
                   (name.lowercased() == "fat" && (nutrientName.contains("total fat") || nutrientName.contains("fats"))) ||
                   (name.lowercased() == "carbohydrates" && (nutrientName.contains("carb") || nutrientName.contains("carbohydrate"))) ||
                   (name.lowercased() == "protein" && nutrientName.contains("protein")) ||
                   (name.lowercased() == "calories" && (nutrientName.contains("calorie") || nutrientName.contains("kcal"))) {
                    if let value = Int(parts[1]) {
                        print("🔍 Found \(name): \(value) from line: \(line)")
                        return value
                    }
                }
            }
        }
        print("⚠️ Could not find \(name) in nutrition text")
        return nil
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

// MARK: - Supporting View Components

struct FixedSizeMealCard: View {
    let meal: Meal
    @State private var isPressed = false
    @State private var imageLoaded = false
    
    var body: some View {
        VStack(spacing: 0) {
            imageSection
            contentSection
        }
        .frame(width: 180, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
    
    // MARK: - Computed Properties to break down complex views
    
    private var imageSection: some View {
        ZStack {
            // Consistent background for all cards
            Rectangle()
                .fill(Color.white.opacity(0.05))
            
            Group {
                if let base64 = meal.image_thumb ?? meal.image_full,
                   !base64.isEmpty,
                   let data = Data(base64Encoded: base64),
                   let image = UIImage(data: data) {
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(imageLoaded ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                imageLoaded = true
                            }
                        }
                } else {
                    // Consistent placeholder design matching app theme
                    VStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Image")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
            }
            
            // Subtle overlay for better text contrast
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.15)]),
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Calories badge - consistent positioning
            caloriesBadgeOverlay
        }
        .frame(width: 180, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var caloriesBadgeOverlay: some View {
        VStack {
            HStack {
                Spacer()
                if let calories = extractMealCalories(from: meal.nutrition_info) {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        
                        Text("\(calories)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .padding(.top, 6)
                    .padding(.trailing, 6)
                }
            }
            Spacer()
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(meal.dish_prediction)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 2)
            
            // Metadata
            metadataSection
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Meal type
            if let mealType = meal.meal_type {
                HStack(spacing: 3) {
                    Image(systemName: getMealTypeIcon(for: mealType))
                        .font(.system(size: 9))
                        .foregroundColor(.orange.opacity(0.8))
                    
                    Text(mealType)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            // Time
            if let savedAt = meal.saved_at,
               let date = ISO8601DateFormatter().date(from: savedAt) {
                Text(formatMealDateTime(date))
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
    }
    
    // MARK: - Private Helper Functions
    
    private func extractMealCalories(from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, parts[0].lowercased().contains("calorie") {
                return Int(parts[1])
            }
        }
        return nil
    }
    
    private func formatMealDateTime(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private func getMealTypeIcon(for mealType: String) -> String {
        switch mealType.lowercased() {
        case "breakfast":
            return "sun.max.fill"
        case "lunch":
            return "sun.min.fill"
        case "dinner":
            return "moon.stars.fill"
        case "evening snacks", "snacks":
            return "cup.and.saucer.fill"
        default:
            return "fork.knife"
        }
    }
}

// MARK: - Private Supporting Component (Simple and clean)

// MARK: - Private Supporting Component

private struct MealCaloriesBadge: View {
    let calories: Int
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.orange)
            
            Text("\(calories)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Supporting Components

struct EmptyMealsStateCard: View {
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

struct CompactActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let subtitle: String
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Compact Progress Circle
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 28, height: 28)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Dashboard-specific View Components

struct DashboardSummaryRow: View {
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

struct DashboardWeeklyStatCard: View {
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

struct DashboardInsightCard: View {
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

// MARK: - Supporting Data Structures

struct NutritionDisplayItem {
    let name: String
    let value: String
    let unit: String
    let color: Color
}

// MARK: - Compact Nutrition View (Sweet spot sizing)

struct CompactNutritionView: View {
    let nutritionText: String
    
    private var nutritionItems: [NutritionDisplayItem] {
        let lines = nutritionText.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.compactMap { line in
            let components = line.components(separatedBy: "|")
            if components.count >= 3 {
                let name = components[0].trimmingCharacters(in: .whitespaces)
                let value = components[1].trimmingCharacters(in: .whitespaces)
                let unit = components[2].trimmingCharacters(in: .whitespaces)
                return NutritionDisplayItem(
                    name: name,
                    value: value,
                    unit: unit,
                    color: colorForNutrient(name)
                )
            }
            return nil
        }
    }
    
    var caloriesItem: NutritionDisplayItem? {
        nutritionItems.first { $0.name.lowercased().contains("calorie") }
    }
    
    var otherItems: [NutritionDisplayItem] {
        nutritionItems.filter { !$0.name.lowercased().contains("calorie") }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Calories Highlight - Better sizing
            if let calories = caloriesItem {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(calories.value)
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text(calories.unit)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.bottom, 2)
                        }
                        
                        Text(calories.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
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
            
            // Other Nutrients - Sweet spot sizing
            if !otherItems.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(otherItems.prefix(6), id: \.name) { item in
                        OptimizedNutrientCard(item: item)
                    }
                }
            }
        }
    }
    
    private func colorForNutrient(_ name: String) -> Color {
        let lowercased = name.lowercased()
        
        if lowercased.contains("calorie") {
            return .orange
        } else if lowercased.contains("protein") {
            return .blue
        } else if lowercased.contains("carb") {
            return .green
        } else if lowercased.contains("fat") {
            return .yellow
        } else if lowercased.contains("fiber") {
            return .brown
        } else if lowercased.contains("sugar") {
            return .pink
        } else if lowercased.contains("sodium") {
            return .red
        } else {
            return .gray
        }
    }
}

struct OptimizedNutrientCard: View {
    let item: NutritionDisplayItem
    
    var body: some View {
        VStack(spacing: 4) {
            Text(item.value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(item.unit)
                .font(.caption2)
                .foregroundColor(.gray)
            
            Text(item.name)
                .font(.caption2)
                .foregroundColor(item.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(item.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item.color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}
