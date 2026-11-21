import Foundation

struct MerchantReportDetailPresentation {
    struct Row: Identifiable {
        let id: Int
        let date: String
        let label: String
        let totals: MerchantReportTotals
        let highlighted: Bool
    }

    let currency: String
    let stats: MerchantReportTotals
    let totals: MerchantReportTotals
    let rows: [Row]
    let note: String

    init(report: MerchantReportDetail) {
        currency = report.currency; stats = report.stats; totals = report.totals; note = report.note
        let end: String?
        switch report.groupBy {
        case "day": end = report.to
        case "month": end = String(report.to.prefix(7))
        case "year": end = String(report.to.prefix(4))
        default: end = nil
        }
        rows = report.rows.enumerated().map { index, row in
            .init(id: index, date: row.date, label: row.label, totals: row.totals, highlighted: row.date == end)
        }
    }

    init(snapshot: MerchantReportSnapshot, currency: String, note: String, arabic: Bool) {
        self.currency = currency; self.note = note
        stats = .init(ordersCount: snapshot.orders, salesTotal: Decimal(snapshot.salesHalalas) / 100,
                      averageOrderValue: Decimal(snapshot.averageHalalas) / 100)
        totals = stats
        rows = snapshot.rows.enumerated().map { index, row in
            .init(id: index, date: MerchantReportRequest.date(row.date),
                  label: MerchantReportFormat.date(row.date, arabic: arabic),
                  totals: .init(ordersCount: row.orders, salesTotal: Decimal(row.salesHalalas) / 100,
                                averageOrderValue: Decimal(row.averageHalalas) / 100),
                  highlighted: row.date == snapshot.period.end)
        }
    }
}
