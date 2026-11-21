import SwiftUI

struct MerchantSettlementDetailView: View {
    @EnvironmentObject private var store: MerchantSettlementsViewModel
    @Environment(\.locale) private var locale
    @State private var reloadID = UUID()
    let settlementID: String
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }
    private func text(_ key: String) -> String { merchantString(key, arabic: arabic) }
    private func money(_ amount: Int) -> String {
        MerchantSettlementFormat.money(amount, arabic: arabic) + " " + text("settlement_currency")
    }
    var body: some View {
        ScrollView {
            if let receipt = store.receipt(id: settlementID) {
                receiptDetails(receipt)
            } else if let settlement = MerchantSettlement.find(settlementID) {
                VStack(spacing: 14) {
                    MerchantCard(padding: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            MerchantStatusBadge(title: text("settlement_completed"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(text("settlement_transferred")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                                    Text(money(settlement.transferredHalalas)).merchantFont(28, .black)
                                        .foregroundStyle(MerchantTheme.success).minimumScaleFactor(0.7).lineLimit(1)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                MerchantSettlementIcon(name: "Money", size: 32).frame(width: 60, height: 60)
                                    .background(Color(red: 1, green: 241/255, blue: 237/255)).clipShape(Circle())
                            }
                        }
                    }
                    MerchantCard(padding: 20) {
                        VStack(spacing: 0) {
                            sectionHeader("settlement_information", icon: "Info")
                            info("settlement_date", value: MerchantSettlementFormat.date(settlement.date, arabic: arabic), icon: "Calendar")
                            info("settlement_time", value: MerchantSettlementFormat.date(settlement.date, arabic: arabic, timeOnly: true), icon: "Clock")
                            info("settlement_method", value: text("settlement_bank_transfer"), icon: "Bank")
                            info("settlement_account", value: settlement.recipientAccount ?? "—", icon: "Account")
                        }
                    }
                    MerchantCard(padding: 20) {
                        VStack(spacing: 0) {
                            sectionHeader("settlement_summary", icon: "Summary")
                            info("settlement_orders", value: String(settlement.orderCount) + " " + text("settlement_order_unit"), icon: "Orders")
                            info("settlement_sales", value: money(settlement.salesHalalas), icon: "Sales")
                            info("settlement_commission", value: "− " + money(settlement.commissionHalalas), icon: "Commission", negative: true)
                            HStack(spacing: 12) {
                                Text(text("settlement_transferred")).merchantFont(14, .bold)
                                Spacer(minLength: 0)
                                Text(money(settlement.transferredHalalas)).merchantFont(15, .bold)
                            }.foregroundStyle(MerchantTheme.success).padding(12)
                                .background(Color(red: 240/255, green: 253/255, blue: 244/255))
                                .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.top, 8)
                        }
                    }
                }.padding(16)
            } else {
                Text(text("settlement_not_found")).merchantFont(16).foregroundStyle(MerchantTheme.secondary).padding(24)
            }
        }
        .modifier(MerchantAccountNavigation(title: "nav_settlement_details"))
        .task(id: "\(settlementID)-\(reloadID)-\(locale.identifier)") { await store.loadDetails(id: settlementID) }
    }

    private func receiptDetails(_ receipt: MerchantReceipt) -> some View {
        let detail = store.detail?.receipts.contains(where: { $0.id == receipt.id }) == true ? store.detail : nil
        let currency = detail?.currency ?? receipt.currency
        let transferredAmount = detail?.transferredAmount ?? receipt.amount
        let completed = (detail?.status ?? receipt.status) == "completed"
        return VStack(spacing: 14) {
            MerchantCard(padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    if completed {
                        MerchantStatusBadge(title: text("settlement_completed"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(detail?.statusText ?? receipt.statusText)
                            .merchantFont(13, .bold).foregroundStyle(MerchantTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text("settlement_transferred")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                            Text(receiptMoney(transferredAmount, currency: currency)).merchantFont(28, .black)
                                .foregroundStyle(MerchantTheme.success).minimumScaleFactor(0.7).lineLimit(1)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        MerchantSettlementIcon(name: "Money", size: 32).frame(width: 60, height: 60)
                            .background(Color(red: 1, green: 241/255, blue: 237/255)).clipShape(Circle())
                    }
                }
            }
            MerchantCard(padding: 20) {
                VStack(spacing: 0) {
                    sectionHeader("settlement_information", icon: "Info")
                    info("settlement_date", value: detail?.dateText ?? receipt.dateText, icon: "Calendar")
                    info("settlement_time", value: detail?.timeText ?? receipt.timeText, icon: "Clock")
                    info("settlement_method", value: detail?.transferMethodText ?? "—", icon: "Bank")
                    info("settlement_account", value: detail?.receivingAccount ?? "—", icon: "Account")
                }
            }
            MerchantCard(padding: 20) {
                VStack(spacing: 0) {
                    sectionHeader("settlement_summary", icon: "Summary")
                    info("settlement_orders", value: detail?.ordersCountText ?? "—", icon: "Orders")
                    info("settlement_sales", value: detail.map { receiptMoney($0.salesTotal, currency: $0.currency) } ?? "—", icon: "Sales")
                    info("settlement_app_commission",
                         value: detail.map { ($0.commissionAmount == 0 ? "" : "− ") + receiptMoney($0.commissionAmount, currency: $0.currency) } ?? "—",
                         icon: "Commission", negative: detail.map { $0.commissionAmount != 0 } ?? false,
                         label: detail?.commissionLabel)
                    HStack(spacing: 12) {
                        Text(text("settlement_transferred")).merchantFont(14, .bold)
                        Spacer(minLength: 0)
                        Text(receiptMoney(transferredAmount, currency: currency)).merchantFont(15, .bold)
                    }.foregroundStyle(MerchantTheme.success).padding(12)
                        .background(Color(red: 240/255, green: 253/255, blue: 244/255))
                        .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.top, 8)
                }
            }
            if store.isLoadingDetail { ProgressView().tint(MerchantTheme.brand) }
            if let error = store.detailError {
                MerchantFieldError(message: error.message(localize: text))
                MerchantButton(title: text("api_retry"), secondary: true) { reloadID = UUID() }
            }
        }.padding(16)
    }

    private func receiptMoney(_ amount: Decimal, currency: String) -> String {
        let unit: String
        switch currency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ريال", "ر.س", "sar": unit = text("settlement_currency")
        default: unit = currency
        }
        return MerchantSettlementFormat.receiptAmount(amount, arabic: arabic) + " " + unit
    }
    private func sectionHeader(_ key: String, icon: String) -> some View {
        HStack {
            MerchantSettlementIcon(name: icon, size: 14).frame(width: 28, height: 28)
                .overlay(Circle().stroke(MerchantTheme.brand))
            Spacer()
            Text(text(key)).merchantFont(15, .bold).foregroundStyle(MerchantTheme.heading)
        }.padding(.bottom, 4)
    }
    private func info(_ key: String, value: String, icon: String, negative: Bool = false,
                      label: String? = nil) -> some View {
        HStack(spacing: 8) {
            MerchantSettlementIcon(name: icon).frame(width: 20)
            Text(label ?? text(key)).merchantFont(13).foregroundStyle(MerchantTheme.muted)
            Spacer(minLength: 8)
            Text(value).merchantFont(14, .semibold).foregroundStyle(negative ? MerchantTheme.error : MerchantTheme.heading)
                .multilineTextAlignment(.trailing)
        }.padding(.vertical, 13)
            .overlay(alignment: .bottom) { MerchantTheme.background.frame(height: 1) }
    }
}

struct MerchantSettlements_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["ar", "en"], id: \.self) { language in
            NavigationStack {
                MerchantSettlementDetailView(settlementID: MerchantSettlement.samples[0].id)
            }
            .environmentObject(MerchantSettlementsViewModel.preview())
            .environment(\.locale, Locale(identifier: language))
            .environment(\.layoutDirection, language == "ar" ? .rightToLeft : .leftToRight)
            .previewDisplayName(language)
        }
    }
}
