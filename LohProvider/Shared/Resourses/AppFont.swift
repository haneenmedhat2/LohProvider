//
//  AppFont.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 30/07/2025.
//


import SwiftUI

enum AppFont {
    static func black(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static func bold(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func semiBold(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func medium(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func regular(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }

    static func light(size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded)
    }
}
