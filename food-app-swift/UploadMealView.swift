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
    @State private var showSaveAlert = false

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
                                            Text("• \($0)")
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }

                                    if !hiddenIngredientLines.isEmpty {
                                        Text("🫙 Hidden Ingredients:")
                                            .font(.headline)
                                            .foregroundColor(.pink)
                                        ForEach(hiddenIngredientLines, id: \.self) {
                                            Text("• \($0)")
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }

                                    if !nutritionLines.isEmpty {
                                        Text("🍎 Nutrition Info:")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        ForEach(nutritionLines, id: \.self) {
                                            Text("• \($0)")
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    } else if !rawNutritionInfo.isEmpty {
                                        Text("🍎 Nutrition Info (Raw Output):")
                                            .font(.headline)
                                            .foregroundColor(.yellow)
                                        Text(rawNutritionInfo)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }

                                    if let cal = calories {
                                        Text("🔥 Estimated Calories: \(cal) kcal")
                                            .foregroundColor(.yellow)
                                    }

                                    HStack {
                                        Button("Edit Ingredients") {
                                            // Placeholder for future editing logic
                                        }
                                        .foregroundColor(.orange)

                                        Spacer()

                                        Button("Save to Diary") {
                                            showSaveAlert = true
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
            }
            .preferredColorScheme(.dark)
            .alert("Saved!", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    func analyzeImage() {
        guard let image = selectedImage else { return }
        isLoading = true

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            isLoading = false
            return
        }

        let url = URL(string: "https://food-app-swift.onrender.com/analyze")! // ✅ LIVE BACKEND
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("ios_user_123\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async { self.isLoading = false }

            guard let data = data, error == nil else {
                print("Network error:", error?.localizedDescription ?? "Unknown error")
                return
            }

            do {
                let result = try JSONDecoder().decode(GeminiResult.self, from: data)
                DispatchQueue.main.async {
                    self.detectedDish = result.dish_prediction
                    self.visibleIngredientLines = parseIngredientLines(from: result.image_description)
                    self.hiddenIngredientLines = parseIngredientLines(from: result.hidden_ingredients ?? "")
                    self.nutritionLines = parseNutritionLines(from: result.nutrition_info)
                    self.calories = extractCalories(from: result.nutrition_info)
                    self.rawNutritionInfo = result.nutrition_info
                }
            } catch {
                print("Decoding error:", error)
                print(String(data: data, encoding: .utf8) ?? "No response string")
            }
        }.resume()
    }
}

// MARK: - Models & Helpers

struct GeminiResult: Codable {
    let image_description: String
    let dish_prediction: String
    let hidden_ingredients: String?
    let nutrition_info: String
}

func parseIngredientLines(from text: String) -> [String] {
    text
        .split(separator: "\n")
        .compactMap { line in
            let parts = line.split(separator: "|")
            guard parts.count == 4 else { return nil }
            return "\(parts[0].trimmingCharacters(in: .whitespaces)) — \(parts[1].trimmingCharacters(in: .whitespaces)) \(parts[2].trimmingCharacters(in: .whitespaces)) (\(parts[3].trimmingCharacters(in: .whitespaces)))"
        }
}

func parseNutritionLines(from text: String) -> [String] {
    text
        .split(separator: "\n")
        .compactMap { line in
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
