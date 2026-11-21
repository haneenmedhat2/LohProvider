import Foundation

struct MerchantReportPeriod: Equatable, Sendable {
    var start: Date
    var end: Date
    var isValid: Bool { start <= end }
    func contains(_ date: Date) -> Bool { date >= start && date < MerchantReportsViewModel.calendar.date(byAdding: .day, value: 1, to: end)! }
}

enum MerchantReportPreset: String, CaseIterable, Identifiable {
    case week, month, quarter, year
    var id: String { rawValue }
    var key: String { "report_preset_" + rawValue }
    var days: Int? { switch self { case .week: return 7; case .month: return 30; case .quarter: return 90; case .year: return nil } }
    func period(ending end: Date) -> MerchantReportPeriod {
        let calendar = MerchantReportsViewModel.calendar
        let start = days.map { calendar.date(byAdding: .day, value: 1 - $0, to: end)! }
            ?? calendar.date(from: calendar.dateComponents([.year], from: end))!
        return .init(start: start, end: end)
    }
}

struct MerchantReportDay: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let orders: Int
    let salesHalalas: Int
    var averageHalalas: Int { orders == 0 ? 0 : (salesHalalas + orders / 2) / orders }
}

struct MerchantReportSnapshot: Sendable {
    let period: MerchantReportPeriod
    let rows: [MerchantReportDay]
    let previousOrders: Int
    let previousSales: Int
    var orders: Int { rows.reduce(0) { $0 + $1.orders } }
    var salesHalalas: Int { rows.reduce(0) { $0 + $1.salesHalalas } }
    var averageHalalas: Int { orders == 0 ? 0 : (salesHalalas + orders / 2) / orders }
    var salesChange: Double? { previousSales == 0 ? nil : Double(salesHalalas - previousSales) / Double(previousSales) * 100 }
    var ordersChange: Double? { previousOrders == 0 ? nil : Double(orders - previousOrders) / Double(previousOrders) * 100 }
    var offerSales: [Int] {
        let first = salesHalalas * 45 / 100
        let second = salesHalalas * 32 / 100
        return [first, second, salesHalalas - first - second]
    }
}


enum MerchantReportFormat {
    static func date(_ date: Date, arabic: Bool, short: Bool = false) -> String {
        let f = DateFormatter()
        f.calendar = MerchantReportsViewModel.calendar
        f.timeZone = MerchantReportsViewModel.calendar.timeZone
        f.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
        f.dateFormat = short ? "d MMM" : "d MMM yyyy"
        return f.string(from: date)
    }
    static func period(_ period: MerchantReportPeriod, arabic: Bool) -> String {
        date(period.start, arabic: arabic) + " – " + date(period.end, arabic: arabic)
    }
    static func monthPeriod(_ period: MerchantReportPeriod, arabic: Bool) -> String {
        let formatter = DateFormatter()
        formatter.calendar = MerchantReportsViewModel.calendar
        formatter.timeZone = MerchantReportsViewModel.calendar.timeZone
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
        formatter.dateFormat = "MMMM yyyy"
        let start = formatter.string(from: period.start), end = formatter.string(from: period.end)
        return start == end ? start : start + " – " + end
    }
    static func money(_ halalas: Int, arabic: Bool) -> String {
        MerchantSettlementFormat.money(halalas, arabic: arabic, decimals: halalas % 100 != 0)
    }
}
