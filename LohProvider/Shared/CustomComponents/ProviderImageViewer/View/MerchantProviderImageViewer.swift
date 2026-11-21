import SwiftUI
import Kingfisher

struct MerchantProviderImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let url: URL?
    let name: String?
    @State private var scale: CGFloat = 1
    @GestureState private var magnification: CGFloat = 1
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private var remoteURL: URL? {
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                KFImage(remoteURL)
                    .placeholder {
                        VStack(spacing: 16) {
                            Image(systemName: "storefront.fill").font(.system(size: 72))
                            Text(merchantString("profile_image_unavailable", arabic: arabic)).merchantFont(15)
                        }.foregroundStyle(.white.opacity(0.75))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .cancelOnDisappear(true)
                    .loadDiskFileSynchronously()
                    .resizable().scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(min(4, max(1, scale * magnification)))
                    .gesture(MagnificationGesture().updating($magnification) { value, state, _ in state = value }
                        .onEnded { scale = min(4, max(1, scale * $0)) })
                    .onTapGesture(count: 2) { withAnimation { scale = scale > 1 ? 1 : 2 } }
                    .clipped()
            }
            .background(.black)
            .navigationTitle(name ?? merchantString("profile_view_image", arabic: arabic))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark").foregroundStyle(.white) }
                        .accessibilityLabel(merchantString("nav_close", arabic: arabic))
                        .accessibilityIdentifier("closeMerchantProfileImage")
                }
            }
        }.accessibilityIdentifier("merchantProfileImageViewer")
    }
}
