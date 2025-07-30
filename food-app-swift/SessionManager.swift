import Foundation
import Combine
import SwiftUI

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var isLoggedIn: Bool = false
    @Published var userID: String = ""
    @Published var userName: String = ""
    @Published var authToken: String = ""
    @Published var shouldNavigateToLogin: Bool = false

    private init() {
        // Check for existing session
        if let token = UserDefaults.standard.string(forKey: "auth_token"),
           let id = UserDefaults.standard.string(forKey: "user_id"),
           let name = UserDefaults.standard.string(forKey: "user_name"),
           !token.isEmpty {
            // Verify token is still valid (basic check)
            authToken = token
            userID = id
            userName = name
            isLoggedIn = true
            
            // Update NetworkManager with token
            NetworkManager.shared.saveToken(token)
        }
    }

    func login(id: String, name: String, token: String) {
        userID = id
        userName = name
        authToken = token
        isLoggedIn = true

        // Save to UserDefaults
        UserDefaults.standard.set(id, forKey: "user_id")
        UserDefaults.standard.set(name, forKey: "user_name")
        UserDefaults.standard.set(token, forKey: "auth_token")
        
        // Update NetworkManager with token
        NetworkManager.shared.saveToken(token)
    }

    func logout() {
        userID = ""
        userName = ""
        authToken = ""
        isLoggedIn = false
        shouldNavigateToLogin = true

        // Clear all user data
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "calorie_target")
        
        // Clear NetworkManager token
        NetworkManager.shared.logout()
        
        // Clear any other user-specific data
        clearUserCache()
    }
    
    private func clearUserCache() {
        // Clear any cached meal data, images, etc.
        // Clear ProfileManager data
        ProfileManager.shared.clearProfile()
        
        // Clear any other cached data
        UserDefaults.standard.synchronize()
    }
    
    func resetNavigationFlag() {
        shouldNavigateToLogin = false
    }
    
    // Check if token is likely expired (basic check)
    func isTokenValid() -> Bool {
        return !authToken.isEmpty && isLoggedIn
    }
    
    // Handle authentication errors
    func handleAuthenticationError() {
        // Called when API returns 401
        logout()
    }
}
