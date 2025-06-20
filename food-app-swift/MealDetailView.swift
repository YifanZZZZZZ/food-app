//
//  MealDetailView.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/20/25.
//

import SwiftUI

struct MealDetailView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Image
                Rectangle()
                    .fill(Color.orange)
                    .frame(height: 220)
                    .cornerRadius(14)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Grilled Chicken Bowl")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)

                    Text("Logged on: Apr 24 • 1:00 PM")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)

                    // Ingredients
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingredients")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)

                        ForEach(["Chicken", "Spinach", "Brown Rice", "Avocado"], id: \.self) {
                            Text("• \($0)").foregroundColor(.white)
                        }
                    }

                    // Macronutrients
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Macronutrients")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)

                        HStack {
                            VStack {
                                Text("Carbs")
                                Text("40g")
                            }
                            .frame(maxWidth: .infinity)
                            VStack {
                                Text("Protein")
                                Text("35g")
                            }
                            .frame(maxWidth: .infinity)
                            VStack {
                                Text("Fats")
                                Text("18g")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .foregroundColor(.white)
                        .font(.caption)
                    }

                    // Gemini notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)

                        Text("⚠️ High in sodium. Consider reducing added salt or processed sauces.")
                            .foregroundColor(.white.opacity(0.85))
                            .font(.footnote)
                    }

                    HStack {
                        Button("Edit") {
                            // future logic
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Delete") {
                            // delete logic
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .navigationTitle("Meal Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}
