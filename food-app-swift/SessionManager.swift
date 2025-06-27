import Foundation
import Combine

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var isLoggedIn: Bool = false
    @Published var userID: String = ""
    @Published var userName: String = ""

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

        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
    }
}
