import SwiftUI
import PhotosUI

struct UploadMealView: View {
    @State private var selectedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoading = false
    @State private var detectedDish: String?
    @State private var visibleIngredientLines: [String] = []
    @State private var hiddenIngredientLines: [String] = []
    @State private var nutritionLines: [String] = []
    @State private var rawNutritionInfo: String = ""
    @State private var calories: Int?
    @State private var showToast = false
    @State private var errorMessage = ""
    @State private var retryCount = 0

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

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
                                pingServerBeforeAnalyze {
                                    analyzeImage()
                                }
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
                                if retryCount > 0 {
                                    Text("Retry attempt \(retryCount)")
                                        .font(.caption2)
                                        .foregroundColor(.orange.opacity(0.7))
                                }
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
                        } else if let dish = detectedDish {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("🍛 Dish: \(dish)")
                                        .foregroundColor(.white)
                                        .fontWeight(.semibold)

                                    if !visibleIngredientLines.isEmpty {
                                        Text("🧾 Visible Ingredients:")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                        ForEach(visibleIngredientLines, id: \.self) {
                                            Text("• \($0)").foregroundColor(.white.opacity(0.9))
                                        }
                                    }

                                    if !hiddenIngredientLines.isEmpty {
                                        Text("🫙 Hidden Ingredients:")
                                            .font(.headline)
                                            .foregroundColor(.pink)
                                        ForEach(hiddenIngredientLines, id: \.self) {
                                            Text("• \($0)").foregroundColor(.white.opacity(0.8))
                                        }
                                    }

                                    if !nutritionLines.isEmpty {
                                        Text("🍎 Nutrition Info:")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        ForEach(nutritionLines, id: \.self) {
                                            Text("• \($0)").foregroundColor(.white.opacity(0.9))
                                        }
                                    }

                                    if let cal = calories {
                                        Text("🔥 Estimated Calories: \(cal) kcal")
                                            .foregroundColor(.yellow)
                                            .font(.headline)
                                            .padding(.top, 8)
                                    }

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

                    Spacer()
                }
                .padding()

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
        }
    }

    func pingServerBeforeAnalyze(completion: @escaping () -> Void) {
        let url = URL(string: "https://food-app-swift.onrender.com/ping")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async { completion() }
        }.resume()
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
        
        // Show immediate feedback
        detectedDish = nil
        visibleIngredientLines = []
        hiddenIngredientLines = []
        nutritionLines = []
        calories = nil
        
        // Resize image more aggressively
        let resizedImage = resizeImage(image, maxDimension: 800) ?? image
        
        // Compress image
        guard let imageData = compressImage(resizedImage, maxSizeKB: 500) else {
            isLoading = false
            errorMessage = "Failed to process image. Please try a different photo."
            return
        }
        
        // Check image size
        let imageSizeMB = Double(imageData.count) / (1024.0 * 1024.0)
        print("📷 Image size: \(imageSizeMB)MB")
        
        analyzeWithRetry(imageData: imageData, retryCount: 0)
    }

    private func analyzeWithRetry(imageData: Data, retryCount: Int) {
        self.retryCount = retryCount
        let maxRetries = 2
        
        let url = URL(string: "https://food-app-swift.onrender.com/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90  // 90 seconds timeout
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        if userId.isEmpty {
            errorMessage = "Login session missing. Please log in again."
            isLoading = false
            return
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error as? URLError {
                if error.code == .timedOut && retryCount < maxRetries {
                    // Retry with exponential backoff
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1) * 2) {
                        self.analyzeWithRetry(imageData: imageData, retryCount: retryCount + 1)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch error.code {
                    case .timedOut:
                        self.errorMessage = "Analysis timed out. Try a clearer image or check your connection."
                    case .notConnectedToInternet:
                        self.errorMessage = "No internet connection."
                    case .networkConnectionLost:
                        self.errorMessage = "Connection lost. Please check your network."
                    default:
                        self.errorMessage = "Network error. Please try again."
                    }
                }
                return
            }
            
            DispatchQueue.main.async { self.isLoading = false }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No response from server."
                }
                return
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📋 Response: \(responseString.prefix(200))...")
            }
            
            // Try to decode error response first
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMsg = errorResponse["error"] {
                DispatchQueue.main.async {
                    self.errorMessage = errorMsg
                }
                return
            }
            
            // Try to decode success response
            if let result = try? JSONDecoder().decode(GeminiResult.self, from: data) {
                DispatchQueue.main.async {
                    self.detectedDish = result.dish_prediction
                    self.visibleIngredientLines = self.parseIngredientLines(from: result.image_description)
                    self.hiddenIngredientLines = self.parseIngredientLines(from: result.hidden_ingredients ?? "")
                    self.nutritionLines = self.parseNutritionLines(from: result.nutrition_info)
                    self.calories = self.extractCalories(from: result.nutrition_info)
                    self.rawNutritionInfo = result.nutrition_info
                    print("✅ Analysis successful: \(result.dish_prediction)")
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to process server response. Please try again."
                }
            }
        }.resume()
    }

    func saveMealToBackend() {
        guard let dish = detectedDish else { return }
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? ""
        if userId.isEmpty { return }

        // Use compressed images for storage
        let fullImageData = compressImage(selectedImage!, maxSizeKB: 1000)
        let thumbnailData = compressImage(selectedImage!, maxSizeKB: 100)
        
        let fullImageBase64 = fullImageData?.base64EncodedString() ?? ""
        let thumbnailBase64 = thumbnailData?.base64EncodedString() ?? ""

        let payload: [String: Any] = [
            "user_id": userId,
            "dish_prediction": dish,
            "image_description": visibleIngredientLines.joined(separator: "\n"),
            "hidden_ingredients": hiddenIngredientLines.joined(separator: "\n"),
            "nutrition_info": rawNutritionInfo,
            "image_full": fullImageBase64,
            "image_thumb": thumbnailBase64,
            "saved_at": ISO8601DateFormatter().string(from: Date())
        ]

        guard let url = URL(string: "https://food-app-swift.onrender.com/save-meal"),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Notification.Name("MealSaved"), object: nil)
                    showToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }.resume()
    }

    func parseIngredientLines(from text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count == 4 else { return nil }
            return "\(parts[0].trimmingCharacters(in: .whitespaces)) — \(parts[1].trimmingCharacters(in: .whitespaces)) \(parts[2].trimmingCharacters(in: .whitespaces))"
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
