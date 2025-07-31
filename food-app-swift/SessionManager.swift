import Foundation
import SwiftUI

class SessionManager: ObservableObject {
    static let shared = SessionManager()
    
    @Published var isLoggedIn = false
    @Published var userID = ""
    @Published var userName = ""
    @Published var token: String? = nil
    @Published var shouldNavigateToLogin = false
    
    private init() {
        checkLoginStatus()
    }
    
    func login(id: String, name: String, token: String) {
        isLoggedIn = true
        userID = id
        userName = name
        self.token = token
        
        // Persist to UserDefaults
        UserDefaults.standard.set(id, forKey: "user_id")
        UserDefaults.standard.set(name, forKey: "user_name")
        UserDefaults.standard.set(token, forKey: "auth_token")
        UserDefaults.standard.set(true, forKey: "is_logged_in")
        
        print("✅ User logged in: \(name) with ID: \(id)")
        print("🔐 Token stored successfully")
    }
    
    func checkLoginStatus() {
        if let id = UserDefaults.standard.string(forKey: "user_id"),
           let name = UserDefaults.standard.string(forKey: "user_name"),
           let token = UserDefaults.standard.string(forKey: "auth_token"),
           UserDefaults.standard.bool(forKey: "is_logged_in") {
            self.userID = id
            self.userName = name
            self.token = token
            self.isLoggedIn = true
            print("✅ Session restored for user: \(name)")
        } else {
            print("❌ No active session found")
        }
    }
    
    func logout() {
        isLoggedIn = false
        userID = ""
        userName = ""
        token = nil
        shouldNavigateToLogin = true
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        UserDefaults.standard.removeObject(forKey: "is_logged_in")
        
        // Clear profile cache
        UserDefaults.standard.removeObject(forKey: "cached_user_profile")
        UserDefaults.standard.removeObject(forKey: "profile_cache_date")
        UserDefaults.standard.removeObject(forKey: "cached_profile_user_id")
        
        print("👋 User logged out")
    }
    
    func resetNavigationFlag() {
        shouldNavigateToLogin = false
    }
    
    // Helper method to get current auth token
    func getAuthToken() -> String? {
        return token ?? UserDefaults.standard.string(forKey: "auth_token")
    }
}
