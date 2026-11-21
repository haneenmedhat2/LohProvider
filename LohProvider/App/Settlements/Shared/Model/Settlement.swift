import Foundation

/// All monetary values use halalas so list and detail totals share exact arithmetic.
struct MerchantSettlement: Identifiable {
    let id: String
    let date: Date
    let orderCount: Int
    let salesHalalas: Int
    let recipientAccount: String?
    static let commissionPercent = 25
    var commissionHalalas: Int { (salesHalalas * Self.commissionPercent + 50) / 100 }
    var transferredHalalas: Int { salesHalalas - commissionHalalas }

    static let samples: [MerchantSettlement] = {
        let formatter = ISO8601DateFormatter()
        let rows = [(26, "14:45", 248, 166400), (25, "11:30", 236, 157333),
                    (24, "09:10", 196, 130667), (23, "15:20", 204, 136000),
                    (22, "10:15", 184, 122667), (21, "08:50", 150, 100000)]
        return rows.map { day, time, orders, sales in
            MerchantSettlement(id: "settlement-2026-05-\(day)",
                date: formatter.date(from: "2026-05-\(day)T\(time):00+03:00")!,
                orderCount: orders, salesHalalas: sales, recipientAccount: nil)
        }
    }()

    static func find(_ id: String) -> MerchantSettlement? { samples.first { $0.id == id } }
}

enum MerchantSettlementFormat {
    static func receiptAmount(_ value: Decimal, arabic: Bool) -> String {
        value.formatted(.number.locale(Locale(identifier: arabic ? "ar_SA" : "en_US"))
            .precision(.fractionLength(0...38)))
    }

    static func amount(_ value: Decimal, arabic: Bool) -> String {
        value.formatted(.number.locale(Locale(identifier: arabic ? "ar_SA" : "en_US"))
            .precision(.fractionLength(2...38)))
    }

    static func money(_ halalas: Int, arabic: Bool, decimals: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_US")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals ? 2 : 0
        formatter.maximumFractionDigits = decimals ? 2 : 0
        return formatter.string(from: NSDecimalNumber(value: halalas).dividing(by: 100)) ?? "—"
    }
    static func date(_ date: Date, arabic: Bool, timeOnly: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: arabic ? "ar_SA" : "en_GB")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Riyadh")
        formatter.dateFormat = timeOnly ? "hh:mm a" : "EEEE d MMMM yyyy"
        return formatter.string(from: date)
    }
}
