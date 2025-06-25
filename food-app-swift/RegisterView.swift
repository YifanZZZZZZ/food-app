import SwiftUI
import AuthenticationServices

struct RegisterResponse: Codable {
    let user_id: String
    let name: String
}

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

    @State private var navigateToProfile = false
    @State private var registrationFailed = false

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

                    Text("Create Your Account")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    VStack(spacing: 20) {
                        textFieldWithValidation("Full Name", text: $name, error: $nameError, validation: validateName)
                        textFieldWithValidation("Email", text: $email, error: $emailError, validation: validateEmail, keyboardType: .emailAddress)

                        secureFieldWithToggle("Password", text: $password, isSecure: $isSecure, error: $passwordError, validation: validatePassword)
                        secureFieldWithToggle("Confirm Password", text: $confirmPassword, isSecure: $isConfirmSecure, error: $confirmPasswordError, validation: validateConfirmPassword)

                        Button(action: {
                            validateAllFields()
                            if allFieldsValid() {
                                attemptRegister()
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

                        if registrationFailed {
                            Text("Registration failed. Try again.")
                                .foregroundColor(.red)
                        }

                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(.white.opacity(0.75))
                            Button(action: { dismiss() }) {
                                Text("Login")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.footnote)

                        NavigationLink("", destination: ProfileSetupView(), isActive: $navigateToProfile).hidden()
                    }

                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Validation & Helpers

    private func textFieldWithValidation(_ title: String, text: Binding<String>, error: Binding<String>, validation: @escaping () -> Void, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(spacing: 4) {
            TextField(title, text: text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .padding()
                .background(Color.white.opacity(0.28))
                .cornerRadius(14)
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 280)
                .onChange(of: text.wrappedValue, initial: false) { _, _ in validation() }

            if !error.wrappedValue.isEmpty {
                Text(error.wrappedValue)
                    .foregroundColor(.red)
                    .font(.system(size: 13))
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    private func secureFieldWithToggle(_ title: String, text: Binding<String>, isSecure: Binding<Bool>, error: Binding<String>, validation: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            HStack {
                if isSecure.wrappedValue {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                }
                Button(action: { isSecure.wrappedValue.toggle() }) {
                    Image(systemName: isSecure.wrappedValue ? "eye.slash" : "eye")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding()
            .background(Color.white.opacity(0.28))
            .cornerRadius(14)
            .foregroundColor(.white)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 280)
            .onChange(of: text.wrappedValue, initial: false) { _, _ in validation() }

            if !error.wrappedValue.isEmpty {
                Text(error.wrappedValue)
                    .foregroundColor(.red)
                    .font(.system(size: 13))
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    private func validateName() {
        nameError = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required" : ""
    }

    private func validateEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        emailError = trimmed.isEmpty ? "Email is required" :
            (!trimmed.contains("@") || !trimmed.contains(".")) ? "Enter a valid email" : ""
    }

    private func validatePassword() {
        passwordError = password.count < 6 ? "Password must be at least 6 characters" : ""
    }

    private func validateConfirmPassword() {
        confirmPasswordError = confirmPassword != password ? "Passwords do not match" : ""
    }

    private func validateAllFields() {
        validateName()
        validateEmail()
        validatePassword()
        validateConfirmPassword()
    }

    private func allFieldsValid() -> Bool {
        return nameError.isEmpty && emailError.isEmpty && passwordError.isEmpty && confirmPasswordError.isEmpty
    }

    private func attemptRegister() {
        guard let url = URL(string: "https://food-app-swift.onrender.com/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["name": name, "email": email, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(RegisterResponse.self, from: data) else {
                DispatchQueue.main.async { registrationFailed = true }
                return
            }

            DispatchQueue.main.async {
                SessionManager.shared.login(id: response.user_id, name: response.name)
                navigateToProfile = true
            }
        }.resume()
    }
}
