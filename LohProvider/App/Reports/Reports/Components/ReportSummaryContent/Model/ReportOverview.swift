import Foundation

struct MerchantReportOverview {
    let currency: String
    let comparison: String
    let sales: MerchantReportStatistic
    let orders: MerchantReportStatistic
    let points: [MerchantReportPoint]

    init(report: MerchantReportSummary) {
        currency = report.stats.currency; comparison = report.stats.compareText
        sales = report.stats.sales; orders = report.stats.orders; points = report.chart.points
    }

    init(snapshot: MerchantReportSnapshot, currency: String, comparison: String, arabic: Bool) {
        self.currency = currency; self.comparison = comparison
        func statistic(total: Decimal, change: Double?) -> MerchantReportStatistic {
            .init(total: total, changePercent: change.map { Decimal($0) } ?? 0,
                  trend: change.map { $0 > 0 ? "up" : $0 < 0 ? "down" : "same" } ?? "unknown")
        }
        sales = statistic(total: Decimal(snapshot.salesHalalas) / 100, change: snapshot.salesChange)
        orders = statistic(total: Decimal(snapshot.orders), change: snapshot.ordersChange)
        points = snapshot.rows.map {
            .init(date: MerchantReportRequest.date($0.date), label: MerchantReportFormat.date($0.date, arabic: arabic, short: true),
                  value: Decimal($0.salesHalalas) / 100)
        }
    }

    /// The design uses Latin numerals; retain every decimal supplied by the API.
    static func number(_ value: Decimal) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US")).precision(.fractionLength(0...38)))
    }
}
