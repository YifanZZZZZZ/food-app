import Foundation

/// Response structure for successful registration from the backend.
struct RegisterResponse: Codable {
    let user_id: String
    let name: String
    let token: String  // JWT token for authentication
}
