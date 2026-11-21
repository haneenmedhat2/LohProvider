//
//  MainAppButton.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 30/07/2025.
//
import SwiftUI

typealias VoidCompletion = () -> Void
extension LinearGradient {
    static var mainVertical: LinearGradient {
        LinearGradient(
            colors: [
                Color("PrimaryMain"),
                Color("SecondaryMain")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}


struct MainAppButton: View {
    let title: String
    let action: VoidCompletion
    
    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(MainButtonStyle())
    }
}
