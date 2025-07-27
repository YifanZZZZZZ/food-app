// Meal.swift

import Foundation

struct Meal: Identifiable, Codable {
    let _id: String?
    var id: String { _id ?? UUID().uuidString }

    let user_id: String
    let dish_name: String                    // renamed from dish_prediction
    let ingredient_list: [String]            // ✅ new
    let nutrition_facts: NutritionFacts      // ✅ new and structured
    let meal_type: String?
    let saved_at: String?
    let image_full: String?
    let image_thumb: String?
}

struct MealUploadRequest: Codable {
    let user_id: String
    let dish_name: String
    let ingredient_list: [String]
    let nutrition_facts: [String: Double]
    let meal_type: String
    let saved_at: String
    let image_full: String?       // ✅ high-res base64 image
    let image_thumb: String?      // ✅ compressed thumbnail
}


struct NutritionFacts: Codable {
    let calories: Double
    let fat: Double
    let saturatedFat: Double?
    let cholesterol: Double?
    let sodium: Double
    let carbs: Double
    let fiber: Double?
    let sugar: Double?
    let protein: Double

    enum CodingKeys: String, CodingKey {
        case calories = "Calories"
        case fat = "Fat"
        case fatAlt = "FatContent"
        case saturatedFat = "SaturatedFatContent"
        case cholesterol = "CholesterolContent"
        case sodium = "Sodium"
        case sodiumAlt = "SodiumContent"
        case carbs = "Carbohydrates"
        case carbsAlt = "CarbohydrateContent"
        case fiber = "Fiber"
        case fiberAlt = "FiberContent"
        case sugar = "Sugar"
        case sugarAlt = "SugarContent"
        case protein = "Protein"
        case proteinAlt = "ProteinContent"
    }

    // MARK: - Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        calories = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0.0

        fat = try container.decodeIfPresent(Double.self, forKey: .fat)
            ?? container.decodeIfPresent(Double.self, forKey: .fatAlt)
            ?? 0.0

        saturatedFat = try container.decodeIfPresent(Double.self, forKey: .saturatedFat)
        cholesterol = try container.decodeIfPresent(Double.self, forKey: .cholesterol)

        sodium = try container.decodeIfPresent(Double.self, forKey: .sodium)
            ?? container.decodeIfPresent(Double.self, forKey: .sodiumAlt)
            ?? 0.0

        carbs = try container.decodeIfPresent(Double.self, forKey: .carbs)
            ?? container.decodeIfPresent(Double.self, forKey: .carbsAlt)
            ?? 0.0

        fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
            ?? container.decodeIfPresent(Double.self, forKey: .fiberAlt)

        sugar = try container.decodeIfPresent(Double.self, forKey: .sugar)
            ?? container.decodeIfPresent(Double.self, forKey: .sugarAlt)

        protein = try container.decodeIfPresent(Double.self, forKey: .protein)
            ?? container.decodeIfPresent(Double.self, forKey: .proteinAlt)
            ?? 0.0
    }

    // MARK: - Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(calories, forKey: .calories)
        try container.encode(fat, forKey: .fat)
        try container.encodeIfPresent(saturatedFat, forKey: .saturatedFat)
        try container.encodeIfPresent(cholesterol, forKey: .cholesterol)
        try container.encode(sodium, forKey: .sodium)
        try container.encode(carbs, forKey: .carbs)
        try container.encodeIfPresent(fiber, forKey: .fiber)
        try container.encodeIfPresent(sugar, forKey: .sugar)
        try container.encode(protein, forKey: .protein)
    }

    // MARK: - Dictionary Representation
    var asDictionary: [String: Double] {
        var dict: [String: Double] = [
            "Calories": calories,
            "Fat": fat,
            "Sodium": sodium,
            "Carbohydrates": carbs,
            "Protein": protein
        ]
        if let satFat = saturatedFat { dict["SaturatedFat"] = satFat }
        if let cholesterol = cholesterol { dict["Cholesterol"] = cholesterol }
        if let fiber = fiber { dict["Fiber"] = fiber }
        if let sugar = sugar { dict["Sugar"] = sugar }
        return dict
    }
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

