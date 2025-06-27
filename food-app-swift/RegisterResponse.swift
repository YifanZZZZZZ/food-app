import SwiftUI

struct RegisterResponse: Codable {
    let user_id: String
    let name: String
}

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session = SessionManager.shared

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var registrationFailed = false
    @State private var navigateToProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Create Account")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)

                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Register") {
                        attemptRegister()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    if registrationFailed {
                        Text("Registration failed. Try again.")
                            .foregroundColor(.red)
                    }

                    NavigationLink("", destination: ProfileSetupView(), isActive: $navigateToProfile).hidden()
                }
                .padding()
            }
        }
    }

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
