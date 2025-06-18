import SwiftUI
import AuthenticationServices


struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSecure = true

    @State private var emailError = ""
    @State private var passwordError = ""

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
                    Spacer()

                    VStack(spacing: 24) {
                        Text("Welcome to Snap & Track")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        // Email
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
                                .onChange(of: email) {
                                    validateEmail()
                                }

                            if !emailError.isEmpty {
                                Text(emailError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        // Password
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
                            .onChange(of: password) {
                                validatePassword()
                            }

                            if !passwordError.isEmpty {
                                Text(passwordError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        Button(action: {
                            validateEmail()
                            validatePassword()
                        }) {
                            Text("Login")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 280)
                                .background(Color.orange)
                                .cornerRadius(14)
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

                            Button(action: {}) {
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
                    }

                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
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
}
