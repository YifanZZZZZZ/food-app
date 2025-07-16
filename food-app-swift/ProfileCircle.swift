//
//  ProfileCircle.swift
//  food-app-swift
//
//  Created by Utsav Doshi on 7/13/25.
//

import SwiftUI

struct ProfileCircle: View {
    let userName: String
    let size: CGFloat
    var showBorder: Bool = true
    var borderColor: Color = .orange
    var tapAction: (() -> Void)? = nil
    
    init(userName: String, size: CGFloat = 40, showBorder: Bool = true, borderColor: Color = .orange, tapAction: (() -> Void)? = nil) {
        self.userName = userName
        self.size = size
        self.showBorder = showBorder
        self.borderColor = borderColor
        self.tapAction = tapAction
    }
    
    var initials: String {
        let components = userName.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else {
            return String(userName.prefix(2)).uppercased()
        }
    }
    
    var body: some View {
        Button(action: {
            tapAction?()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [borderColor, borderColor.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                if showBorder {
                    Circle()
                        .stroke(borderColor.opacity(0.3), lineWidth: 2)
                        .frame(width: size, height: size)
                }
                
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .disabled(tapAction == nil)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Usage Examples and Previews

struct ProfileCircleExamples: View {
    var body: some View {
        VStack(spacing: 20) {
            // Small circle for navigation bar
            ProfileCircle(userName: "John Doe", size: 32)
            
            // Medium circle for dashboard
            ProfileCircle(userName: "Jane Smith", size: 50, borderColor: .blue)
            
            // Large circle for profile page
            ProfileCircle(userName: "Alex Johnson", size: 80, borderColor: .green)
            
            // Without border
            ProfileCircle(userName: "Sam Wilson", size: 60, showBorder: false)
        }
        .padding()
        .background(Color.black)
    }
}
