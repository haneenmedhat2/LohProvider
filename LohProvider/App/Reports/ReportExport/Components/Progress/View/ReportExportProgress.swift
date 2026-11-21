import SwiftUI

struct MerchantReportExportProgress: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var moving = false

    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(MerchantTheme.subtle)
                .overlay(alignment: .leading) {
                    Capsule().fill(MerchantTheme.brand).frame(width: geometry.size.width * 0.68)
                        .offset(x: moving ? geometry.size.width * 0.32 : 0)
                }.clipped()
        }.frame(height: 6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { moving = true }
            }
            .accessibilityElement().accessibilityLabel(merchantString("report_preparing", locale: locale))
    }
}
