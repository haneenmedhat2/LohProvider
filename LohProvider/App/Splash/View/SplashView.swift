import SwiftUI

struct MerchantSplashView: View {
    let onFinished: () -> Void
    
    var body: some View {
        ZStack {
            Image("SplashBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            LottieView(fileName: "Comp-1-2", loopMode: .loop)
                .frame(width: 240, height: 100)
        }
        .accessibilityIdentifier("merchantSplash")
        .task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}
