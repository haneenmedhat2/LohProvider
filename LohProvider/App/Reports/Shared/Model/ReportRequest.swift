import Foundation

enum MerchantReportFilter: String, CaseIterable {
    case week = "last_7_days", month = "last_30_days", quarter = "last_90_days", year = "current_year", custom
}

struct MerchantReportRequest: Equatable {
    let filter: MerchantReportFilter
    let period: MerchantReportPeriod

    func queryItems() throws -> [URLQueryItem] {
        guard period.isValid else { throw APIError.configuration }
        var items = [URLQueryItem(name: "filter", value: filter.rawValue)]
        if filter == .custom {
            items += [.init(name: "from", value: Self.date(period.start)), .init(name: "to", value: Self.date(period.end))]
        }
        return items
    }

    static func date(_ date: Date, format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = MerchantReportsViewModel.calendar
        formatter.timeZone = MerchantReportsViewModel.calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

struct MerchantReportDownloadLink: Decodable {
    let downloadLink: URL
    enum CodingKeys: String, CodingKey { case downloadLink = "download_link" }
}
