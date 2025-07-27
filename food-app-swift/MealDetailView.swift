import SwiftUI

struct MealDetailView: View {
    @State var meal: Meal
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) var dismiss


    var body: some View {
            ZStack {
                BackgroundGradient()

                ScrollView {
                    VStack(spacing: 0) {
                        MealImageSection(meal: meal, showShareSheet: $showShareSheet)

                        VStack(alignment: .leading, spacing: 24) {
                            TitleAndMetaSection(meal: meal)
                            NutritionFactsSection(meal: meal)
                            IngredientListSection(meal: meal)
                            DeleteButton(isDeleting: $isDeleting, showDeleteAlert: $showDeleteAlert, deleteMeal: deleteMeal)
                        }
                        .padding()
                        .padding(.bottom, 40)
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Meal", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteMeal()
                }
            } message: {
                Text("Are you sure you want to delete this meal? This action cannot be undone.")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [generateShareText()])
            }
        }
    
    // MARK: - Helper Functions
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    func generateShareText() -> String {
        var text = "Check out my meal: \(meal.dish_name)\n\n"
        
        // Add ingredients
        text += "Ingredients:\n"
        for ingredient in meal.ingredient_list {
            text += "• \(ingredient)\n"
        }

        // Add calories if available
        let calories = meal.nutrition_facts.calories
        text += "\nCalories: \(Int(calories)) kcal\n"


        text += "\nTracked with NutriSnap 🍎"
        return text
    }
    
    func deleteMeal() {
        isDeleting = true

        NetworkManager.shared.deleteMeal(mealId: meal.id) { success in
            self.isDeleting = false
            if success {
                NotificationCenter.default.post(name: Notification.Name("MealDeleted"), object: nil)
                self.dismiss()
            }
        }
    }

    func decodeBase64ToUIImage(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }
        return image
    }
}

// MARK: - Supporting Views

struct ActionButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .blur(radius: 10)
                )
        }
    }
}

struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct NutritionOverviewCard: View {
    let nutrition: NutritionFacts

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Facts")
                .font(.headline)
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                NutritionRow(icon: "flame.fill", label: "Calories", value: "\(Int(nutrition.calories)) kcal", color: .red)
                NutritionRow(icon: "flame.fill", label: "Protein", value: "\(Int(nutrition.protein)) g", color: .blue)
                NutritionRow(icon: "leaf.fill", label: "Carbs", value: "\(Int(nutrition.carbs)) g", color: .orange)
                NutritionRow(icon: "drop.fill", label: "Fat", value: "\(Int(nutrition.fat)) g", color: .purple)
                if let fiber = nutrition.fiber {
                    NutritionRow(icon: "scalemass", label: "Fiber", value: "\(Int(fiber)) g", color: .green)
                }
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

    struct NutritionRow: View {
        let icon: String
        let label: String
        let value: String
        let color: Color

        var body: some View {
            HStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(color)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()
            }
        }
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct BackgroundGradient: View {
    var body: some View {
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
    }
}

struct MealImageSection: View {
    let meal: Meal
    @Binding var showShareSheet: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if let base64 = meal.image_full, let uiImage = decodeBase64ToUIImage(base64) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 350)
                    .clipped()
            } else {
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.orange.opacity(0.4), .orange.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 350)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }

            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7), Color.black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 12) {
                ActionButton(icon: "square.and.arrow.up") {
                    showShareSheet = true
                }
                ActionButton(icon: "heart") {
                    // Add to favorites logic
                }
            }
            .padding()
            .padding(.top, 50)
        }
    }
}

struct TitleAndMetaSection: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(meal.dish_name)
                .font(.title2.bold())
                .foregroundColor(.white)

            HStack(spacing: 20) {
                if let savedAt = meal.saved_at,
                   let date = ISO8601DateFormatter().date(from: savedAt) {
                    InfoPill(icon: "calendar", text: formatDate(date), color: .blue)
                }

                if let mealType = meal.meal_type {
                    InfoPill(icon: "fork.knife", text: mealType, color: .purple)
                }

                Label("\(meal.nutrition_facts.calories, specifier: "%.0f") kcal", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct NutritionFactsSection: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Nutrition Facts", icon: "chart.bar.fill", color: .orange)

            ForEach(meal.nutrition_facts.asDictionary.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f", value))
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }

        }
    }
}

struct IngredientListSection: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Ingredients", icon: "leaf.fill", color: .green)

            ForEach(meal.ingredient_list, id: \.self) { ingredient in
                IngredientDisplay(text: ingredient)
            }
        }
    }
}

struct DeleteButton: View {
    @Binding var isDeleting: Bool
    @Binding var showDeleteAlert: Bool
    let deleteMeal: () -> Void

    var body: some View {
        Button(action: { showDeleteAlert = true }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "trash")
                    Text("Delete")
                }
            }
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.red, .red.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isDeleting)
    }
}
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

func decodeBase64ToUIImage(_ base64: String) -> UIImage? {
    guard let data = Data(base64Encoded: base64) else { return nil }
    return UIImage(data: data)
}
