//
//  AppNavigationBarModifier.swift
//  CTF
//
//  Created by Mohamed Hadwa on 19/11/2025.
//

import SwiftUI

struct AppNavigationBarModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(AppFont.bold(size: 18))
                }
            }
    }
}
