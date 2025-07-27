import SwiftUI
import PhotosUI

struct UploadMealView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoading = false
    @State private var isSaving: Bool = false

    @State private var detectedDish: String = ""
    @State private var ingredientList: [String] = []
    @State private var nutritionMap: [String: Double] = [:]
    @State private var calories: Int?
    @State private var showToast = false
    @State private var errorMessage = ""
    @State private var retryCount = 0
    
    @State private var selectedDate = Date()
    @State private var selectedMealType = "Lunch"
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
                                            ingredientList = []
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
                            } else if isSaving {
                                SavingView()
                            }
                            else if !errorMessage.isEmpty {
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
                                        
                                        TextField("Dish name", text: $detectedDish)
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
                                    
                                    
                                    // Ingredients
                                    if !ingredientList.isEmpty {
                                        VStack(alignment: .leading, spacing: 16) {
                                            SectionHeader(
                                                title: "Ingredients",
                                                icon: "eye.slash.fill",
                                                color: Color.pink,
                                            )
                                            
                                            VStack(spacing: 12) {
                                                ForEach(ingredientList, id: \.self) { ingredient in
                                                    IngredientDisplay(text: ingredient)
                                                }
                                                
                                            }
                                            
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    // Nutrition Info
                                    // Haven't debug
                                    NutritionCard(
                                        nutritionMap: nutritionMap,
                                        calories: calories,
                                    )
                                    .padding(.horizontal)
                                    
                                    
                                    Button(action: saveMeal) {
                                        Text("Add Meal")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.green)
                                            .cornerRadius(12)
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 32)
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
            ingredientList = []
            nutritionMap = [:]
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
                
                //debug
                switch result {
                case .success(let meal):
                    withAnimation(.spring()) {
                        self.detectedDish = meal.dish_name
                        self.ingredientList = meal.ingredient_list
                        self.nutritionMap = meal.nutrition_facts.asDictionary
                        self.calories = Int(meal.nutrition_facts.calories)
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
    
        func saveMeal() {
            print("✅ Add Meal tapped")

            guard let image = selectedImage,
                  let fullData = image.jpegData(compressionQuality: 0.8),
                  let thumbData = image.jpegData(compressionQuality: 0.2) else {
                errorMessage = "Missing or invalid image."
                return
            }

            let base64Full = fullData.base64EncodedString()
            let base64Thumb = thumbData.base64EncodedString()

            let newMeal = MealUploadRequest(
                user_id: UserDefaults.standard.string(forKey: "user_id") ?? "unknown",
                dish_name: detectedDish,
                ingredient_list: ingredientList,
                nutrition_facts: nutritionMap,
                meal_type: selectedMealType,
                saved_at: ISO8601DateFormatter().string(from: selectedDate),
                image_full: base64Full,
                image_thumb: base64Thumb
            )

            isSaving = true

            NetworkManager.shared.saveMeal(meal: newMeal) { success in
                isSaving = false
                if success {
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showToast = false
                        NotificationCenter.default.post(name: Notification.Name("MealSaved"), object: nil)
                        dismiss()
                    }
                }
                else {
                    errorMessage = "Failed to save meal. Please try again."
                }
            }
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
                
                Text("Identifying ingredients and hidden components")
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

struct SavingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .green))
                .scaleEffect(1.5)
            Text("Saving meal...")
                .foregroundColor(.white)
                .font(.headline)
        }
        .padding()
    }
}


struct NutritionCard: View {
    let nutritionMap: [String : Double]
    let calories: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(Color.purple)
                
                Text("Nutrition Facts")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
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
                ForEach(nutritionMap.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    if key.lowercased() != "calories" {
                        HStack {
                            Circle()
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 8, height: 8)

                            Text("\(key): \(formatDouble(value))")
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
    
    func formatDouble(_ value: Double) -> String {
        return String(format: "%.0f", value)
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
