import SwiftUI

struct MealHistoryView: View {
    @ObservedObject var session = SessionManager.shared
    @State private var selectedTab = "Today"
    @State private var meals: [Meal] = []

    let tabs = ["Today", "Week", "Month"]

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

                VStack(spacing: 20) {
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(tabs, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.05))

                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(meals) { meal in
                                NavigationLink(destination: MealDetailView()) {
                                    HStack(spacing: 12) {
                                        if let base64 = meal.image,
                                           let uiImage = decodeBase64ToUIImage(base64) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 70, height: 70)
                                                .cornerRadius(10)
                                        } else {
                                            Rectangle()
                                                .fill(Color.orange.opacity(0.8))
                                                .frame(width: 70, height: 70)
                                                .cornerRadius(10)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(meal.dish_prediction)
                                                .foregroundColor(.white)
                                                .fontWeight(.semibold)

                                            Text("Uploaded")
                                                .foregroundColor(.white.opacity(0.7))
                                                .font(.caption)

                                            Text(meal.nutrition_info.components(separatedBy: "\n").first ?? "Nutrition Info")
                                                .foregroundColor(.orange)
                                                .font(.caption2)
                                        }

                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(14)
                                    .frame(width: 320)
                                }
                            }
                        }
                        .padding(.top)
                    }

                    Spacer()
                }
                .padding(.top, 30)
            }
            .navigationTitle("Meal History")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
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
                    self.meals = decoded
                }
            } else {
                print("❌ Meal decoding failed")
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
