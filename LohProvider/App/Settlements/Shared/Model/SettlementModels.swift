import Foundation

/// The saved settlement-details response contains this financial summary.
/// Amounts retain the server's decimal units and currency; no commission or transfer is calculated locally.
struct MerchantSettlementFinancials: Decodable, Equatable {
    let deservedAmount: Decimal
    let marketerPercentageAmount: Decimal
    let marketerPercentageFromLOH: Decimal
    let appPercentageType: String
    let appPercentage: Decimal
    let appPercentageAmount: Decimal
    let currency: String

    private enum CodingKeys: String, CodingKey {
        case deservedAmount = "deserved_amount"
        case marketerPercentageAmount = "marketer_percentage_amount"
        case marketerPercentageFromLOH = "marketer_percentage_from_loh"
        case appPercentageType = "app_percentage_type"
        case appPercentage = "app_percentage"
        case appPercentageAmount = "app_percentage_amount"
        case currency
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        deservedAmount = try values.settlementDecimal(.deservedAmount)
        marketerPercentageAmount = try values.settlementDecimal(.marketerPercentageAmount)
        marketerPercentageFromLOH = try values.settlementDecimal(.marketerPercentageFromLOH)
        appPercentageType = try values.decode(String.self, forKey: .appPercentageType)
        appPercentage = try values.settlementDecimal(.appPercentage)
        appPercentageAmount = try values.settlementDecimal(.appPercentageAmount)
        currency = try values.decode(String.self, forKey: .currency)
        guard !appPercentageType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !currency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidResponse
        }
    }
}

/// Settlement details are returned for a receipt ID; the response may group several receipts.
struct MerchantSettlementDetail: Decodable, Equatable {
    let id: String
    let status: String
    let statusText: String
    let amount: Decimal
    let currency: String
    let date: String
    let dateText: String
    let time: String
    let timeText: String
    let transferMethod: String
    let transferMethodText: String
    let receivingAccount: String
    let ordersCount: Int
    let ordersCountText: String
    let salesTotal: Decimal
    let commissionPercentage: Decimal
    let commissionAmount: Decimal
    let commissionLabel: String
    let transferredAmount: Decimal
    let receipts: [MerchantReceipt]

    private enum CodingKeys: String, CodingKey {
        case id, status, amount, currency, date, time, receipts
        case statusText = "status_text", dateText = "date_text", timeText = "time_text"
        case transferMethod = "transfer_method", transferMethodText = "transfer_method_text"
        case receivingAccount = "receiving_account", ordersCount = "orders_count"
        case ordersCountText = "orders_count_text", salesTotal = "sales_total"
        case commissionPercentage = "commission_percentage", commissionAmount = "commission_amount"
        case commissionLabel = "commission_label", transferredAmount = "transferred_amount"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        status = try values.decode(String.self, forKey: .status)
        statusText = try values.decode(String.self, forKey: .statusText)
        amount = try values.settlementDecimal(.amount)
        currency = try values.decode(String.self, forKey: .currency)
        date = try values.decode(String.self, forKey: .date)
        dateText = try values.decode(String.self, forKey: .dateText)
        time = try values.decode(String.self, forKey: .time)
        timeText = try values.decode(String.self, forKey: .timeText)
        transferMethod = try values.decode(String.self, forKey: .transferMethod)
        transferMethodText = try values.decode(String.self, forKey: .transferMethodText)
        receivingAccount = try values.decode(String.self, forKey: .receivingAccount)
        ordersCount = try values.decode(Int.self, forKey: .ordersCount)
        ordersCountText = try values.decode(String.self, forKey: .ordersCountText)
        salesTotal = try values.settlementDecimal(.salesTotal)
        commissionPercentage = try values.settlementDecimal(.commissionPercentage)
        commissionAmount = try values.settlementDecimal(.commissionAmount)
        commissionLabel = try values.decode(String.self, forKey: .commissionLabel)
        transferredAmount = try values.settlementDecimal(.transferredAmount)
        receipts = try values.decode([MerchantReceipt].self, forKey: .receipts)
        guard ordersCount >= 0, !receipts.isEmpty,
              [id, status, statusText, currency, date, dateText, time, timeText, transferMethod,
               transferMethodText, receivingAccount, ordersCountText, commissionLabel]
                .allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw APIError.invalidResponse
        }
    }
}

/// The live my-receipts response supersedes the collection's older summary example.
struct MerchantReceiptPage: Decodable, Equatable {
    let receipts: [MerchantReceipt]
    let pagination: MerchantReceiptPagination

    private enum CodingKeys: String, CodingKey { case receipts, pagination }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        receipts = try values.decode([MerchantReceipt].self, forKey: .receipts)
        pagination = try values.decode(MerchantReceiptPagination.self, forKey: .pagination)
        guard pagination.currentPage > 0, pagination.totalPages >= pagination.currentPage,
              pagination.perPage > 0, pagination.countItems == receipts.count,
              pagination.countItems <= pagination.perPage, pagination.totalItems >= receipts.count else {
            throw APIError.invalidResponse
        }
    }
}

struct MerchantReceiptPagination: Decodable, Equatable {
    let countItems: Int
    let currentPage: Int
    let perPage: Int
    let totalItems: Int
    let totalPages: Int
    let nextPageURL: String?
    let previousPageURL: String?

    private enum CodingKeys: String, CodingKey {
        case countItems = "count_items", currentPage = "current_page", perPage = "per_page"
        case totalItems = "total_items", totalPages = "total_pages", nextPageURL = "next_page_url"
        case previousPageURL = "prev_page_url", legacyPreviousPageURL = "perv_page_url"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        countItems = try values.decode(Int.self, forKey: .countItems)
        currentPage = try values.decode(Int.self, forKey: .currentPage)
        perPage = try values.decode(Int.self, forKey: .perPage)
        totalItems = try values.decode(Int.self, forKey: .totalItems)
        totalPages = try values.decode(Int.self, forKey: .totalPages)
        nextPageURL = try values.decodeIfPresent(String.self, forKey: .nextPageURL)
        previousPageURL = try values.decodeIfPresent(String.self, forKey: .previousPageURL)
            ?? values.decodeIfPresent(String.self, forKey: .legacyPreviousPageURL)
    }
}

struct MerchantReceipt: Decodable, Equatable, Identifiable {
    let id: Int
    let amount: Decimal
    let createdAt: String
    let currency: String
    let dateText: String
    let description: String
    let status: String
    let statusText: String
    let timeText: String

    private enum CodingKeys: String, CodingKey {
        case id, amount, currency, description, status
        case createdAt = "created_at", dateText = "date_text"
        case statusText = "status_text", timeText = "time_text"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        amount = try values.settlementDecimal(.amount)
        createdAt = try values.decode(String.self, forKey: .createdAt)
        currency = try values.decode(String.self, forKey: .currency)
        dateText = try values.decode(String.self, forKey: .dateText)
        description = try values.decode(String.self, forKey: .description)
        status = try values.decode(String.self, forKey: .status)
        statusText = try values.decode(String.self, forKey: .statusText)
        timeText = try values.decode(String.self, forKey: .timeText)
        guard id > 0,
              createdAt.range(of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z"#, options: .regularExpression) != nil,
              [currency, dateText, description, status, statusText, timeText]
                .allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw APIError.invalidResponse
        }
    }
}

private extension KeyedDecodingContainer {
    func settlementDecimal(_ key: Key) throws -> Decimal {
        let number: Decimal
        if let string = try? decode(String.self, forKey: key) {
            // Decimal(string:) accepts numeric prefixes, so validate the entire API value first.
            guard string.range(of: #"\A-?[0-9]+(?:\.[0-9]+)?\z"#, options: .regularExpression) != nil,
                  let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
                throw APIError.invalidResponse
            }
            number = value
        } else {
            number = try decode(Decimal.self, forKey: key)
        }
        guard !number.isNaN else { throw APIError.invalidResponse }
        return number
    }
}
