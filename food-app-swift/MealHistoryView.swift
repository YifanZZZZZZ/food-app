//
//  MealHistoryView.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/20/25.
//

import SwiftUI

struct MealHistoryView: View {
    @State private var selectedTab = "Today"
    let tabs = ["Today", "Week", "Month"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Tabs
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(tabs, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .background(Color.white.opacity(0.05))

                    // Meals
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(1..<6) { i in
                                NavigationLink(destination: MealDetailView()) {
                                    HStack(spacing: 12) {
                                        Rectangle()
                                            .fill(Color.orange.opacity(0.8))
                                            .frame(width: 70, height: 70)
                                            .cornerRadius(10)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Meal \(i)")
                                                .foregroundColor(.white)
                                                .fontWeight(.semibold)

                                            Text("Apr 24 • 1:00 PM")
                                                .foregroundColor(.white.opacity(0.7))
                                                .font(.caption)

                                            Text("📊 520 kcal • 4 ingredients")
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
        }
    }
}
