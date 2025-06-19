import SwiftUI

struct OnboardingView: View {
    @FocusState private var isEmailFocused: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var isSecure = true
    @State private var rememberMe = false
    @State private var emailError = ""
    @State private var passwordError = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Image
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .ignoresSafeArea()

                // Gradient overlay for contrast
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.2)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                .ignoresSafeArea()

                VStack {
                    Spacer(minLength: 80)

                    // Subtle Tagline
                    Text("Your AI Nutrition Assistant")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.bottom, 6)

                    // Centered App Name
                    Text("Snap & Track")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 30)

                    // Title & Subtitle
                    VStack(spacing: 12) {
                        Text("Discover fresh meals, fast tracking")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Text("Snap a photo of your food, detect ingredients and track your nutrition in seconds.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Spacer()

                    // CTA Button with Haptic Feedback
                    NavigationLink(destination: LoginView()) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 300, height: 52)
                            .background(Color.orange)
                            .cornerRadius(26)
                            .shadow(radius: 6)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    })
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.dark)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
