import SwiftUI

struct MerchantReportsView: View {
    @EnvironmentObject private var store: MerchantReportsViewModel
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @Environment(\.locale) private var locale
    @State private var reloadID = UUID()
    @State private var isPullRefreshing = false
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    var body: some View {
        let report = store.snapshot
        ScrollView {
            VStack(spacing: 16) {
                Text(text("tab_reports")).merchantFont(24, .extraBold).foregroundStyle(MerchantTheme.heading).frame(maxWidth: .infinity, alignment: .leading)
                MerchantReportPeriodButton()
                if store.isPreview {
                    previewContent(report)
                } else {
                    if store.isLoading {
                        ProgressView(text("report_loading"))
                            .tint(MerchantTheme.brand).padding(24)
                            .accessibilityIdentifier("merchantReportsLoading")
                    }
                    if let error = store.error {
                        MerchantFieldError(message: error.message(localize: text))
                        MerchantButton(title: text("api_retry"), secondary: true, isLoading: store.isLoading) { reloadID = UUID() }
                    }
                    if let report = store.summary {
                        MerchantReportSummaryContent(overview: .init(report: report)).id(store.requestID)
                        HStack(spacing: 10) {
                            action("report_detailed_report", icon: "Detail", secondary: true) { stack.push(.reportDetails) }
                            action("report_download_pdf", icon: "Download") { coordinator.sheet = .reportExport }
                        }.environment(\.layoutDirection, .leftToRight)
                        Text(text("report_top_offers")).merchantFont(18, .bold).foregroundStyle(MerchantTheme.heading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if report.topOffers.offers.isEmpty {
                            MerchantCard {
                                Text(text("report_no_top_offers")).merchantFont(14).foregroundStyle(MerchantTheme.muted)
                                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                            }
                        } else {
                            ForEach(report.topOffers.offers) { offer in
                                MerchantReportTopOfferRow(offer: offer)
                            }
                        }
                    }
                }
            }.padding(16)
                .padding(.bottom, 80)
        }.modifier(MerchantReportNavigation())
            .task(id: store.requestID + locale.identifier + reloadID.uuidString) { await store.reload() }
            .refreshable {
                isPullRefreshing = true
                Task { @MainActor in
                    await store.refresh()
                    isPullRefreshing = false
                }
            }
            .overlay(alignment: .top) {
                if isPullRefreshing {
                    ProgressView()
                        .tint(MerchantTheme.brand)
                        .padding(10)
                        .background(MerchantTheme.surface, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                        .padding(.top, 8)
                        .accessibilityIdentifier("merchantReportsPullRefreshLoading")
                }
            }
            .onDisappear { store.cancelRefresh() }
    }
    @ViewBuilder private func previewContent(_ report: MerchantReportSnapshot) -> some View {
                MerchantReportSummaryContent(overview: .init(snapshot: report,
                    currency: text("settlement_currency"), comparison: text("report_previous_period"), arabic: arabic))
                    .id(store.requestID)
                HStack(spacing: 10) {
                    action("report_detailed_report", icon: "Detail", secondary: true) { stack.push(.reportDetails) }
                    action("report_download_pdf", icon: "Download") { coordinator.sheet = .reportExport }
                }.environment(\.layoutDirection, .leftToRight)
                Text(text("report_top_offers")).merchantFont(18, .bold).foregroundStyle(MerchantTheme.heading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<3) { index in
                    MerchantCard(padding: 12, radius: 14) {
                        HStack(spacing: 12) {
                            MerchantReportOfferArtwork(index: index)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(text("report_offer_\(index)")).merchantFont(14, .bold).foregroundStyle(MerchantTheme.heading)
                                MerchantStatusBadge(title: text("report_active"))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(MerchantReportFormat.money(report.offerSales[index], arabic: arabic) + " " + text("settlement_currency")).merchantFont(14, .semibold).foregroundStyle(MerchantTheme.heading)
                                Text(text("report_sales")).merchantFont(10).foregroundStyle(MerchantTheme.muted)
                            }
                        }
                    }
                }
    }
    private func action(_ key: String, icon: String, secondary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                MerchantReportIcon(name: icon, size: 16)
                Text(text(key)).merchantFont(12, .bold).multilineTextAlignment(.center)
            }.environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
                .foregroundStyle(secondary ? MerchantTheme.body : MerchantTheme.ink)
                .frame(maxWidth: .infinity).frame(minHeight: 52)
                .background(secondary ? .white : MerchantTheme.brand).clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(secondary ? MerchantTheme.border : .clear))
        }.buttonStyle(.plain)
    }
}
