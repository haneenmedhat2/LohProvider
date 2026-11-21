//
//  CardContainer.swift
//  CTF
//
//  Created by Mohamed Hadwa on 22/12/2025.
//


import SwiftUI

struct CardContainer<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: Content
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white)
            )
    }
}
