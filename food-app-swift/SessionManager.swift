//
//  SessionManager.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/25/25.
//

import Foundation

class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var userID: String = UserDefaults.standard.string(forKey: "user_id") ?? ""
    @Published var userName: String = UserDefaults.standard.string(forKey: "user_name") ?? ""

    var isLoggedIn: Bool {
        !userID.isEmpty
    }

    func login(id: String, name: String) {
        userID = id
        userName = name
        UserDefaults.standard.set(id, forKey: "user_id")
        UserDefaults.standard.set(name, forKey: "user_name")
    }

    func logout() {
        userID = ""
        userName = ""
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
    }
}
