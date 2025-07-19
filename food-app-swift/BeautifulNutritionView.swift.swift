//
//  BeautifulNutritionView.swift.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 7/19/25.
//

// Create BeautifulNutritionView.swift

import SwiftUI

struct BeautifulNutritionView: View {
    let nutritionText: String
    @State private var nutritionItems: [NutritionItem] = []
    
    var caloriesItem: NutritionItem? {
        nutritionItems.first { $0.name.lowercased().contains("calorie") }
    }
    
    var otherItems: [NutritionItem] {
        nutritionItems.filter { !$0.name.lowercased().contains("calorie") }
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
            }
            
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .onAppear {
            parseNutrition()
        }
        .onChange(of: nutritionText) { _, _ in
            parseNutrition()
        }
    }
    
    private func parseNutrition() {
        withAnimation(.easeInOut(duration: 0.3)) {
            nutritionItems = NutritionParser.parseNutrition(from: nutritionText)
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
