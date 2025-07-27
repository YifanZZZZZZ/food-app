//
//  WeightTrackingView.swift
//  food-app-recipe
//
//  Created by Utsav Doshi on 7/16/25.
//

import SwiftUI
import Charts

// MARK: - Weight Entry Model
struct WeightEntry: Identifiable, Codable {
    let _id: String
    let user_id: String
    let weight: Double
    let recorded_at: String
    
    var id: String { _id }
}

// MARK: - Weight Chart Data
struct WeightChartData: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let index: Int
}

struct WeightTrackingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var weightEntries: [WeightEntry] = []
    @State private var currentWeight: String = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var selectedUnit = "kg"
    
    let weightUnits = ["kg", "lbs"]
    
    var latestWeight: Double {
        weightEntries.first?.weight ?? 0
    }
    
    var weightTrend: String {
        guard weightEntries.count >= 2 else { return "No trend data" }
        
        let recent = weightEntries[0].weight
        let previous = weightEntries[1].weight
        let difference = recent - previous
        
        if abs(difference) < 0.1 {
            return "Stable"
        } else if difference > 0 {
            return "↗️ +\(String(format: "%.1f", difference)) \(selectedUnit)"
        } else {
            return "↘️ \(String(format: "%.1f", difference)) \(selectedUnit)"
        }
    }
    
    var chartData: [WeightChartData] {
        return weightEntries.prefix(30).reversed().enumerated().map { index, entry in
            WeightChartData(
                date: ISO8601DateFormatter().date(from: entry.recorded_at) ?? Date(),
                weight: entry.weight,
                index: index
            )
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color(red: 0.2, green: 0.05, blue: 0.2)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.purple)
                            
                            Text("Weight Tracker")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Track your weight progress over time")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Current Weight Display
                        VStack(spacing: 20) {
                            if latestWeight > 0 {
                                VStack(spacing: 12) {
                                    Text("Current Weight")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    HStack(alignment: .bottom, spacing: 4) {
                                        Text(String(format: "%.1f", latestWeight))
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundColor(.purple)
                                        
                                        Text(selectedUnit)
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                            .padding(.bottom, 8)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text(weightTrend)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        
                                        if let lastEntry = weightEntries.first,
                                           let lastDate = ISO8601DateFormatter().date(from: lastEntry.recorded_at) {
                                            Text("Last updated: \(formatDate(lastDate))")
                                                .font(.caption)
                                                .foregroundColor(.gray.opacity(0.7))
                                        }
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "scalemass")
                                        .font(.system(size: 40))
                                        .foregroundColor(.purple.opacity(0.6))
                                    
                                    Text("No weight data yet")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Add your first weight entry to start tracking")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                                .foregroundColor(.purple.opacity(0.3))
                                        )
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Weight Chart
                        if chartData.count > 1 {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Weight Trend")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                Chart(chartData) { data in
                                    LineMark(
                                        x: .value("Date", data.date),
                                        y: .value("Weight", data.weight)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .lineStyle(StrokeStyle(lineWidth: 3))
                                    
                                    PointMark(
                                        x: .value("Date", data.date),
                                        y: .value("Weight", data.weight)
                                    )
                                    .foregroundStyle(Color.purple)
                                    .symbolSize(50)
                                }
                                .frame(height: 200)
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                                        AxisGridLine()
                                            .foregroundStyle(Color.white.opacity(0.1))
                                        AxisTick()
                                            .foregroundStyle(Color.white.opacity(0.3))
                                        AxisValueLabel()
                                            .foregroundStyle(Color.gray)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisGridLine()
                                            .foregroundStyle(Color.white.opacity(0.1))
                                        AxisTick()
                                            .foregroundStyle(Color.white.opacity(0.3))
                                        AxisValueLabel()
                                            .foregroundStyle(Color.gray)
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
                            .padding(.horizontal)
                        }
                        
                        // Add Weight Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add Weight Entry")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            VStack(spacing: 16) {
                                // Unit Selector
                                Picker("Unit", selection: $selectedUnit) {
                                    ForEach(weightUnits, id: \.self) { unit in
                                        Text(unit).tag(unit)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .padding(.horizontal)
                                
                                // Weight Input
                                HStack {
                                    TextField("Enter weight", text: $currentWeight)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(maxWidth: 120)
                                    
                                    Text(selectedUnit)
                                        .foregroundColor(.gray)
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    if let weight = Double(currentWeight) {
                                        let converted = selectedUnit == "kg" ? weight * 2.20462 : weight / 2.20462
                                        let otherUnit = selectedUnit == "kg" ? "lbs" : "kg"
                                        Text("≈ \(String(format: "%.1f", converted)) \(otherUnit)")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // Quick weight buttons (if user has previous entries)
                                if !weightEntries.isEmpty {
                                    VStack(spacing: 8) {
                                        Text("Quick adjustments")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        HStack {
                                            ForEach([-2, -1, -0.5, 0.5, 1, 2], id: \.self) { adjustment in
                                                Button("\(adjustment > 0 ? "+" : "")\(String(format: "%.1f", adjustment))") {
                                                    let newWeight = latestWeight + adjustment
                                                    currentWeight = String(format: "%.1f", newWeight)
                                                }
                                                .font(.caption)
                                                .foregroundColor(.purple)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.purple.opacity(0.1))
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Add Button
                        Button(action: addWeight) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Weight Entry")
                                }
                            }
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple, .purple.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isLoading || currentWeight.isEmpty)
                        .padding(.horizontal)
                        
                        // Recent History
                        if !weightEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent History")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(Array(weightEntries.prefix(10))) { entry in
                                        WeightHistoryRowView(entry: entry, unit: selectedUnit)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
                
                // Success Animation
                if showSuccess {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Weight logged!")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Capsule()
                                .fill(Color.green)
                                .shadow(color: .green.opacity(0.3), radius: 10)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                    }
                    .animation(.spring(), value: showSuccess)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
            .onAppear {
                fetchWeightData()
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func fetchWeightData() {
        guard let userId = getCurrentUserId() else { return }
        
        guard let url = URL(string: "https://food-app-recipe.onrender.com/user-weight?user_id=\(userId)") else { return }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Weight fetch error: \(error?.localizedDescription ?? "Unknown")")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([WeightEntry].self, from: data)
                DispatchQueue.main.async {
                    self.weightEntries = decoded.sorted { entry1, entry2 in
                        let date1 = ISO8601DateFormatter().date(from: entry1.recorded_at) ?? Date()
                        let date2 = ISO8601DateFormatter().date(from: entry2.recorded_at) ?? Date()
                        return date1 > date2
                    }
                }
            } catch {
                print("❌ Weight decode error: \(error)")
            }
        }.resume()
    }
    
    func addWeight() {
        guard let weight = Double(currentWeight),
              weight > 0 else { return }
        
        guard let userId = getCurrentUserId() else { return }
        
        guard let url = URL(string: "https://food-app-recipe.onrender.com/add-weight") else { return }
        
        isLoading = true
        
        // Convert to kg if needed for storage
        let weightInKg = selectedUnit == "lbs" ? weight / 2.20462 : weight
        
        let payload: [String: Any] = [
            "user_id": userId,
            "weight": weightInKg,
            "recorded_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Add to local array for immediate UI update
                    let newEntry = WeightEntry(
                        _id: UUID().uuidString,
                        user_id: userId,
                        weight: weightInKg,
                        recorded_at: ISO8601DateFormatter().string(from: Date())
                    )
                    
                    self.weightEntries.insert(newEntry, at: 0)
                    
                    // Show success animation
                    withAnimation(.spring()) {
                        self.showSuccess = true
                    }
                    
                    // Hide success animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.spring()) {
                            self.showSuccess = false
                        }
                    }
                    
                    // Post notification
                    NotificationCenter.default.post(name: Notification.Name("WeightAdded"), object: nil)
                    
                    // Reset form
                    self.currentWeight = ""
                }
            }
        }.resume()
    }
    
    func getCurrentUserId() -> String? {
        // Check SessionManager first - userID is String, not String?
        let sessionId = SessionManager.shared.userID
        if !sessionId.isEmpty {
            return sessionId
        }
        
        // Check UserDefaults as fallback
        return UserDefaults.standard.string(forKey: "user_id")
    }
}

// MARK: - Supporting Views
struct WeightHistoryRowView: View {
    let entry: WeightEntry
    let unit: String
    
    var displayWeight: Double {
        return unit == "lbs" ? entry.weight * 2.20462 : entry.weight
    }
    
    var dateString: String {
        guard let date = ISO8601DateFormatter().date(from: entry.recorded_at) else {
            return "Unknown date"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "scalemass.fill")
                .foregroundColor(.purple)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f %@", displayWeight, unit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(dateString)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Trend indicator
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 8, height: 8)
                .scaleEffect(1.5)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: entry.weight
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
