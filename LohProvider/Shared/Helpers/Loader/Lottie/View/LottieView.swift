//
//  LottieView.swift
//  CTF
//
//  Created by Mohamed Hadwa on 23/11/2025.
//


import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    let fileName: String
    var loopMode: LottieLoopMode = .loop
    var autoplay = true

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let animationView = LottieAnimationView(name: fileName)
        animationView.loopMode = loopMode
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        if autoplay {
            animationView.play()
        } else {
            animationView.currentProgress = 0.5
        }
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) { }
}
