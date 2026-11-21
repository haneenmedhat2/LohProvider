import SwiftUI

struct MerchantReportDetailView: View {
    @EnvironmentObject private var store: MerchantReportsViewModel
    @EnvironmentObject private var coordinator: MerchantTabsCoordinator
    @Environment(\.locale) private var locale
    @State private var reloadID = UUID()

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    MerchantReportPeriodButton(periodLabel: store.detail?.periodLabel)
                    if store.isPreview {
                        content(.init(snapshot: store.snapshot, currency: text("settlement_currency"),
                                      note: text("report_completed_only"), arabic: arabic), width: geometry.size.width - 32)
                    } else {
                        if store.isLoadingDetails {
                            ProgressView(text("report_loading"))
                                .tint(MerchantTheme.brand).padding(24)
                                .accessibilityIdentifier("merchantReportDetailsLoading")
                        }
                        if let error = store.detailError {
                            MerchantFieldError(message: error.message(localize: text))
                            MerchantButton(title: text("api_retry"), secondary: true, isLoading: store.isLoadingDetails) { reloadID = UUID() }
                        }
                        if let report = store.detail {
                            content(.init(report: report), width: geometry.size.width - 32)
                        }
                    }
                }.padding(.horizontal, 16).padding(.top, 8)
            }.refreshable { await store.refreshDetails() }
        }.modifier(MerchantReportNavigation(detail: true))
            .task(id: store.requestID + locale.identifier + reloadID.uuidString) { await store.reloadDetails() }
            .onDisappear { store.cancelRefresh(detail: true) }
    }

    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }
    private func content(_ report: MerchantReportDetailPresentation, width: CGFloat) -> some View {
        MerchantReportDetailContent(report: report, width: width) { coordinator.sheet = .reportExport }
    }
}
