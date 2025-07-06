// Meal.swift

import Foundation

struct Meal: Identifiable, Codable {
    let _id: String
    var id: String { _id }

    let user_id: String
    var dish_prediction: String
    var image_description: String
    let hidden_ingredients: String?
    let nutrition_info: String
    let image_full: String?
    let image_thumb: String?
    let saved_at: String?
    let meal_type: String?  // New field for meal type
}

struct GeminiResult: Codable {
    let image_description: String
    let dish_prediction: String
    let hidden_ingredients: String?
    let nutrition_info: String
}

struct NutritionRecalculationResult: Codable {
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
        if parts.count >= 2, parts[0].lowercased().contains("calories") {
            return Int(parts[1].trimmingCharacters(in: .whitespaces))
        }
    }
    return nil
}
