import SwiftUI

import Foundation

/// Response structure for successful registration from the backend.
struct RegisterResponse: Codable {
    let user_id: String
    let name: String
    let token: String  // Add this line
}
