import Foundation
import Combine

@MainActor
final class MerchantReportsViewModel: ObservableObject {
    nonisolated static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        return value
    }
    nonisolated static let latest = calendar.date(from: DateComponents(year: 2026, month: 5, day: 26))!
    nonisolated static let earliest = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
    @Published private(set) var period: MerchantReportPeriod
    @Published private(set) var filter: MerchantReportFilter = .week
    @Published private(set) var summary: MerchantReportSummary?
    @Published private(set) var detail: MerchantReportDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingDetails = false
    @Published private(set) var error: APIError?
    @Published private(set) var detailError: APIError?
    let earliestDate: Date
    let latestDate: Date
    let days: [MerchantReportDay]
    private let responseHandler: ResponseHandler?
    private let token: () -> String?
    private var summaryGeneration = UUID()
    private var detailGeneration = UUID()
    private var summaryRefresh: (id: UUID, task: Task<Void, Never>)?
    private var detailRefresh: (id: UUID, task: Task<Void, Never>)?
    private var loadedToken: String?
    var isPreview: Bool { responseHandler == nil }
    var request: MerchantReportRequest { .init(filter: filter, period: period) }
    var requestID: String { filter.rawValue + MerchantReportRequest.date(period.start) + MerchantReportRequest.date(period.end) }

    init(responseHandler: ResponseHandler, token: @escaping () -> String?, now: Date = Date()) {
        self.responseHandler = responseHandler; self.token = token
        latestDate = Self.calendar.startOfDay(for: now)
        earliestDate = .distantPast
        period = MerchantReportPreset.week.period(ending: latestDate)
        days = []
    }

    #if DEBUG
    private init() {
        responseHandler = nil; token = { nil }
        earliestDate = Self.earliest; latestDate = Self.latest
        period = MerchantReportPreset.week.period(ending: Self.latest)
        let lastOrders = [58, 55, 69, 62, 74, 60, 20]
        let lastSales = [120, 250, 420, 380, 490, 410, 620]
        let count = Self.calendar.dateComponents([.day], from: Self.earliest, to: Self.latest).day!
        days = (0...count).map { index in
            let remaining = count - index
            return MerchantReportDay(date: Self.calendar.date(byAdding: .day, value: index, to: Self.earliest)!,
                orders: remaining < 7 ? lastOrders[6 - remaining] : 25 + (index * 13 % 55),
                salesHalalas: (remaining < 7 ? lastSales[6 - remaining] : 100 + (index * 37 % 430)) * 100)
        }
    }
    static func preview() -> MerchantReportsViewModel { .init() }
    #endif

    @discardableResult func apply(_ period: MerchantReportPeriod, preset: MerchantReportPreset? = nil) -> Bool {
        guard period.isValid, period.start >= earliestDate, period.end <= latestDate else { return false }
        let filter: MerchantReportFilter = preset.map {
            switch $0 { case .week: return .week; case .month: return .month; case .quarter: return .quarter; case .year: return .year }
        } ?? .custom
        guard self.period != period || self.filter != filter else { return true }
        cancelRefresh()
        cancelRefresh(detail: true)
        summaryGeneration = UUID(); detailGeneration = UUID()
        self.period = period; self.filter = filter
        summary = nil; self.detail = nil
        error = nil; detailError = nil; isLoading = false; isLoadingDetails = false
        return true
    }

    func reload() async {
        guard !Task.isCancelled else { return }
        cancelRefresh()
        await load(detail: false)
    }

    func reloadDetails() async {
        guard !Task.isCancelled else { return }
        cancelRefresh(detail: true)
        await load(detail: true)
    }

    func refresh() async { await refresh(detail: false) }
    func refreshDetails() async { await refresh(detail: true) }

    /// Keep the request alive if SwiftUI cancels its transient refresh action.
    /// Period/language changes and leaving the relevant screen explicitly cancel it.
    private func refresh(detail: Bool) async {
        cancelRefresh(detail: detail)
        let id = UUID()
        let task = Task { await load(detail: detail) }
        if detail { detailRefresh = (id, task) } else { summaryRefresh = (id, task) }
        await task.value
        if detail {
            if detailRefresh?.id == id { detailRefresh = nil }
        } else if summaryRefresh?.id == id { summaryRefresh = nil }
    }

    func cancelRefresh(detail: Bool = false) {
        if detail {
            detailRefresh?.task.cancel()
            detailRefresh = nil
        } else {
            summaryRefresh?.task.cancel()
            summaryRefresh = nil
        }
    }

    private func load(detail: Bool) async {
        guard !Task.isCancelled, let responseHandler else { return }
        let generation = UUID()
        let requestToken = token()
        let selection = request
        if loadedToken != requestToken { clearPayloads() }
        loadedToken = requestToken
        if detail { detailGeneration = generation; isLoadingDetails = true; detailError = nil }
        else { summaryGeneration = generation; isLoading = true; error = nil }
        defer {
            if (detail ? detailGeneration : summaryGeneration) == generation {
                if detail { isLoadingDetails = false } else { isLoading = false }
                if token() != requestToken, loadedToken == requestToken { clearPayloads(); loadedToken = nil }
            }
        }
        do {
            try Task.checkCancellation()
            guard let requestToken, !requestToken.isEmpty else { throw APIError.unauthenticated(nil) }
            if detail {
                let response: MerchantReportDetail = try await responseHandler.data(
                    from: ReportEndpoints.details(query: selection.queryItems(), token: requestToken),
                    language: AppLanguageManager.shared.apiLanguage)
                try Task.checkCancellation()
                guard detailGeneration == generation, token() == requestToken, request == selection else { return }
                self.detail = response
            } else {
                let response: MerchantReportSummary = try await responseHandler.data(
                    from: ReportEndpoints.summary(query: selection.queryItems(), token: requestToken),
                    language: AppLanguageManager.shared.apiLanguage)
                try Task.checkCancellation()
                guard summaryGeneration == generation, token() == requestToken, request == selection else { return }
                summary = response
            }
        } catch {
            guard (detail ? detailGeneration : summaryGeneration) == generation, token() == requestToken,
                  !Task.isCancelled, !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
            let mapped = APIError.map(error)
            if mapped.invalidatesSession { clearPayloads() }
            if detail { detailError = mapped } else { self.error = mapped }
        }
    }

    func download(period: MerchantReportPeriod) async throws -> Data {
        guard let responseHandler, let current = token(), !current.isEmpty else { throw APIError.unauthenticated(nil) }
        guard period.isValid else { throw APIError.configuration }
        let from = MerchantReportRequest.date(period.start, format: "MM-yyyy")
        let to = MerchantReportRequest.date(period.end, format: "MM-yyyy")
        let link: MerchantReportDownloadLink = try await responseHandler.data(
            from: ReportEndpoints.download(from: from, to: to, token: current),
            language: AppLanguageManager.shared.apiLanguage)
        let data = try await responseHandler.downloadPDF(at: link.downloadLink)
        try Task.checkCancellation()
        guard token() == current else { throw CancellationError() }
        return data
    }

    private func clearPayloads() {
        summary = nil; self.detail = nil; error = nil; detailError = nil
    }
    var snapshot: MerchantReportSnapshot {
        let duration = Self.calendar.dateComponents([.day], from: period.start, to: period.end).day! + 1
        let previous = MerchantReportPeriod(start: Self.calendar.date(byAdding: .day, value: -duration, to: period.start)!,
                                            end: Self.calendar.date(byAdding: .day, value: -1, to: period.start)!)
        let preceding = days.filter { previous.contains($0.date) }
        return .init(period: period, rows: days.filter { period.contains($0.date) },
                     previousOrders: preceding.reduce(0) { $0 + $1.orders }, previousSales: preceding.reduce(0) { $0 + $1.salesHalalas })
    }
}
