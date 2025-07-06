import SwiftUI
import PhotosUI

struct UploadMealView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoading = false
    @State private var detectedDish: String = ""
    @State private var editableDishName: String = ""
    @State private var visibleIngredients: [EditableIngredient] = []
    @State private var hiddenIngredients: [EditableIngredient] = []
    @State private var nutritionLines: [String] = []
    @State private var rawNutritionInfo: String = ""
    @State private var calories: Int?
    @State private var showToast = false
    @State private var errorMessage = ""
    @State private var retryCount = 0
    
    // New states for meal customization
    @State private var selectedDate = Date()
    @State private var selectedMealType = "Lunch"
    @State private var isEditingIngredients = false
    @State private var showDatePicker = false
    
    let mealTypes = ["Breakfast", "Lunch", "Evening Snacks", "Dinner"]

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Upload a Meal")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Pick an Image")
                                .padding()
                                .frame(width: 200)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .onChange(of: selectedPhoto, initial: false) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    self.selectedImage = uiImage
                                    self.errorMessage = ""
                                    self.retryCount = 0
                                    analyzeImage()
                                }
                            }
                        }

                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 180)
                                .cornerRadius(10)
                                .shadow(radius: 5)

                            if isLoading {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                                        .scaleEffect(1.5)
                                    Text("Analyzing your meal...")
                                        .foregroundColor(.white)
                                    Text("This may take up to 1 minute")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            } else if !errorMessage.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                    
                                    Text("Analysis Failed")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                        .font(.subheadline)
                                    
                                    Button(action: {
                                        errorMessage = ""
                                        analyzeImage()
                                    }) {
                                        Label("Try Again", systemImage: "arrow.clockwise")
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.orange)
                                            .foregroundColor(.white)
                                            .cornerRadius(20)
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            } else if !detectedDish.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Editable dish name
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("🍛 Dish Name")
                                            .foregroundColor(.white)
                                            .fontWeight(.semibold)
                                        
                                        TextField("Dish name", text: $editableDishName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .foregroundColor(.black)
                                    }
                                    
                                    // Meal Type and Date Selection
                                    HStack(spacing: 16) {
                                        // Meal Type Picker
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Meal Type")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Menu {
                                                ForEach(mealTypes, id: \.self) { type in
                                                    Button(type) {
                                                        selectedMealType = type
                                                    }
                                                }
                                            } label: {
                                                HStack {
                                                    Text(selectedMealType)
                                                    Spacer()
                                                    Image(systemName: "chevron.down")
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                            }
                                        }
                                        
                                        // Date Picker
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Date")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Button(action: { showDatePicker.toggle() }) {
                                                HStack {
                                                    Text(formatDate(selectedDate))
                                                    Spacer()
                                                    Image(systemName: "calendar")
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(Color.white.opacity(0.1))
                                                .cornerRadius(8)
                                                .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    
                                    // Editable Ingredients Section
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("🧾 Ingredients")
                                                .font(.headline)
                                                .foregroundColor(.orange)
                                            
                                            Spacer()
                                            
                                            Button(action: { isEditingIngredients.toggle() }) {
                                                Text(isEditingIngredients ? "Done" : "Edit")
                                                    .font(.caption)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 4)
                                                    .background(Color.orange.opacity(0.2))
                                                    .cornerRadius(12)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        
                                        ForEach($visibleIngredients) { $ingredient in
                                            IngredientRow(ingredient: $ingredient, isEditing: isEditingIngredients)
                                        }
                                        
                                        if isEditingIngredients {
                                            Button(action: addNewIngredient) {
                                                Label("Add Ingredient", systemImage: "plus.circle")
                                                    .font(.caption)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    
                                    // Hidden Ingredients
                                    if !hiddenIngredients.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("🫙 Hidden Ingredients")
                                                .font(.headline)
                                                .foregroundColor(.pink)
                                            
                                            ForEach($hiddenIngredients) { $ingredient in
                                                IngredientRow(ingredient: $ingredient, isEditing: isEditingIngredients)
                                            }
                                        }
                                    }
                                    
                                    // Nutrition Info
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("🍎 Nutrition Info")
                                                .font(.headline)
                                                .foregroundColor(.green)
                                            
                                            if isEditingIngredients {
                                                Button(action: recalculateNutrition) {
                                                    Label("Recalculate", systemImage: "arrow.clockwise")
                                                        .font(.caption)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 4)
                                                        .background(Color.green.opacity(0.2))
                                                        .cornerRadius(12)
                                                        .foregroundColor(.green)
                                                }
                                            }
                                        }
                                        
                                        ForEach(nutritionLines, id: \.self) { line in
                                            Text("• \(line)")
                                                .foregroundColor(.white.opacity(0.9))
                                                .font(.subheadline)
                                        }
                                        
                                        if let cal = calories {
                                            Text("🔥 Total Calories: \(cal) kcal")
                                                .foregroundColor(.yellow)
                                                .font(.headline)
                                                .padding(.top, 4)
                                        }
                                    }
                                    
                                    // Save Button
                                    HStack {
                                        Spacer()
                                        Button(action: saveMealToBackend) {
                                            HStack {
                                                Image(systemName: "checkmark.circle.fill")
                                                Text("Save to Diary")
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 12)
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(25)
                                        }
                                    }
                                    .padding(.top, 10)
                                }
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(14)
                            }
                        }
                    }
                    .padding()
                }

                // Toast notification
                VStack {
                    if showToast {
                        Text("✅ Meal saved successfully!")
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(12)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate)
            }
        }
    }
    
    // Helper functions
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func addNewIngredient() {
        visibleIngredients.append(EditableIngredient(
            id: UUID().uuidString,
            name: "New Ingredient",
            quantity: "1",
            unit: "piece"
        ))
    }
    
    func recalculateNutrition() {
        // Call backend to recalculate nutrition based on edited ingredients
        guard let userId = UserDefaults.standard.string(forKey: "user_id") else { return }
        
        isLoading = true
        
        // Prepare ingredients data
        let ingredientsList = visibleIngredients.map { "\($0.name) | \($0.quantity) | \($0.unit)" }.joined(separator: "\n")
        
        // Call a new endpoint to recalculate nutrition
        NetworkManager.shared.recalculateNutrition(
            ingredients: ingredientsList,
            userId: userId
        ) { result in
            self.isLoading = false
            
            switch result {
            case .success(let nutritionData):
                self.nutritionLines = self.parseNutritionLines(from: nutritionData.nutrition_info)
                self.calories = self.extractCalories(from: nutritionData.nutrition_info)
                self.rawNutritionInfo = nutritionData.nutrition_info
                
            case .failure(let error):
                self.errorMessage = "Failed to recalculate nutrition: \(error.localizedDescription)"
            }
        }
    }

    func resizeImage(_ image: UIImage, maxDimension: CGFloat = 800) -> UIImage? {
        let size = image.size
        
        var newSize: CGSize
        if size.width > size.height {
            if size.width > maxDimension {
                newSize = CGSize(width: maxDimension, height: size.height * maxDimension / size.width)
            } else {
                return image
            }
        } else {
            if size.height > maxDimension {
                newSize = CGSize(width: size.width * maxDimension / size.height, height: maxDimension)
            } else {
                return image
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = 0.7
        var imageData = image.jpegData(compressionQuality: compression)
        
        while let data = imageData,
              data.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        return imageData
    }

    func analyzeImage() {
        guard let image = selectedImage else { return }
        isLoading = true
        errorMessage = ""
        
        NetworkManager.shared.checkHealth { isHealthy, status in
            if !isHealthy {
                self.isLoading = false
                self.errorMessage = "Server is not responding. Please try again later."
                return
            }
            
            self.performImageAnalysis(image: image)
        }
    }

    func performImageAnalysis(image: UIImage) {
        // Clear previous results
        detectedDish = ""
        editableDishName = ""
        visibleIngredients = []
        hiddenIngredients = []
        nutritionLines = []
        calories = nil
        
        let resizedImage = resizeImage(image, maxDimension: 800) ?? image
        guard let imageData = compressImage(resizedImage, maxSizeKB: 500) else {
            isLoading = false
            errorMessage = "Failed to process image. Please try a different photo."
            return
        }
        
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        if userId.isEmpty {
            isLoading = false
            errorMessage = "Login session missing. Please log in again."
            return
        }
        
        NetworkManager.shared.uploadImage(imageData: imageData, userId: userId) { result in
            self.isLoading = false
            
            switch result {
            case .success(let geminiResult):
                self.detectedDish = geminiResult.dish_prediction
                self.editableDishName = geminiResult.dish_prediction
                self.visibleIngredients = self.parseIngredientsToEditable(from: geminiResult.image_description)
                self.hiddenIngredients = self.parseIngredientsToEditable(from: geminiResult.hidden_ingredients ?? "")
                self.nutritionLines = self.parseNutritionLines(from: geminiResult.nutrition_info)
                self.calories = self.extractCalories(from: geminiResult.nutrition_info)
                self.rawNutritionInfo = geminiResult.nutrition_info
                
            case .failure(let error):
                if (error as NSError).code == NSURLErrorTimedOut {
                    self.errorMessage = "Analysis timed out. Try a clearer image or check your connection."
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func saveMealToBackend() {
        guard !editableDishName.isEmpty else {
            errorMessage = "Please enter a dish name"
            return
        }
        
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        if userId.isEmpty {
            errorMessage = "Login session missing. Please log in again."
            return
        }

        let fullImageData = compressImage(selectedImage!, maxSizeKB: 1000)
        let thumbnailData = compressImage(selectedImage!, maxSizeKB: 100)
        
        let fullImageBase64 = fullImageData?.base64EncodedString() ?? ""
        let thumbnailBase64 = thumbnailData?.base64EncodedString() ?? ""
        
        // Convert editable ingredients back to string format
        let visibleIngredientsString = visibleIngredients.map {
            "\($0.name) | \($0.quantity) | \($0.unit) | User edited"
        }.joined(separator: "\n")
        
        let hiddenIngredientsString = hiddenIngredients.map {
            "\($0.name) | \($0.quantity) | \($0.unit) | User edited"
        }.joined(separator: "\n")

        let payload: [String: Any] = [
            "user_id": userId,
            "dish_prediction": editableDishName,
            "image_description": visibleIngredientsString,
            "hidden_ingredients": hiddenIngredientsString,
            "nutrition_info": rawNutritionInfo,
            "image_full": fullImageBase64,
            "image_thumb": thumbnailBase64,
            "meal_type": selectedMealType,
            "saved_at": ISO8601DateFormatter().string(from: selectedDate)
        ]

        guard let url = URL(string: "https://food-app-swift.onrender.com/save-meal"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            errorMessage = "Failed to prepare meal data"
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to save meal: \(error.localizedDescription)"
                    return
                }
                
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    NotificationCenter.default.post(name: Notification.Name("MealSaved"), object: nil)
                    self.showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.dismiss()
                    }
                } else {
                    self.errorMessage = "Failed to save meal. Please try again."
                }
            }
        }.resume()
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

    func parseNutritionLines(from text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count >= 2 else { return nil }
            let nutrient = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            let unit = parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : ""
            return "\(nutrient) — \(value) \(unit)"
        }
    }

    func extractCalories(from text: String) -> Int? {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|")
            if parts.count >= 2, parts[0].lowercased().contains("calories") {
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
}

// Supporting Views and Models
struct EditableIngredient: Identifiable {
    let id: String
    var name: String
    var quantity: String
    var unit: String
}

struct IngredientRow: View {
    @Binding var ingredient: EditableIngredient
    let isEditing: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            if isEditing {
                TextField("Name", text: $ingredient.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)
                
                TextField("Qty", text: $ingredient.quantity)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .keyboardType(.decimalPad)
                
                TextField("Unit", text: $ingredient.unit)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            } else {
                Text("• \(ingredient.name) — \(ingredient.quantity) \(ingredient.unit)")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)
            }
        }
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
