import SwiftUI

struct BeautifulNutritionView: View {
    let nutritionText: String
    @State private var nutritionItems: [NutritionItem] = []
    @State private var debugInfo: String = ""
    
    var caloriesItem: NutritionItem? {
        nutritionItems.first { $0.name.lowercased().contains("calorie") }
    }
    
    var otherItems: [NutritionItem] {
        nutritionItems.filter { !$0.name.lowercased().contains("calorie") }
    }
    
    var hasValidNutrition: Bool {
        !nutritionItems.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text("Nutrition Facts")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                // Debug button (only in development)
                #if DEBUG
                Button("Debug") {
                    print("🔍 DEBUG Nutrition Text:")
                    print("Raw text: '\(nutritionText)'")
                    print("Parsed items: \(nutritionItems.count)")
                    for item in nutritionItems {
                        print("- \(item.name): \(item.value) \(item.unit)")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
                #endif
            }
            
            if hasValidNutrition {
                // Calories Highlight (if available)
                if let calories = caloriesItem {
                    CaloriesHighlightCard(item: calories)
                }
                
                // Other Nutrients Grid
                if !otherItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detailed Breakdown")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(otherItems) { item in
                                NutrientCard(item: item)
                            }
                        }
                    }
                }
                
                // All Nutrients List (Alternative compact view)
                VStack(spacing: 8) {
                    ForEach(nutritionItems) { item in
                        NutrientRow(item: item)
                    }
                }
            } else {
                // Show error state when no nutrition is found
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.orange.opacity(0.6))
                    
                    Text("Nutrition data unavailable")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Unable to parse nutrition information for this meal")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    // Show raw data in development
                    #if DEBUG
                    ScrollView {
                        Text("Raw data: \(nutritionText)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .frame(maxHeight: 100)
                    #endif
                    
                    // Retry button
                    Button("Try Parsing Again") {
                        parseNutritionRobust()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: hasValidNutrition ?
                                    [.orange.opacity(0.3), .orange.opacity(0.1)] :
                                    [.red.opacity(0.3), .red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            parseNutritionRobust()
        }
        .onChange(of: nutritionText) { _, _ in
            parseNutritionRobust()
        }
    }
    
    // MARK: - Enhanced Nutrition Parsing
    
    private func parseNutritionRobust() {
        print("🔍 Starting robust nutrition parsing...")
        print("📄 Input text (\(nutritionText.count) chars): '\(nutritionText.prefix(200))'")
        
        // Try the standard parser first
        var items = NutritionParser.parseNutrition(from: nutritionText)
        
        // If standard parsing fails, try alternative methods
        if items.isEmpty {
            print("⚠️ Standard parsing failed, trying alternative methods...")
            items = parseNutritionAlternative(from: nutritionText)
        }
        
        // If still no items, try super basic parsing
        if items.isEmpty {
            print("⚠️ Alternative parsing failed, trying basic extraction...")
            items = parseNutritionBasic(from: nutritionText)
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            nutritionItems = items
        }
        
        print("📊 Final parsing result: \(items.count) items")
        for item in items {
            print("✅ \(item.name): \(item.value) \(item.unit)")
        }
    }
    
    // Alternative parsing method for edge cases
    private func parseNutritionAlternative(from text: String) -> [NutritionItem] {
        var items: [NutritionItem] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty or invalid lines
            if trimmedLine.isEmpty ||
               trimmedLine.contains("------") ||
               trimmedLine.hasPrefix("---") ||
               trimmedLine.lowercased().contains("ingredient | quantity") {
                continue
            }
            
            // Try different parsing approaches
            if let item = parseLineWithMultipleSeparators(line: trimmedLine) {
                items.append(item)
            }
        }
        
        return items
    }
    
    // Parse with multiple separator types
    private func parseLineWithMultipleSeparators(line: String) -> NutritionItem? {
        let separators = ["|", ":", "-", "—", "–"]
        
        for separator in separators {
            let parts = line.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            if parts.count >= 2 {
                let name = parts[0]
                let valueAndUnit = parts[1]
                
                // Skip invalid names
                if name.isEmpty || name.contains("---") || name.lowercased() == "ingredient" {
                    continue
                }
                
                // Extract value and unit from "123 g" or "123g" format
                if let (value, unit) = extractValueAndUnit(from: valueAndUnit) {
                    return NutritionItem(
                        name: name,
                        value: value,
                        unit: unit,
                        reasoning: parts.count > 2 ? parts[2] : nil
                    )
                }
            }
        }
        
        return nil
    }
    
    // Extract value and unit from combined string
    private func extractValueAndUnit(from text: String) -> (String, String)? {
        let pattern = #"(\d+\.?\d*)\s*([a-zA-Z]*)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        if let match = regex?.firstMatch(in: text, range: range),
           let valueRange = Range(match.range(at: 1), in: text),
           let unitRange = Range(match.range(at: 2), in: text) {
            
            let value = String(text[valueRange])
            let unit = String(text[unitRange])
            
            // Validate value is numeric
            if Double(value) != nil || Int(value) != nil {
                return (value, unit.isEmpty ? "unit" : unit)
            }
        }
        
        return nil
    }
    
    // Basic parsing as last resort
    private func parseNutritionBasic(from text: String) -> [NutritionItem] {
        var items: [NutritionItem] = []
        
        // Look for common nutrition keywords with numbers
        let nutritionKeywords = [
            "calories", "kcal", "protein", "carbohydrate", "carbs",
            "fat", "fiber", "sugar", "sodium", "vitamin", "calcium", "iron"
        ]
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            for keyword in nutritionKeywords {
                if lowercaseLine.contains(keyword) {
                    // Try to find numbers in the line
                    let numberPattern = #"\b(\d+\.?\d*)\b"#
                    let regex = try? NSRegularExpression(pattern: numberPattern)
                    let range = NSRange(location: 0, length: line.utf16.count)
                    
                    if let match = regex?.firstMatch(in: line, range: range),
                       let numberRange = Range(match.range(at: 1), in: line) {
                        
                        let value = String(line[numberRange])
                        let unit = extractUnit(from: line, keyword: keyword)
                        
                        items.append(NutritionItem(
                            name: keyword.capitalized,
                            value: value,
                            unit: unit,
                            reasoning: "Basic extraction"
                        ))
                    }
                }
            }
        }
        
        return items
    }
    
    // Extract likely unit for a nutrient
    private func extractUnit(from line: String, keyword: String) -> String {
        let lowercaseLine = line.lowercased()
        
        // Common unit patterns
        if lowercaseLine.contains("kcal") || lowercaseLine.contains("calorie") {
            return "kcal"
        } else if lowercaseLine.contains("mg") {
            return "mg"
        } else if lowercaseLine.contains("g") {
            return "g"
        } else if lowercaseLine.contains("ml") {
            return "ml"
        } else {
            return "unit"
        }
    }
}

// MARK: - Supporting Views

struct CaloriesHighlightCard: View {
    let item: NutritionItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.red.opacity(0.3), .orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(.orange)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text(item.value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(item.unit)
                        .font(.title3)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }
                
                Text(item.name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.red.opacity(0.1), .orange.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct NutrientCard: View {
    let item: NutritionItem
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundColor(item.color)
            
            // Value
            VStack(spacing: 2) {
                HStack(alignment: .bottom, spacing: 2) {
                    Text(item.value)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    
                    Text(item.unit)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(item.name)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(item.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct NutrientRow: View {
    let item: NutritionItem
    
    var body: some View {
        HStack {
            // Left side - Nutrient name with icon
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .foregroundColor(item.color)
                    .font(.subheadline)
                    .frame(width: 20)
                
                Text(item.name)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Right side - Value and unit
            HStack(alignment: .bottom, spacing: 2) {
                Text(item.value)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Text(item.unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Preview
struct BeautifulNutritionView_Previews: PreviewProvider {
    static var previews: some View {
        BeautifulNutritionView(nutritionText: """
            Calories | 450 | kcal | From rice and chicken
            Protein | 25 | g | From chicken and lentils
            Fat | 12 | g | From cooking oil and meat
            Carbohydrates | 60 | g | From rice and vegetables
            Fiber | 8 | g | From vegetables and grains
            Sugar | 5 | g | Natural sugars from vegetables
            Sodium | 800 | mg | From salt and seasonings
            """)
        .preferredColorScheme(.dark)
        .padding()
        .background(Color.black)
    }
}
