import SwiftUI
import Kingfisher

struct MerchantReportTopOfferRow: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let offer: MerchantReportTopOffer

    var body: some View {
        MerchantCard(padding: 12, radius: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    identity
                    sales
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    identity
                    sales
                }
            }
        }
    }

    private var identity: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 5) {
                Text(offer.name).merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
                    .fixedSize(horizontal: false, vertical: true)
                MerchantStatusBadge(title: offer.statusText.isEmpty ? offer.status : offer.statusText,
                               kind: offer.status == "active" ? .success : .neutral)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sales: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(MerchantReportOverview.number(offer.salesTotal) + " " + offer.currency)
                .merchantFont(14, .semibold).foregroundStyle(MerchantTheme.heading)
                .fixedSize(horizontal: false, vertical: true)
            Text(merchantString("report_sales", locale: locale)).merchantFont(10).foregroundStyle(MerchantTheme.muted)
            Text(merchantString("report_sales_count", locale: locale) + ": " + offer.salesCount.formatted(.number.locale(locale)))
                .merchantFont(10).foregroundStyle(MerchantTheme.muted)
        }
    }

    private var artwork: some View {
        Group {
            if let image = offer.image {
                KFImage(image)
                    .placeholder { placeholder }
                    .cancelOnDisappear(true).loadDiskFileSynchronously()
                    .resizable().scaledToFill()
            } else {
                placeholder
            }
        }.frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: "tag").resizable().scaledToFit().padding(16)
            .foregroundStyle(MerchantTheme.muted).frame(width: 52, height: 52).background(MerchantTheme.brandTint)
    }
}
