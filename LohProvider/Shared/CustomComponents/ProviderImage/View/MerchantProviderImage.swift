import SwiftUI
import Kingfisher

/// Kingfisher shares its memory/disk image cache across every merchant screen.
struct MerchantProviderImage: View {
    let url: URL?
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 12

    private var remoteURL: URL? {
        guard let url, ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false else { return nil }
        return url
    }

    var body: some View {
        KFImage(remoteURL)
            .placeholder {
                ZStack {
                    MerchantTheme.brandTint
                    Image(systemName: "storefront.fill")
                        .font(.system(size: size * 0.44, weight: .medium))
                        .foregroundStyle(MerchantTheme.brand)
                }.frame(width: size, height: size)
            }
            .cancelOnDisappear(true)
            .loadDiskFileSynchronously()
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}
