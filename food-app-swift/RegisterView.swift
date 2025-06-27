import SwiftUI
import AuthenticationServices

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session = SessionManager.shared

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
    @State private var registrationFailed = false
    @State private var navigateToProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.45))
                    .blur(radius: 4)

                VStack(spacing: 28) {
                    Text("Create Your Account")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Group {
                        validatedTextField("Full Name", text: $name, error: $nameError, validate: validateName)
                        validatedTextField("Email", text: $email, error: $emailError, validate: validateEmail, keyboard: .emailAddress)
                        validatedSecureField("Password", text: $password, isSecure: $isSecure, error: $passwordError, validate: validatePassword)
                        validatedSecureField("Confirm Password", text: $confirmPassword, isSecure: $isConfirmSecure, error: $confirmPasswordError, validate: validateConfirmPassword)
                    }

                    Button("Register") {
                        validateAll()
                        if allValid() {
                            attemptRegister()
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 280)
                    .background(Color.orange)
                    .cornerRadius(14)

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
                .padding(.top, 40)
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Components

    func validatedTextField(_ title: String, text: Binding<String>, error: Binding<String>, validate: @escaping () -> Void, keyboard: UIKeyboardType = .default) -> some View {
        VStack(spacing: 4) {
            TextField(title, text: text)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .padding()
                .background(Color.white.opacity(0.28))
                .cornerRadius(14)
                .foregroundColor(.white)
                .frame(width: 280)
                .onChange(of: text.wrappedValue, initial: false) { _, _ in validate() }

            if !error.wrappedValue.isEmpty {
                Text(error.wrappedValue)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    func validatedSecureField(_ title: String, text: Binding<String>, isSecure: Binding<Bool>, error: Binding<String>, validate: @escaping () -> Void) -> some View {
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
            .frame(width: 280)
            .onChange(of: text.wrappedValue, initial: false) { _, _ in validate() }

            if !error.wrappedValue.isEmpty {
                Text(error.wrappedValue)
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(width: 280, alignment: .leading)
            }
        }
    }

    // MARK: - Validation

    func validateName() {
        nameError = name.isEmpty ? "Name is required" : ""
    }

    func validateEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        emailError = trimmed.isEmpty ? "Email is required" :
            (!trimmed.contains("@") || !trimmed.contains(".")) ? "Enter a valid email" : ""
    }

    func validatePassword() {
        passwordError = password.count < 6 ? "Password must be at least 6 characters" : ""
    }

    func validateConfirmPassword() {
        confirmPasswordError = confirmPassword != password ? "Passwords do not match" : ""
    }

    func validateAll() {
        validateName()
        validateEmail()
        validatePassword()
        validateConfirmPassword()
    }

    func allValid() -> Bool {
        nameError.isEmpty && emailError.isEmpty && passwordError.isEmpty && confirmPasswordError.isEmpty
    }

    // MARK: - API Call

    func attemptRegister() {
        guard let url = URL(string: "https://food-app-swift.onrender.com/register") else { return }

        let payload = ["name": name, "email": email, "password": password]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(RegisterResponse.self, from: data) else {
                DispatchQueue.main.async { registrationFailed = true }
                return
            }

            DispatchQueue.main.async {
                session.login(id: response.user_id, name: response.name)
                navigateToProfile = true
            }
        }.resume()
    }
}
