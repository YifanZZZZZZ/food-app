// MARK: - UploadMealView.swift
import SwiftUI
import PhotosUI

// Additional Structs & Helpers (auto-inserted)

struct GeminiResult: Codable {
    let image_description: String
    let dish_prediction: String
    let hidden_ingredients: String?
    let nutrition_info: String
}

func parseIngredientLines(from text: String) -> [String] {
    text.split(separator: "\n").compactMap { line in
        let parts = line.split(separator: "|")
        guard parts.count == 4 else { return nil }
        return "\(parts[0].trimmingCharacters(in: .whitespaces)) — \(parts[1].trimmingCharacters(in: .whitespaces)) \(parts[2].trimmingCharacters(in: .whitespaces)) (\(parts[3].trimmingCharacters(in: .whitespaces)))"
    }
}

func parseNutritionLines(from text: String) -> [String] {
    text.split(separator: "\n").compactMap { line in
        let parts = line.split(separator: "|")
        guard parts.count == 4 else { return nil }
        return "\(parts[0].trimmingCharacters(in: .whitespaces)) — \(parts[1].trimmingCharacters(in: .whitespaces)) \(parts[2].trimmingCharacters(in: .whitespaces)) (\(parts[3].trimmingCharacters(in: .whitespaces)))"
    }
}

func extractCalories(from text: String) -> Int? {
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: "|")
        if parts.count == 4, parts[0].lowercased().contains("calories") {
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }
    }
    return nil
}


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
                            ProgressView("Analyzing...")
                                .foregroundColor(.white)
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
                                    }

                                    HStack {
                                        Spacer()
                                        Button("Save to Diary") {
                                            saveMealToBackend()
                                        }
                                        .foregroundColor(.green)
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

                // Toast Notification
                VStack {
                    if showToast {
                        Text("Meal saved!")
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
        let url = URL(string: "https://food-app-swift.onrender.com/")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async { completion() }
        }.resume()
    }

    func analyzeImage() {
        guard let image = selectedImage else { return }
        isLoading = true

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            isLoading = false
            return
        }

        let url = URL(string: "https://food-app-swift.onrender.com/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let userId = UserDefaults.standard.string(forKey: "user_id") ?? "guest"

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
        let session = URLSession(configuration: config)

        session.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }

            guard let data = data, error == nil else { return }

            if let result = try? JSONDecoder().decode(GeminiResult.self, from: data) {
                DispatchQueue.main.async {
                    self.detectedDish = result.dish_prediction
                    self.visibleIngredientLines = parseIngredientLines(from: result.image_description)
                    self.hiddenIngredientLines = parseIngredientLines(from: result.hidden_ingredients ?? "")
                    self.nutritionLines = parseNutritionLines(from: result.nutrition_info)
                    self.calories = extractCalories(from: result.nutrition_info)
                    self.rawNutritionInfo = result.nutrition_info
                }
            }
        }.resume()
    }

    func saveMealToBackend() {
        guard let dish = detectedDish else { return }
        let userId = UserDefaults.standard.string(forKey: "user_id") ?? "guest"

        let fullImageBase64 = selectedImage?.jpegData(compressionQuality: 0.9)?.base64EncodedString() ?? ""
        let thumbnailBase64 = selectedImage?.jpegData(compressionQuality: 0.1)?.base64EncodedString() ?? ""

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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            }
        }.resume()
    }
}
