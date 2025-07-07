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
    
    @State private var selectedDate = Date()
    @State private var selectedMealType = "Lunch"
    @State private var isEditingIngredients = false
    @State private var showDatePicker = false
    @State private var showCamera = false
    @State private var analysisStep = 0 // 0: select, 1: analyzing, 2: results
    
    let mealTypes = ["Breakfast", "Lunch", "Evening Snacks", "Dinner"]
    
    @Environment(\.dismiss) var dismiss

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
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Add Meal")
                                    .font(.largeTitle.bold())
                                    .foregroundColor(.white)
                                
                                Text("Snap and track your nutrition")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        if selectedImage == nil {
                            // Image Selection
                            VStack(spacing: 20) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.orange.opacity(0.2),
                                                    Color.orange.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(height: 250)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                                                .foregroundColor(.orange.opacity(0.5))
                                        )
                                    
                                    VStack(spacing: 16) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.orange)
                                        
                                        Text("Add a photo of your meal")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text("Take a photo or choose from library")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                HStack(spacing: 16) {
                                    // Camera Button
                                    Button(action: { showCamera = true }) {
                                        HStack {
                                            Image(systemName: "camera.fill")
                                            Text("Camera")
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
                                    
                                    // Gallery Button
                                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                        HStack {
                                            Image(systemName: "photo.fill")
                                            Text("Gallery")
                                        }
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
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Image Preview
                            ZStack {
                                Image(uiImage: selectedImage!)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 250)
                                    .clipped()
                                    .cornerRadius(20)
                                    .overlay(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.clear,
                                                Color.black.opacity(0.3)
                                            ]),
                                            startPoint: .center,
                                            endPoint: .bottom
                                        )
                                        .cornerRadius(20)
                                    )
                                
                                // Change Photo Button
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            selectedImage = nil
                                            detectedDish = ""
                                            visibleIngredients = []
                                            nutritionLines = []
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                Text("Change")
                                            }
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.black.opacity(0.6))
                                                    .blur(radius: 10)
                                            )
                                        }
                                        .padding()
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)

                            if isLoading {
                                AnalyzingView()
                            } else if !errorMessage.isEmpty {
                                ErrorView(message: errorMessage, retry: analyzeImage)
                                    .padding(.horizontal)
                            } else if !detectedDish.isEmpty {
                                // Analysis Results
                                VStack(spacing: 20) {
                                    // Dish Name
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("DISH NAME")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .tracking(1)
                                        
                                        TextField("Dish name", text: $editableDishName)
                                            .font(.title3.bold())
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
                                    }
                                    .padding(.horizontal)
                                    
                                    // Meal Type and Date
                                    HStack(spacing: 16) {
                                        MealTypeSelector(selectedType: $selectedMealType)
                                        DateSelector(selectedDate: $selectedDate, showPicker: $showDatePicker)
                                    }
                                    .padding(.horizontal)
                                    
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
                                            
                                            Button(action: { isEditingIngredients.toggle() }) {
                                                Text(isEditingIngredients ? "Done" : "Edit")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.orange)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.orange.opacity(0.2))
                                                            .overlay(
                                                                Capsule()
                                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                                            )
                                                    )
                                            }
                                        }
                                        
                                        VStack(spacing: 12) {
                                            ForEach($visibleIngredients) { $ingredient in
                                                if isEditingIngredients {
                                                    EditableIngredientRow(
                                                        ingredient: $ingredient,
                                                        onDelete: { removeIngredient(id: ingredient.id) }
                                                    )
                                                } else {
                                                    IngredientDisplay(
                                                        text: "\(ingredient.name) — \(ingredient.quantity) \(ingredient.unit)"
                                                    )
                                                }
                                            }
                                            
                                            if isEditingIngredients {
                                                Button(action: addNewIngredient) {
                                                    HStack {
                                                        Image(systemName: "plus.circle.fill")
                                                        Text("Add Ingredient")
                                                    }
                                                    .font(.subheadline)
                                                    .foregroundColor(Color.green)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    // Nutrition Info
                                    NutritionCard(
                                        nutritionLines: nutritionLines,
                                        calories: calories,
                                        onRecalculate: isEditingIngredients ? recalculateNutrition : nil
                                    )
                                    .padding(.horizontal)
                                    
                                    // Save Button
                                    Button(action: saveMealToBackend) {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Save to Diary")
                                        }
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 40)
                                }
                            }
                        }
                    }
                }

                // Success Toast
                if showToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Meal saved successfully!")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            Capsule()
                                .fill(Color.green)
                                .shadow(color: Color.green.opacity(0.3), radius: 10)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                    }
                    .animation(.spring(), value: showToast)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate)
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
        }
    }
    
    // Helper functions
    
    func removeIngredient(id: String) {
        visibleIngredients.removeAll { $0.id == id }
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
        guard let userId = UserDefaults.standard.string(forKey: "user_id") else { return }
        
        isLoading = true
        
        let ingredientsList = visibleIngredients.map { "\($0.name) | \($0.quantity) | \($0.unit)" }.joined(separator: "\n")
        
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
                
            case .failure(_):
                self.errorMessage = "Failed to recalculate nutrition"
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
        detectedDish = ""
        editableDishName = ""
        visibleIngredients = []
        hiddenIngredients = []
        nutritionLines = []
        calories = nil
        
        let resizedImage = resizeImage(image, maxDimension: 800) ?? image
        guard let imageData = compressImage(resizedImage, maxSizeKB: 500) else {
            isLoading = false
            errorMessage = "Failed to process image."
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
                withAnimation(.spring()) {
                    self.detectedDish = geminiResult.dish_prediction
                    self.editableDishName = geminiResult.dish_prediction
                    self.visibleIngredients = self.parseIngredientsToEditable(from: geminiResult.image_description)
                    self.hiddenIngredients = self.parseIngredientsToEditable(from: geminiResult.hidden_ingredients ?? "")
                    self.nutritionLines = self.parseNutritionLines(from: geminiResult.nutrition_info)
                    self.calories = self.extractCalories(from: geminiResult.nutrition_info)
                    self.rawNutritionInfo = geminiResult.nutrition_info
                }
                
            case .failure(let error):
                if (error as NSError).code == NSURLErrorTimedOut {
                    self.errorMessage = "Analysis timed out. Try a clearer image."
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
            errorMessage = "Login session missing."
            return
        }

        let fullImageData = compressImage(selectedImage!, maxSizeKB: 1000)
        let thumbnailData = compressImage(selectedImage!, maxSizeKB: 100)
        
        let fullImageBase64 = fullImageData?.base64EncodedString() ?? ""
        let thumbnailBase64 = thumbnailData?.base64EncodedString() ?? ""
        
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
                if error != nil {
                    self.errorMessage = "Failed to save meal"
                    return
                }
                
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    NotificationCenter.default.post(name: Notification.Name("MealSaved"), object: nil)
                    withAnimation(.spring()) {
                        self.showToast = true
                    }
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

// MARK: - Supporting Views

struct MealTypeSelector: View {
    @Binding var selectedType: String
    let types = ["Breakfast", "Lunch", "Evening Snacks", "Dinner"]
    let icons = ["sun.max.fill", "sun.min.fill", "cup.and.saucer.fill", "moon.fill"]
    
    var body: some View {
        Menu {
            ForEach(Array(zip(types, icons)), id: \.0) { type, icon in
                Button(action: { selectedType = type }) {
                    Label(type, systemImage: icon)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("MEAL TYPE")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .tracking(1)
                
                HStack {
                    Image(systemName: icons[types.firstIndex(of: selectedType) ?? 1])
                        .foregroundColor(.orange)
                    Text(selectedType)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct DateSelector: View {
    @Binding var selectedDate: Date
    @Binding var showPicker: Bool
    
    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }
    
    var body: some View {
        Button(action: { showPicker = true }) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DATE")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .tracking(1)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(Color.blue)
                    Text(dateText)
                        .fontWeight(.medium)
                    Spacer()
                }
                .foregroundColor(.white)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct AnalyzingView: View {
    @State private var dots = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.orange, .orange.opacity(0.5)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(Double(dots) * 120))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: dots
                    )
                
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing your meal")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Using AI to identify ingredients and nutrition")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear {
            dots = 3
        }
    }
}

struct NutritionCard: View {
    let nutritionLines: [String]
    let calories: Int?
    let onRecalculate: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.pie.fill")
                        .foregroundColor(Color.purple)
                    
                    Text("Nutrition Facts")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if let onRecalculate = onRecalculate {
                    Button(action: onRecalculate) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Recalculate")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.purple)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            
            if let calories = calories {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(calories)")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Calories")
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
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(nutritionLines, id: \.self) { line in
                    if !line.lowercased().contains("calories") {
                        HStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 8, height: 8)
                            
                            Text(line)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                        }
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
}


// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}


