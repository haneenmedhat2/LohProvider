//
//  PrimaryGradientButtonStyle.swift
//  CTF
//
//  Created by Mohamed Hadwa on 23/11/2025.
//

import SwiftUI

// MARK: - Styles & helpers

private struct PrimaryGradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [Color.gradientGreenLight, Color.gradientGreenDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension Color {
    static let primaryText = Color.black
    static let secondaryText = Color.black.opacity(0.6)
}

