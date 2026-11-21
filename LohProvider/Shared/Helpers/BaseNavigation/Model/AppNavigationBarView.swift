//
//  AppNavigationBarView.swift
//  CTF
//
//  Created by Mohamed Hadwa on 19/11/2025.
//

import SwiftUI

extension View {
    func appNavigationBar(_ title: String) -> some View {
        self.modifier(AppNavigationBarModifier(title: title))
    }
}
