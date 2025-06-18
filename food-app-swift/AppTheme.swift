//
//  AppTheme.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 6/17/25.
//

// AppTheme.swift
import SwiftUI

enum AppTheme: String, CaseIterable {
    case light, dark

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}
