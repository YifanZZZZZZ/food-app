import Foundation
import Combine
import SwiftUI

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var isLoggedIn: Bool = false
    @Published var userID: String = ""
    @Published var userName: String = ""
    @Published var shouldNavigateToLogin: Bool = false

    private init() {
        if let id = UserDefaults.standard.string(forKey: "user_id"),
           let name = UserDefaults.standard.string(forKey: "user_name") {
            userID = id
            userName = name
            isLoggedIn = true
        }
    }

    func login(id: String, name: String) {
        userID = id
        userName = name
        isLoggedIn = true

        UserDefaults.standard.set(id, forKey: "user_id")
        UserDefaults.standard.set(name, forKey: "user_name")
    }

    func logout() {
        userID = ""
        userName = ""
        isLoggedIn = false
        shouldNavigateToLogin = true

        // Clear all user data
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
        UserDefaults.standard.removeObject(forKey: "calorie_target")
        
        // Clear any other user-specific data
        clearUserCache()
    }
    
    private func clearUserCache() {
        // Clear any cached meal data, images, etc.
        // This is where you'd clear any local storage if you implement it
    }
    
    func resetNavigationFlag() {
        shouldNavigateToLogin = false
    }
}
