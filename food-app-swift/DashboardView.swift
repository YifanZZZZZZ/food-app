// MARK: - DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @State private var meals: [Meal] = []
    @State private var totalCalories = 0
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(meals.indices, id: \ .self) { index in
                                let meal = meals[index]
                                VStack(alignment: .leading, spacing: 6) {
                                    if let uiImage = decodeBase64ToUIImage(meal.image_thumb ?? "") {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 140, height: 90)
                                            .clipped()
                                            .cornerRadius(12)
                                    } else {
                                        Rectangle()
                                            .fill(Color.orange.opacity(0.9))
                                            .frame(width: 140, height: 90)
                                            .cornerRadius(12)
                                    }

                                    Text(meal.dish_prediction)
                                        .foregroundColor(.white)
                                        .font(.subheadline)

                                    Text("\(extractCalories(from: meal.nutrition_info) ?? 0) kcal")
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.caption2)

                                    if let savedAt = meal.saved_at,
                                       let date = ISO8601DateFormatter().date(from: savedAt) {
                                        Text("🕒 \(formattedDate(date))")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .id(index)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: meals.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(meals.count - 1, anchor: .trailing)
                        }
                    }
                }

                // FAB Buttons
                VStack(spacing: 14) {
                    NavigationLink(destination: UploadMealView()) {
                        Label("Upload Meal", systemImage: "plus")
                            .padding()
                            .frame(width: 160)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: MealHistoryView()) {
                        Label("View Summary", systemImage: "chart.bar")
                            .padding()
                            .frame(width: 160)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: fetchMeals)
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MealSaved"))) { _ in
                fetchMeals()
            }
        }
    }

    // MARK: - Networking
    func fetchMeals() {
        guard let userId = Optional(SessionManager.shared.userID), !userId.isEmpty,
              let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(userId)") else {
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let fetchedMeals = try? JSONDecoder().decode([Meal].self, from: data) else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            DispatchQueue.main.async {
                self.meals = fetchedMeals
                self.totalCalories = fetchedMeals.reduce(0) {
                    $0 + (extractCalories(from: $1.nutrition_info) ?? 0)
                }
                self.isLoading = false
            }
        }.resume()
    }

    func decodeBase64ToUIImage(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    func extractCalories(from nutritionText: String) -> Int? {
        for line in nutritionText.split(separator: "\n") {
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

struct Meal: Codable, Identifiable {
    var id = UUID()
    let user_id: String
    let dish_prediction: String
    let image_description: String
    let nutrition_info: String
    let image_thumb: String?
    let image_full: String?
    let hidden_ingredients: String?
    let saved_at: String?
}
