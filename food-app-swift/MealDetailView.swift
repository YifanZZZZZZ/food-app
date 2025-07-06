import SwiftUI

struct MealDetailView: View {
    @State var meal: Meal
    @State private var isEditing = false
    @State private var editedDishName: String = ""
    @State private var editedIngredients: [EditableIngredient] = []
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Image
                if let base64 = meal.image_full, let uiImage = decodeBase64ToUIImage(base64) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .cornerRadius(14)
                        .padding(.horizontal)
                } else {
                    Rectangle()
                        .fill(Color.orange.opacity(0.7))
                        .frame(height: 220)
                        .cornerRadius(14)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 14) {
                    // Dish Name
                    if isEditing {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dish Name")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Dish name", text: $editedDishName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.black)
                        }
                    } else {
                        Text(meal.dish_prediction)
                            .font(.title3)
                            .bold()
                            .foregroundColor(.white)
                    }

                    // Meal info
                    HStack(spacing: 16) {
                        if let savedAt = meal.saved_at,
                           let date = ISO8601DateFormatter().date(from: savedAt) {
                            Label(formatDate(date), systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let mealType = meal.meal_type {
                            Label(mealType, systemImage: "fork.knife")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    // Ingredients
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("🧾 Ingredients")
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                            
                            if isEditing {
                                Button(action: { addNewIngredient() }) {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        if isEditing {
                            ForEach($editedIngredients) { $ingredient in
                                EditableIngredientRow(
                                    ingredient: $ingredient,
                                    onDelete: { removeIngredient(id: ingredient.id) }
                                )
                            }
                        } else {
                            ForEach(meal.image_description.split(separator: "\n"), id: \.self) { line in
                                Text("• \(line)").foregroundColor(.white)
                            }
                        }
                    }

                    // Hidden Ingredients
                    if let hidden = meal.hidden_ingredients, !hidden.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🫙 Hidden Ingredients")
                                .foregroundColor(.pink)
                                .fontWeight(.semibold)

                            ForEach(hidden.split(separator: "\n"), id: \.self) { line in
                                Text("• \(line)").foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }

                    // Nutrition Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🍎 Nutrition Info")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)

                        let lines = parseNutritionLinesFallback(meal.nutrition_info)
                        ForEach(lines, id: \.self) { line in
                            Text("• \(line)").foregroundColor(.white.opacity(0.9))
                        }
                        
                        if let calories = extractCalories(from: meal.nutrition_info) {
                            Text("🔥 Total: \(calories) kcal")
                                .foregroundColor(.yellow)
                                .fontWeight(.semibold)
                                .padding(.top, 4)
                        }
                    }

                    // Action Buttons
                    HStack {
                        if isEditing {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        } else {
                            Button("Edit") {
                                startEditing()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)

                            Button("Delete") {
                                showDeleteAlert = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .overlay(
                                isDeleting ? ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                : nil
                            )
                            .disabled(isDeleting)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .navigationTitle("Meal Detail")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Meal", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMeal()
            }
        } message: {
            Text("Are you sure you want to delete this meal? This action cannot be undone.")
        }
    }
    
    // Helper Functions
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
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
        // Update the meal object
        meal.dish_prediction = editedDishName
        meal.image_description = editedIngredients.map {
            "\($0.name) | \($0.quantity) | \($0.unit) | Edited"
        }.joined(separator: "\n")
        
        // Call backend to update meal
        updateMealInBackend()
    }
    
    func updateMealInBackend() {
        guard let url = URL(string: "https://food-app-swift.onrender.com/update-meal") else { return }
        
        let payload: [String: Any] = [
            "meal_id": meal._id,
            "dish_prediction": meal.dish_prediction,
            "image_description": meal.image_description
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    self.isEditing = false
                    // Post notification to refresh meal lists
                    NotificationCenter.default.post(name: Notification.Name("MealUpdated"), object: nil)
                }
            }
        }.resume()
    }
    
    func deleteMeal() {
        isDeleting = true
        
        guard let url = URL(string: "https://food-app-swift.onrender.com/delete-meal") else { return }
        
        let payload = ["meal_id": meal._id]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    // Post notification to refresh meal lists
                    NotificationCenter.default.post(name: Notification.Name("MealDeleted"), object: nil)
                    self.dismiss()
                }
            }
        }.resume()
    }

    func decodeBase64ToUIImage(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    func parseNutritionLinesFallback(_ text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|")
            if parts.count >= 2 {
                let nutrient = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                let unit = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
                return "\(nutrient) — \(value) \(unit)"
            } else {
                return String(line)
            }
        }
    }
    
    func parseIngredientsToEditable(from text: String) -> [EditableIngredient] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
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
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, parts[0].lowercased().contains("calories") {
                return Int(parts[1])
            }
        }
        return nil
    }
}

struct EditableIngredientRow: View {
    @Binding var ingredient: EditableIngredient
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $ingredient.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
            
            TextField("Qty", text: $ingredient.quantity)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 60)
                .keyboardType(.decimalPad)
            
            TextField("Unit", text: $ingredient.unit)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 60)
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}
