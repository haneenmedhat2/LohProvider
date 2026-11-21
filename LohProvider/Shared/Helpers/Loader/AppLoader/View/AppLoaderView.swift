//
//  AppLoaderView.swift
//  CTF
//
//  Created by Mohamed Hadwa on 23/11/2025.
//


import SwiftUI

struct AppLoaderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let asset: LoaderAsset
    var size: CGFloat = 112
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.33)
                .ignoresSafeArea()
            
            Group {
                switch asset {
                case .gif(let name):
                    GIFView(name: name)
                case .lottie(let name):
                    LottieView(fileName: name, autoplay: !reduceMotion)
                        .id(reduceMotion)
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(merchantString("api_loading", arabic: AppLanguageManager.shared.isRTL)))
    }
}
