//
//  LoginResponse.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/25/25.
//


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
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.45))
                    .blur(radius: 4)
                    .ignoresSafeArea()

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
                                .onChange(of: email, initial: false) { _, _ in validateEmail() }

                            if !emailError.isEmpty {
                                Text(emailError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

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
                            .onChange(of: password, initial: false) { _, _ in validatePassword() }

                            if !passwordError.isEmpty {
                                Text(passwordError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        Toggle(isOn: $rememberMe) {
                            Text("Remember Me")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .frame(width: 280, alignment: .leading)

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

                        HStack {
                            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.4))
                            Text("OR").foregroundColor(.gray.opacity(0.7)).padding(.horizontal, 6)
                            Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.4))
                        }
                        .frame(width: 260)

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

                        NavigationLink("", destination: ProfileSetupView(), isActive: $navigate).hidden()
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

    private func attemptLogin() {
        guard let url = URL(string: "https://your-api.onrender.com/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(LoginResponse.self, from: data) else {
                DispatchQueue.main.async { loginFailed = true }
                return
            }

            DispatchQueue.main.async {
                UserDefaults.standard.set(response.user_id, forKey: "user_id")
                UserDefaults.standard.set(response.name, forKey: "user_name")
                navigate = true
            }
        }.resume()
    }
}
