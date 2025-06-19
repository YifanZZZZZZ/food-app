import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSecure = true
    @State private var isConfirmSecure = true

    @State private var nameError = ""
    @State private var emailError = ""
    @State private var passwordError = ""
    @State private var confirmPasswordError = ""

    @State private var showSuccess = false
    @State private var showError = false

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

                    // Subtle Tagline
                    Text("Your AI Nutrition Assistant")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.bottom, 6)

                    // App Name
                    Text("Snap & Track")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.bottom, 30)

                    VStack(spacing: 24) {
                        Text("Create your account")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        // Name
                        VStack(spacing: 4) {
                            TextField("Full Name", text: $name)
                                .autocapitalization(.words)
                                .padding()
                                .background(Color.white.opacity(0.28))
                                .cornerRadius(14)
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 280)
                                .onChange(of: name) { _ in validateName() }

                            if !nameError.isEmpty {
                                Text(nameError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

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
                                .onChange(of: email) { _ in validateEmail() }

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
                            .onChange(of: password) { _ in validatePassword() }

                            if !passwordError.isEmpty {
                                Text(passwordError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        // Confirm Password
                        VStack(spacing: 4) {
                            HStack {
                                if isConfirmSecure {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                } else {
                                    TextField("Confirm Password", text: $confirmPassword)
                                }
                                Button(action: { isConfirmSecure.toggle() }) {
                                    Image(systemName: isConfirmSecure ? "eye.slash" : "eye")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.28))
                            .cornerRadius(14)
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 280)
                            .onChange(of: confirmPassword) { _ in validateConfirmPassword() }

                            if !confirmPasswordError.isEmpty {
                                Text(confirmPasswordError)
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .frame(width: 280, alignment: .leading)
                            }
                        }

                        // Register Button
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            validateName()
                            validateEmail()
                            validatePassword()
                            validateConfirmPassword()

                            if nameError.isEmpty && emailError.isEmpty && passwordError.isEmpty && confirmPasswordError.isEmpty {
                                withAnimation {
                                    showSuccess = true
                                }
                            } else {
                                withAnimation {
                                    showError = true
                                }
                            }
                        }) {
                            Text("Register")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding()
                                .frame(width: 280)
                                .background(Color.orange)
                                .cornerRadius(14)
                        }
                        .alert("Registration Successful!", isPresented: $showSuccess, actions: {
                            Button("Go to Login") { dismiss() }
                        })
                        .alert("Please correct the errors", isPresented: $showError, actions: {
                            Button("OK", role: .cancel) { }
                        })

                        // Already have account
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.white.opacity(0.75))
                            Button(action: {
                                withAnimation {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    dismiss()
                                }
                            }) {
                                Text("Login")
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
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    // Validation
    private func validateName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        nameError = trimmed.isEmpty ? "Name is required" : ""
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

    private func validateConfirmPassword() {
        let trimmed = confirmPassword.trimmingCharacters(in: .whitespaces)
        confirmPasswordError = trimmed.isEmpty ? "Please confirm your password" :
                                 (trimmed != password ? "Passwords do not match" : "")
    }
}

#Preview {
    RegisterView()
}
