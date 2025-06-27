import SwiftUI

struct MealHistoryView: View {
    @ObservedObject var session = SessionManager.shared
    @State private var meals: [Meal] = []

    struct Meal: Identifiable, Decodable {
        let _id: String
        var id: String { _id }
        let dish_prediction: String
        let nutrition_info: String
        let image_description: String
        let hidden_ingredients: String?
        let image: String?
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(meals) { meal in
                            HStack(spacing: 12) {
                                if let base64 = meal.image,
                                   let image = decodeBase64ToUIImage(base64) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .cornerRadius(10)
                                } else {
                                    Rectangle()
                                        .fill(Color.orange.opacity(0.7))
                                        .frame(width: 70, height: 70)
                                        .cornerRadius(10)
                                }

                                VStack(alignment: .leading) {
                                    Text(meal.dish_prediction)
                                        .foregroundColor(.white)
                                        .bold()

                                    Text(meal.nutrition_info.components(separatedBy: "\n").first ?? "")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(14)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Meal History")
            .onAppear {
                fetchMeals()
            }
        }
    }

    func fetchMeals() {
        guard let url = URL(string: "https://food-app-swift.onrender.com/user-meals?user_id=\(session.userID)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let decoded = try? JSONDecoder().decode([Meal].self, from: data) {
                DispatchQueue.main.async {
                    meals = decoded
                }
            } else {
                print("❌ Failed to decode meal history")
            }
        }.resume()
    }

    func decodeBase64ToUIImage(_ base64: String) -> UIImage? {
        if let data = Data(base64Encoded: base64),
           let image = UIImage(data: data) {
            return image
        }
        return nil
    }
}
