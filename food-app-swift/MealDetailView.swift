import SwiftUI

struct MealDetailView: View {
    @State var meal: Meal
    @State private var isEditing = false
    @State private var editedDishName: String = ""
    @State private var editedIngredients: [EditableIngredient] = []
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var isSaving = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
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
                VStack(spacing: 0) {
                    // Hero Image Section
                    ZStack(alignment: .bottom) {
                        if let base64 = meal.image_full, let uiImage = decodeBase64ToUIImage(base64) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 350)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.orange.opacity(0.4), .orange.opacity(0.2)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 350)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.5))
                                )
                        }
                        
                        // Gradient overlay
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.black.opacity(0.7),
                                Color.black.opacity(0.9)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 150)
                    }
                    .overlay(alignment: .topTrailing) {
                        // Action buttons
                        HStack(spacing: 12) {
                            ActionButton(icon: "square.and.arrow.up") {
                                showShareSheet = true
                            }
                            
                            ActionButton(icon: "heart") {
                                // Favorite action
                            }
                        }
                        .padding()
                        .padding(.top, 50)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 24) {
                        // Title and Meta
                        VStack(alignment: .leading, spacing: 12) {
                            if isEditing {
                                TextField("Dish name", text: $editedDishName)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            } else {
                                Text(meal.dish_prediction)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                            
                            HStack(spacing: 20) {
                                if let savedAt = meal.saved_at,
                                   let date = ISO8601DateFormatter().date(from: savedAt) {
                                    InfoPill(
                                        icon: "calendar",
                                        text: formatDate(date),
                                        color: .blue
                                    )
                                }
                                
                                if let mealType = meal.meal_type {
                                    InfoPill(
                                        icon: "fork.knife",
                                        text: mealType,
                                        color: .purple
                                    )
                                }
                                
                                if let calories = extractCalories(from: meal.nutrition_info) {
                                    InfoPill(
                                        icon: "flame.fill",
                                        text: "\(calories) kcal",
                                        color: .orange
                                    )
                                }
                            }
                        }
                        
                        // Nutrition Overview Card
                        NutritionOverviewCard(nutritionInfo: meal.nutrition_info)
                        
                        // Ingredients Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(Color.green)
                                    
                                    Text("Ingredients")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                
                                if isEditing {
                                    Button(action: addNewIngredient) {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(Color.green)
                                    }
                                }
                            }
                            
                            if isEditing {
                                VStack(spacing: 12) {
                                    ForEach($editedIngredients) { $ingredient in
                                        EditableIngredientRow(
                                            ingredient: $ingredient,
                                            onDelete: { removeIngredient(id: ingredient.id) }
                                        )
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(meal.image_description.split(separator: "\n"), id: \.self) { line in
                                        IngredientDisplay(text: String(line))
                                    }
                                }
                            }
                        }
                        
                        // Hidden Ingredients
                        if let hidden = meal.hidden_ingredients, !hidden.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "eye.slash.fill")
                                            .foregroundColor(Color.pink)
                                        
                                        Text("Hidden Ingredients")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                }
                                
                                VStack(spacing: 8) {
                                    ForEach(hidden.split(separator: "\n"), id: \.self) { line in
                                        IngredientDisplay(text: String(line), isHidden: true)
                                    }
                                }
                            }
                        }
                        
                        // Action Buttons
                        if isEditing {
                            HStack(spacing: 12) {
                                Button(action: cancelEditing) {
                                    Text("Cancel")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                }
                                
                                Button(action: saveChanges) {
                                    HStack {
                                        if isSaving {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "checkmark")
                                            Text("Save")
                                        }
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.green, .green.opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                .disabled(isSaving)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button(action: startEditing) {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Edit")
                                    }
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                
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
    
    // Helper Functions
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    func generateShareText() -> String {
        var text = "Check out my meal: \(meal.dish_prediction)\n\n"
        if let calories = extractCalories(from: meal.nutrition_info) {
            text += "Calories: \(calories) kcal\n"
        }
        text += "\nTracked with NutriSnap 🍎"
        return text
    }
    
    func startEditing() {
        isEditing = true
        editedDishName = meal.dish_prediction
        editedIngredients = parseIngredientsToEditable(from: meal.image_description)
    }
    
    func cancelEditing() {
        isEditing = false
        editedDishName = ""
        editedIngredients = []
    }
    
    func addNewIngredient() {
        editedIngredients.append(EditableIngredient(
            id: UUID().uuidString,
            name: "New Ingredient",
            quantity: "1",
            unit: "piece"
        ))
    }
    
    func removeIngredient(id: String) {
        editedIngredients.removeAll { $0.id == id }
    }
    
    func saveChanges() {
        isSaving = true
        meal.dish_prediction = editedDishName
        meal.image_description = editedIngredients.map {
            "\($0.name) | \($0.quantity) | \($0.unit) | Edited"
        }.joined(separator: "\n")
        
        updateMealInBackend()
    }
    
    func updateMealInBackend() {
        NetworkManager.shared.updateMeal(
            mealId: meal._id,
            dishName: meal.dish_prediction,
            ingredients: meal.image_description
        ) { success in
            self.isSaving = false
            if success {
                self.isEditing = false
                NotificationCenter.default.post(name: Notification.Name("MealUpdated"), object: nil)
            }
        }
    }
    
    func deleteMeal() {
        isDeleting = true
        
        NetworkManager.shared.deleteMeal(mealId: meal._id) { success in
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

    func parseIngredientsToEditable(from text: String) -> [EditableIngredient] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            guard parts.count >= 3 else { return nil }
            return EditableIngredient(
                id: UUID().uuidString,
                name: parts[0],
                quantity: parts[1],
                unit: parts[2]
            )
        }
    }
    
    func extractCalories(from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            if parts.count >= 2, parts[0].lowercased().contains("calories") {
                return Int(parts[1])
            }
        }
        return nil
    }
}

// MARK: - Supporting Views (Only those specific to MealDetailView)

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
    let nutritionInfo: String
    
    var nutritionData: [(String, String, Color)] {
        var data: [(String, String, Color)] = []
        
        for line in nutritionInfo.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            if parts.count >= 2 {
                let nutrient = parts[0]
                let value = parts[1]
                let unit = parts.count > 2 ? parts[2] : ""
                
                var color: Color = .gray
                if nutrient.lowercased().contains("protein") { color = .blue }
                else if nutrient.lowercased().contains("carb") { color = .orange }
                else if nutrient.lowercased().contains("fat") { color = .purple }
                else if nutrient.lowercased().contains("calories") { color = .red }
                
                data.append((nutrient, "\(value) \(unit)", color))
            }
        }
        
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Facts")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(nutritionData.prefix(4), id: \.0) { item in
                    HStack {
                        Circle()
                            .fill(item.2.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: getNutrientIcon(item.0))
                                    .foregroundColor(item.2)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(item.0)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
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
    
    func getNutrientIcon(_ nutrient: String) -> String {
        if nutrient.lowercased().contains("protein") { return "flame.fill" }
        else if nutrient.lowercased().contains("carb") { return "leaf.fill" }
        else if nutrient.lowercased().contains("fat") { return "drop.fill" }
        else if nutrient.lowercased().contains("calories") { return "flame.fill" }
        else { return "circle.fill" }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
