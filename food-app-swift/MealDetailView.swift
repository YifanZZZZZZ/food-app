import SwiftUI

struct MealDetailView: View {
    let meal: Meal

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ✅ Dynamic Image (if available)
                if let base64 = meal.image_full, let uiImage = decodeBase64ToUIImage(base64) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)
                        .cornerRadius(14)
                        .padding(.horizontal)
                }
                else {
                    Rectangle()
                        .fill(Color.orange.opacity(0.7))
                        .frame(height: 220)
                        .cornerRadius(14)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 14) {
                    // ✅ Dish Title
                    Text(meal.dish_prediction)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)

                    Text("🕒 Logged Meal")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption)

                    // ✅ Ingredients Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🧾 Ingredients")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)

                        ForEach(meal.image_description.split(separator: "\n"), id: \.self) { line in
                            Text("• \(line)").foregroundColor(.white)
                        }
                    }

                    // ✅ Hidden Ingredients
                    if let hidden = meal.hidden_ingredients, !hidden.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🫙 Hidden Ingredients")
                                .foregroundColor(.pink)
                                .fontWeight(.semibold)

                            ForEach(hidden.split(separator: "\n"), id: \.self) { line in
                                Text("• \(line)").foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }

                    // ✅ Nutrition Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🍎 Nutrition Info")
                            .foregroundColor(.green)
                            .fontWeight(.semibold)

                        ForEach(meal.nutrition_info.split(separator: "\n"), id: \.self) { line in
                            Text("• \(line)").foregroundColor(.white.opacity(0.9))
                        }
                    }

                    // 🔧 Action Buttons (stubbed for now)
                    HStack {
                        Button("Edit") {
                            // TODO: Add edit logic
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)

                        Button("Delete") {
                            // TODO: Add delete logic
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.85))
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

    // MARK: - Helper
    func decodeBase64ToUIImage(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }
        return image
    }
}
