import SwiftUI

struct DashboardView: View {
    @State private var showUpload = false
    @State private var showSummary = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Greeting
                        VStack(alignment: .leading, spacing: 6) {
                            Text("👋 Welcome Back!")
                                .font(.title2)
                                .foregroundColor(.white)

                            Text("Here’s your nutrition overview for today")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.footnote)
                        }
                        .padding(.horizontal)
                        .padding(.top, 40)

                        // Logged Meals (horizontal)
                        VStack(alignment: .leading) {
                            Text("Today's Meals")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(1..<4) { i in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Rectangle()
                                                .fill(Color.orange.opacity(0.9))
                                                .frame(width: 140, height: 90)
                                                .cornerRadius(12)

                                            Text("Meal \(i)")
                                                .foregroundColor(.white)

                                            Text("350 kcal")
                                                .foregroundColor(.white.opacity(0.7))
                                                .font(.caption2)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Progress Bars
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Daily Nutrients")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(["Calories", "Protein", "Carbs", "Fat"], id: \.self) { nutrient in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nutrient)
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.caption)

                                    ProgressView(value: 0.5)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                        .frame(height: 8)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Suggestions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .foregroundColor(.white)
                                .font(.headline)
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Add breakfast for a better start", systemImage: "sunrise.fill")
                                    .foregroundColor(.white.opacity(0.8))

                                Label("Low protein so far", systemImage: "bolt.fill")
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 100)
                    }
                }

                // FAB Buttons
                VStack(spacing: 14) {
                    NavigationLink(destination: UploadMealView()) {
                        Label("Upload Meal", systemImage: "plus")
                            .padding()
                            .frame(width: 160)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    NavigationLink(destination: MealHistoryView()) {
                        Label("View Summary", systemImage: "chart.bar")
                            .padding()
                            .frame(width: 160)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .preferredColorScheme(.dark)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
