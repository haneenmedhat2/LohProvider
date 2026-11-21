import SwiftUI

struct MerchantSettlementsView: View {
    @Environment(\.merchantProfile) private var merchantProfile
    @EnvironmentObject private var stack: BaseCoordinator<MerchantRoute>
    @EnvironmentObject private var store: MerchantSettlementsViewModel
    @Environment(\.locale) private var locale
    @State private var reloadID = UUID()
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if store.isLoading {
                    ProgressView(text("settlement_loading")).merchantFont(13).padding(24)
                }
                if let error = store.error {
                    VStack(spacing: 12) {
                        MerchantFieldError(message: error.message(localize: text))
                        MerchantButton(title: text("api_retry"), secondary: true, isLoading: store.isLoading) {
                            reloadID = UUID()
                        }
                    }
                }
                if let page = store.receiptPage, page.receipts.isEmpty { emptyState() }
                if let page = store.receiptPage, !page.receipts.isEmpty {
                    Text(text("settlement_previous")).merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
                    ForEach(page.receipts) { receipt in
                        Button { stack.push(.settlementDetails(String(receipt.id))) } label: {
                            receiptRow(receipt)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !store.previewReceipts.isEmpty {
                    Text(text("settlement_previous")).merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 4)
                }
                ForEach(store.previewReceipts) { settlement in
                    Button { stack.push(.settlementDetails(settlement.id)) } label: {
                        row(settlement)
                    }.buttonStyle(.plain).accessibilityIdentifier(settlement.id)
                }
            }.frame(maxWidth: .infinity).padding(16)
        }
        .background(MerchantTheme.background.ignoresSafeArea())
        .modifier(MerchantNavigationBar(title: "tab_settlements", background: MerchantTheme.surface, showsBackButton: false))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { storeIdentity }
        }
        .task(id: "\(locale.identifier)-\(reloadID)") { await store.reload() }
        .refreshable { await store.reload() }
    }

    private func emptyState() -> some View {
        MerchantCard(padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 32)).foregroundStyle(MerchantTheme.brand).accessibilityHidden(true)
                Text(text("settlement_empty")).merchantFont(16, .bold).foregroundStyle(MerchantTheme.heading)
                Text(text("settlement_empty_description")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
            }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 20)
        }.accessibilityElement(children: .combine)
            .accessibilityIdentifier("settlementEmpty")
    }

    private func receiptRow(_ receipt: MerchantReceipt) -> some View {
        let completed = receipt.status == "completed"
        let statusColor = completed ? MerchantTheme.success : MerchantTheme.secondary
        return MerchantCard(padding: 14, radius: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MerchantSettlementFormat.receiptAmount(receipt.amount, arabic: arabic))
                        .merchantFont(22, .black).foregroundStyle(MerchantTheme.heading)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(receiptCurrency(receipt.currency))
                        .merchantFont(13, .semibold).foregroundStyle(MerchantTheme.secondary)
                }
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        MerchantSettlementIcon(name: "CalendarSmall", size: 14)
                        Text(receipt.dateText).merchantFont(13, .semibold).foregroundStyle(MerchantTheme.body)
                    }
                    HStack(spacing: 6) {
                        MerchantSettlementIcon(name: "ClockSmall", size: 14)
                        Text(receipt.timeText).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                    }
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                VStack(spacing: 4) {
                    if completed {
                        MerchantSettlementIcon(name: "Check", size: 14).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(statusColor, lineWidth: 2))
                    } else {
                        MerchantSettlementIcon(name: "ClockSmall", size: 16).frame(width: 32, height: 32)
                            .overlay(Circle().stroke(statusColor, lineWidth: 2))
                    }
                    Text(receipt.statusText).merchantFont(11, .bold).foregroundStyle(statusColor)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }.frame(minHeight: 52)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settlementReceipt_\(receipt.id)")
        .accessibilityHint(receipt.description)
    }

    private func receiptCurrency(_ currency: String) -> String {
        switch currency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ريال", "ر.س", "sar": return text("settlement_currency")
        default: return currency
        }
    }

    private var storeIdentity: some View {
        HStack(spacing: 8) {
            MerchantProviderImage(url: merchantProfile?.image, size: 32, cornerRadius: 8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(MerchantTheme.brand, lineWidth: 2)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(merchantProfile?.name ?? "—").merchantFont(12, .bold).foregroundStyle(MerchantTheme.heading)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Capsule().fill(MerchantTheme.brand).frame(width: 32, height: 2.5)
            }
        }
    }
    private func row(_ settlement: MerchantSettlement) -> some View {
        MerchantCard(padding: 14, radius: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(MerchantSettlementFormat.money(settlement.transferredHalalas, arabic: arabic, decimals: false))
                        .merchantFont(22, .black).foregroundStyle(MerchantTheme.heading)
                    Text(text("settlement_currency")).merchantFont(13, .semibold).foregroundStyle(MerchantTheme.secondary)
                }
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        MerchantSettlementIcon(name: "CalendarSmall", size: 14)
                        Text(MerchantSettlementFormat.date(settlement.date, arabic: arabic)).merchantFont(13, .semibold).foregroundStyle(MerchantTheme.body)
                    }
                    HStack(spacing: 6) {
                        MerchantSettlementIcon(name: "ClockSmall", size: 14)
                        Text(MerchantSettlementFormat.date(settlement.date, arabic: arabic, timeOnly: true)).merchantFont(12).foregroundStyle(MerchantTheme.muted)
                    }
                }.frame(maxWidth: .infinity).multilineTextAlignment(.center)
                VStack(spacing: 4) {
                    MerchantSettlementIcon(name: "Check", size: 14).frame(width: 32, height: 32)
                        .overlay(Circle().stroke(MerchantTheme.success, lineWidth: 2))
                    Text(text("settlement_settled")).merchantFont(11, .bold).foregroundStyle(MerchantTheme.success)
                }
            }.frame(minHeight: 52)
        }.accessibilityElement(children: .combine)
    }
}
