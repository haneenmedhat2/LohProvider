import Foundation

struct MerchantReportSummary: Decodable, Equatable {
    let stats: MerchantReportStatistics
    let chart: MerchantReportChart
    let topOffers: MerchantReportTopOffers
    enum CodingKeys: String, CodingKey { case stats, chart, topOffers = "top_offers" }
}

struct MerchantReportStatistics: Decodable, Equatable {
    let currency: String
    let compareText: String
    let sales: MerchantReportStatistic
    let orders: MerchantReportStatistic
    enum CodingKeys: String, CodingKey { case currency, compareText = "compare_text", sales, orders }
}

struct MerchantReportStatistic: Decodable, Equatable {
    let total: Decimal
    let changePercent: Decimal
    let trend: String
    enum CodingKeys: String, CodingKey { case total, changePercent = "change_percent", trend }
    init(total: Decimal, changePercent: Decimal, trend: String) {
        self.total = total; self.changePercent = changePercent; self.trend = trend
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        total = try values.reportDecimal(.total)
        changePercent = try values.reportDecimal(.changePercent)
        trend = try values.decode(String.self, forKey: .trend)
    }
}

struct MerchantReportChart: Decodable, Equatable {
    let groupBy: String
    let points: [MerchantReportPoint]
    enum CodingKeys: String, CodingKey { case groupBy = "group_by", points }
}

struct MerchantReportPoint: Decodable, Equatable {
    let date: String
    let label: String
    let value: Decimal
    enum CodingKeys: String, CodingKey { case date, label, value }
    init(date: String, label: String, value: Decimal) {
        self.date = date; self.label = label; self.value = value
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decode(String.self, forKey: .date)
        label = try values.decode(String.self, forKey: .label)
        value = try values.reportDecimal(.value)
    }
}

struct MerchantReportTopOffers: Decodable, Equatable {
    struct Pagination: Decodable, Equatable {
        let totalItems: Int
        let countItems: Int
        let perPage: Int
        let totalPages: Int
        let currentPage: Int
        enum CodingKeys: String, CodingKey {
            case totalItems = "total_items", countItems = "count_items", perPage = "per_page"
            case totalPages = "total_pages", currentPage = "current_page"
        }
    }
    let pagination: Pagination
    let offers: [MerchantReportTopOffer]
}

struct MerchantReportTopOffer: Decodable, Equatable, Identifiable {
    let id: Int
    let name: String
    let image: URL?
    let currency: String
    let salesCount: Int
    let salesTotal: Decimal
    let status: String
    let statusText: String

    enum CodingKeys: String, CodingKey {
        case id, name, image, currency, status
        case salesCount = "sales_count", salesTotal = "sales_total", statusText = "status_text"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        currency = try values.decode(String.self, forKey: .currency)
        salesCount = try values.decode(Int.self, forKey: .salesCount)
        salesTotal = try values.reportDecimal(.salesTotal)
        status = try values.decode(String.self, forKey: .status)
        statusText = try values.decode(String.self, forKey: .statusText)
        guard id > 0, salesCount >= 0 else { throw APIError.invalidResponse }
        if let text = try values.decodeIfPresent(String.self, forKey: .image),
           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
           let host = url.host, !host.isEmpty, url.user == nil, url.password == nil {
            image = url
        } else {
            image = nil
        }
    }
}

struct MerchantReportTotals: Decodable, Equatable {
    let ordersCount: Int
    let salesTotal: Decimal
    let averageOrderValue: Decimal
    enum CodingKeys: String, CodingKey {
        case ordersCount = "orders_count", salesTotal = "sales_total", averageOrderValue = "average_order_value"
    }
    init(ordersCount: Int, salesTotal: Decimal, averageOrderValue: Decimal) {
        self.ordersCount = ordersCount; self.salesTotal = salesTotal; self.averageOrderValue = averageOrderValue
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        ordersCount = try values.decode(Int.self, forKey: .ordersCount)
        guard ordersCount >= 0 else { throw APIError.invalidResponse }
        salesTotal = try values.reportDecimal(.salesTotal)
        averageOrderValue = try values.reportDecimal(.averageOrderValue)
    }
}

struct MerchantReportDetail: Decodable, Equatable {
    let period: String
    let from: String
    let to: String
    let periodLabel: String
    let currency: String
    let note: String
    let stats: MerchantReportTotals
    let groupBy: String
    let rows: [MerchantReportDetailRow]
    let totals: MerchantReportTotals
    enum CodingKeys: String, CodingKey {
        case period, from, to, periodLabel = "period_label", currency, note, stats, groupBy = "group_by", rows, totals
    }
}

struct MerchantReportDetailRow: Decodable, Equatable {
    let date: String
    let label: String
    let totals: MerchantReportTotals
    enum CodingKeys: String, CodingKey { case date, label }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decode(String.self, forKey: .date)
        label = try values.decode(String.self, forKey: .label)
        totals = try MerchantReportTotals(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func reportDecimal(_ key: Key) throws -> Decimal {
        if let string = try? decode(String.self, forKey: key) {
            guard string.range(of: #"\A-?[0-9]+(?:\.[0-9]+)?\z"#, options: .regularExpression) != nil,
                  let number = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")), !number.isNaN else {
                throw APIError.invalidResponse
            }
            return number
        }
        let number = try decode(Decimal.self, forKey: key)
        guard !number.isNaN else { throw APIError.invalidResponse }
        return number
    }
}
