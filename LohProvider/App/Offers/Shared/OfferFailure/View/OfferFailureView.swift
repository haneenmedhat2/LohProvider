import SwiftUI
import Kingfisher

struct MerchantOfferFailureView: View {
    @Environment(\.locale) private var locale
    let error: APIError
    let retry: () async -> Void
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    var body: some View {
        VStack(spacing: 12) {
            Text(error.message { merchantString($0, arabic: arabic) })
                .merchantFont(14).foregroundStyle(MerchantTheme.error).multilineTextAlignment(.center)
            Button(merchantString("api_retry", arabic: arabic)) { Task { await retry() } }
                .merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
        }.padding(16).frame(maxWidth: .infinity)
    }
}
