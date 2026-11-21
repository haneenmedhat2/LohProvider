import SwiftUI
import UIKit

struct MerchantReportDetailTable: View {
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate: String?
    let report: MerchantReportDetailPresentation
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Text(merchantString("report_sales_details", locale: locale)).merchantFont(15, .bold)
                .foregroundStyle(MerchantTheme.heading).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 14)
            VStack(spacing: 1) {
                MerchantReportDetailTableRow(values: [text("report_date"), text("report_orders_short"),
                    text("report_sales") + "\n(" + report.currency + ")",
                    text("report_average") + "\n(" + report.currency + ")"], width: tableWidth, header: true)
                if report.rows.isEmpty {
                    Text(text("report_no_sales")).merchantFont(13).foregroundStyle(MerchantTheme.muted)
                        .frame(width: tableWidth).padding(.vertical, 28).background(MerchantTheme.surface)
                } else {
                    ForEach(report.rows) { row in orderRow(row) }
                }
                MerchantReportDetailTableTotals(totals: report.totals, currency: report.currency, width: tableWidth)
            }.background(MerchantTheme.subtle.opacity(0.65)).frame(width: tableWidth)
                .environment(\.layoutDirection, .leftToRight)
        }.background(MerchantTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(MerchantTheme.subtle))
            .onChange(of: report.rows.map(\.date)) { dates in
                if let selectedDate, !dates.contains(selectedDate) { self.selectedDate = nil }
            }
    }

    private var tableWidth: CGFloat { max(4, width) }
    private func text(_ key: String) -> String { merchantString(key, locale: locale) }

    private func orderRow(_ row: MerchantReportDetailPresentation.Row) -> some View {
        let orders = MerchantReportOverview.number(Decimal(row.totals.ordersCount))
        let sales = MerchantReportOverview.number(row.totals.salesTotal)
        let average = MerchantReportOverview.number(row.totals.averageOrderValue)
        let label = [row.label, text("report_orders_short") + ": " + orders,
                     text("report_sales") + ": " + sales + " " + report.currency,
                     text("report_average") + ": " + average + " " + report.currency].joined(separator: ", ")
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                selectedDate = selectedDate == row.date ? nil : row.date
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            MerchantReportDetailTableRow(values: [row.label, orders, sales, average],
                width: tableWidth, highlighted: row.highlighted, selected: selectedDate == row.date)
        }.buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityHint(text("report_row_selection_hint"))
            .accessibilityAddTraits(selectedDate == row.date ? [.isSelected] : [])
            .accessibilityIdentifier("merchantReportRow_" + row.date)
    }
}
