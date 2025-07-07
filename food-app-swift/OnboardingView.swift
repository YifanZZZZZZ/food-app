import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var navigateToLogin = false
    
    let features = [
        OnboardingFeature(
            icon: "camera.fill",
            title: "Snap Your Meals",
            description: "Take a photo and instantly identify ingredients and nutrition",
            color: .orange
        ),
        OnboardingFeature(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Progress",
            description: "Monitor your daily calories and nutritional intake",
            color: .green
        ),
        OnboardingFeature(
            icon: "sparkles",
            title: "AI-Powered Analysis",
            description: "Get detailed insights about hidden ingredients and nutrition",
            color: .purple
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.black.opacity(0.95),
                        Color(red: 0.1, green: 0.1, blue: 0.15)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Animated background elements
                GeometryReader { geometry in
                    ForEach(0..<15) { index in
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: CGFloat.random(in: 20...80))
                            .position(
                                x: CGFloat.random(in: 0...geometry.size.width),
                                y: CGFloat.random(in: 0...geometry.size.height)
                            )
                            .blur(radius: 10)
                            .animation(
                                Animation.easeInOut(duration: Double.random(in: 10...20))
                                    .repeatForever(autoreverses: true),
                                value: currentPage
                            )
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        Button("Skip") {
                            navigateToLogin = true
                        }
                        .foregroundColor(.gray)
                        .padding()
                    }

                    Spacer()

                    // Logo
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .orange.opacity(0.3), radius: 20)
                        .scaleEffect(currentPage == 0 ? 1.0 : 0.8)
                        .animation(.spring(), value: currentPage)

                    Text("NutriSnap")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    // Page content
                    TabView(selection: $currentPage) {
                        ForEach(0..<features.count, id: \.self) { index in
                            OnboardingPage(feature: features[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 300)

                    // Page indicator
                    HStack(spacing: 12) {
                        ForEach(0..<features.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? Color.orange : Color.white.opacity(0.3))
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    .padding(.vertical, 30)

                    // CTA Button
                    Button(action: {
                        if currentPage < features.count - 1 {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            navigateToLogin = true
                        }
                    }) {
                        HStack {
                            Text(currentPage < features.count - 1 ? "Next" : "Get Started")
                                .fontWeight(.semibold)
                            
                            Image(systemName: currentPage < features.count - 1 ? "arrow.right" : "arrow.right.circle.fill")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.orange, .orange.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
            .preferredColorScheme(.dark)
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct OnboardingFeature {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPage: View {
    let feature: OnboardingFeature
    
    var body: some View {
        VStack(spacing: 24) {
            // Feature icon
            ZStack {
                Circle()
                    .fill(feature.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 50))
                    .foregroundColor(feature.color)
            }
            
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(feature.description)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.vertical, 20)
    }
}
