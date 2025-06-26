import SwiftUI
import AuthenticationServices

struct LoginResponse: Codable {
    let user_id: String
    let name: String
}

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSecure = true
    @State private var rememberMe = false
    @State private var emailError = ""
    @State private var passwordError = ""
    @State private var loginFailed = false
    @State private var navigate = false

    var body: some View {
        NavigationStack {
            ZStack {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.45))
                    .blur(radius: 4)

                VStack {
                    Spacer(minLength: 80)

                    Text("Your AI Nutrition Assistant")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.bottom, 6)

                    Text("Snap & Track")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 30)

                    VStack(spacing: 24) {
                        Text("Welcome Back")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        // Email field
                        VStack(spacing: 4) {
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white.opacity(0.28))
                                .cornerRadius(14)
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 280)
                                .onChange(of: email) { _, _ in validateEmail() }

                            if !emailError.isEmpty {
                                Text(emailError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        // Password field
                        VStack(spacing: 4) {
                            HStack {
                                if isSecure {
                                    SecureField("Password", text: $password)
                                } else {
                                    TextField("Password", text: $password)
                                }
                                Button(action: { isSecure.toggle() }) {
                                    Image(systemName: isSecure ? "eye.slash" : "eye")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.28))
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 280)
                            .onChange(of: password) { _, _ in validatePassword() }

                            if !passwordError.isEmpty {
                                Text(passwordError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        // Remember Me
                        Toggle(isOn: $rememberMe) {
                            Text("Remember Me")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .frame(width: 280, alignment: .leading)

                        // Login Button
                        Button("Login") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            validateEmail()
                            validatePassword()
                            if emailError.isEmpty && passwordError.isEmpty {
                                attemptLogin()
                            }
                        }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 280)
                        .background(Color.orange)
                        .cornerRadius(14)

                        if loginFailed {
                            Text("Login failed. Please try again.")
                                .foregroundColor(.red)
                        }

                        // Register Link (Restored)
                        HStack(spacing: 4) {
                            Text("New here?")
                                .foregroundColor(.white.opacity(0.75))
                            NavigationLink(destination: RegisterView()) {
                                Text("Register")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.footnote)

                        // OR Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.4))
                            Text("OR").foregroundColor(.gray.opacity(0.7)).padding(.horizontal, 6)
                            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.4))
                        }
                        .frame(width: 260)

                        // Sign in with Apple/Google (Optional UI)
                        VStack(spacing: 12) {
                            SignInWithAppleButton(.signIn, onRequest: { _ in }, onCompletion: { _ in })
                                .frame(width: 280, height: 44)
                                .cornerRadius(10)

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Sign in with Google").fontWeight(.medium)
                                }
                                .frame(width: 280, height: 44)
                                .foregroundColor(.white)
                                .background(Color.red.opacity(0.85))
                                .cornerRadius(10)
                            }
                        }

                        // Navigation
                        NavigationLink(destination: ProfileSetupView(), isActive: $navigate) {
                            EmptyView()
                        }
                        .hidden()
                    }

                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // MARK: - Validation
    private func validateEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        emailError = trimmed.isEmpty ? "Email is required" :
            (!trimmed.contains("@") || !trimmed.contains(".")) ? "Enter a valid email" : ""
    }

    private func validatePassword() {
        let trimmed = password.trimmingCharacters(in: .whitespaces)
        passwordError = trimmed.isEmpty ? "Password is required" :
            (trimmed.count < 6 ? "Password must be at least 6 characters" : "")
    }

    // MARK: - API Call
    private func attemptLogin() {
        guard let url = URL(string: "https://food-app-swift.onrender.com/login") else { return }

        let payload = ["email": email, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        print("Sending login request:", payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let data = data {
                print("Raw login response:", String(data: data, encoding: .utf8) ?? "nil")
            }

            guard let data = data,
                  let response = try? JSONDecoder().decode(LoginResponse.self, from: data) else {
                DispatchQueue.main.async {
                    loginFailed = true
                }
                return
            }

            DispatchQueue.main.async {
                SessionManager.shared.login(id: response.user_id, name: response.name)
                navigate = true
            }
        }.resume()
    }
}
