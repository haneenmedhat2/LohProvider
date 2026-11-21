import Foundation

@MainActor private final class ReportTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var responses: [HTTPResponse] = []
    var failure: Error?
    func execute(_ request: URLRequest) async throws -> HTTPResponse {
        requests.append(request)
        if let failure { throw failure }
        precondition(!responses.isEmpty)
        return responses.removeFirst()
    }
    func respond(_ data: Data, status: Int = 200) { responses = [.init(statusCode: status, data: data)]; failure = nil }
}
@MainActor private final class ReportServiceStub: MerchantReportServicing {
    var calls: [(String, MerchantReportRequest, String)] = []
    var summaryAction: () async throws -> MerchantReportSummary = { throw APIError.offline }
    var detailAction: () async throws -> MerchantReportDetail = { throw APIError.offline }
    func report(_ request: MerchantReportRequest, token: String) async throws -> MerchantReportSummary {
        calls.append(("summary", request, token)); return try await summaryAction()
    }
    func detailedReport(_ request: MerchantReportRequest, token: String) async throws -> MerchantReportDetail {
        calls.append(("detail", request, token)); return try await detailAction()
    }
    func downloadReport(period: MerchantReportPeriod, token: String) async throws -> Data { Data("%PDF-test".utf8) }
}
@main struct MerchantReportAPIChecks {
    static func fixture(_ name: String) throws -> Data { try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/\(name).json")) }
    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        MerchantReportStore.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    @MainActor static func main() async throws {
        let transport = ReportTransport()
        var language = "ar"
        var invalidated: String?
        let client = DefaultResponseHandler(transport: transport, language: { language }, logger: .init(output: { _ in }))
        client.onUnauthorized = { invalidated = $0 }
        let service = MerchantReportService(client: client)
        let period = MerchantReportPeriod(start: date(2026, 1, 1), end: date(2026, 12, 30))
        let selection = MerchantReportRequest(filter: .custom, period: period)
        transport.respond(try fixture("MerchantReport"))
        let report = try await service.report(selection, token: "report-token")
        precondition(report.stats.sales.total == 0 && report.stats.orders.total == 0 && report.stats.currency == "ريال")
        precondition(report.stats.compareText == "عن الفترة السابقة" && report.stats.sales.trend == "same")
        precondition(report.chart.groupBy == "month" && report.chart.points.count == 12)
        precondition(report.chart.points[0].date == "2026-01" && report.chart.points[0].label == "يناير")
        precondition(report.topOffers.offers.isEmpty && report.topOffers.pagination.perPage == 3)
        check(transport.requests.last!, path: "/api/vendor/report", language: "ar", filter: "custom")
        let query = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(query.map(\.name) == ["filter", "from", "to"] && query.map(\.value) == ["custom", "2026-01-01", "2026-12-30"])
        language = "en"
        transport.respond(try fixture("MerchantDetailedReport"))
        let detail = try await service.detailedReport(selection, token: "report-token")
        precondition(detail.rows.count == 12 && detail.rows[11].label == "ديسمبر")
        precondition(detail.stats.ordersCount == 0 && detail.totals.salesTotal == 0 && detail.currency == "ريال")
        precondition(detail.periodLabel == "1 يناير 2026 - 30 ديسمبر 2026" && detail.note == "جميع الأرقام تشمل الطلبات المكتملة فقط")
        let detailPresentation = MerchantReportDetailPresentation(report: detail)
        precondition(detailPresentation.currency == detail.currency && detailPresentation.note == detail.note)
        precondition(detailPresentation.stats == detail.stats && detailPresentation.totals == detail.totals)
        precondition(detailPresentation.rows.count == 12 && detailPresentation.rows.filter(\.highlighted).map(\.date) == ["2026-12"])
        precondition(detailPresentation.rows[0].label == "يناير" && detailPresentation.rows[0].totals == detail.rows[0].totals)
        try checkDetailPresentation()
        check(transport.requests.last!, path: "/api/vendor/detailed-report", language: "en", filter: "custom")
        for filter in MerchantReportFilter.allCases where filter != .custom {
            transport.respond(try fixture("MerchantReport"))
            _ = try await service.report(.init(filter: filter, period: period), token: "report-token")
            let items = URLComponents(url: transport.requests.last!.url!, resolvingAgainstBaseURL: false)!.queryItems!
            precondition(items == [.init(name: "filter", value: filter.rawValue)])
        }
        // Totals retain decimal precision and are independent of chart rows.
        var json = try JSONSerialization.jsonObject(with: fixture("MerchantReport")) as! [String: Any]
        var data = json["data"] as! [String: Any]
        data["top_offers"] = try JSONSerialization.jsonObject(with: fixture("MerchantReportTopOffers"))
        json["data"] = data
        transport.respond(try JSONSerialization.data(withJSONObject: json))
        let topOffers = try await service.report(selection, token: "report-token")
        precondition(topOffers.topOffers.offers.count == 1)
        let topOffer = topOffers.topOffers.offers[0]
        precondition(topOffer.id == 197 && topOffer.name == "Test Offer")
        precondition(topOffer.image?.absoluteString == "https://upgrade.loh.com.sa/storage/images/coupons/1792915133_3973.png")
        precondition(topOffer.currency == "ريال" && topOffer.salesCount == 1 && topOffer.salesTotal == 1)
        precondition(topOffer.status == "active" && topOffer.statusText == "نشط")
        precondition(topOffers.topOffers.pagination.totalItems == 1 && topOffers.topOffers.pagination.countItems == 1)
        precondition(topOffers.topOffers.pagination.currentPage == 1 && topOffers.topOffers.pagination.perPage == 3)
        precondition(topOffers.stats.sales.total == 0, "Top offers must not replace report-wide totals")
        try checkTopOfferDecoding()
        var stats = data["stats"] as! [String: Any]
        stats["sales"] = ["total": "90071992547409.93", "change_percent": "-12.25", "trend": "down"]
        stats["orders"] = ["total": 13, "change_percent": 4.5, "trend": "up"]
        data["stats"] = stats; json["data"] = data
        transport.respond(try JSONSerialization.data(withJSONObject: json))
        let populated = try await service.report(selection, token: "report-token")
        precondition(populated.stats.sales.total == Decimal(string: "90071992547409.93") && populated.stats.sales.changePercent == Decimal(string: "-12.25"))
        precondition(populated.stats.orders.total == 13 && populated.chart.points.allSatisfy { $0.value == 0 })
        for bad in ["", "NaN", "12oops", "1e999", "12\n"] {
            stats["sales"] = ["total": bad, "change_percent": 0, "trend": "same"]
            data["stats"] = stats; json["data"] = data
            transport.respond(try JSONSerialization.data(withJSONObject: json))
            await expect(.invalidResponse) { _ = try await service.report(selection, token: "report-token") }
        }
        let beforeInvalid = transport.requests.count
        await expect(.configuration) { _ = try await service.report(.init(filter: .custom, period: .init(start: period.end, end: period.start)), token: "report-token") }
        await expect(.invalidResponse) { _ = try await service.report(selection, token: "") }
        precondition(transport.requests.count == beforeInvalid)
        // Download JSON is followed by a credential-free request for the actual PDF.
        let pdf = Data("%PDF-1.7\nreport bytes".utf8)
        transport.responses = [.init(statusCode: 200, data: try fixture("MerchantReportDownload")), .init(statusCode: 200, data: pdf)]
        let downloaded = try await service.downloadReport(period: .init(start: date(2010, 1, 5), end: date(2024, 12, 15)), token: "report-token")
        precondition(downloaded == pdf)
        let endpoint = transport.requests[transport.requests.count - 2], file = transport.requests.last!
        precondition(endpoint.url!.path == "/api/vendor/download-report/01-2010/12-2024" && endpoint.value(forHTTPHeaderField: "Authorization") == "Bearer report-token")
        precondition(file.url!.path == "/storage/reports/vendor_report_01-2010_to_12-2024.pdf")
        precondition(file.value(forHTTPHeaderField: "Authorization") == nil && file.value(forHTTPHeaderField: "Cookie") == nil && file.value(forHTTPHeaderField: "Accept") == "application/pdf")
        for link in ["http://example.test/report.pdf", "file:///report.pdf", "https://user:password@example.test/report.pdf", "/relative.pdf"] {
            transport.respond(Data("{\"key\":\"success\",\"data\":{\"download_link\":\"\(link)\"}}".utf8))
            let count = transport.requests.count
            await expect(.invalidResponse) { _ = try await service.downloadReport(period: period, token: "report-token") }
            precondition(transport.requests.count == count + 1)
        }
        transport.responses = [.init(statusCode: 200, data: try fixture("MerchantReportDownload")), .init(statusCode: 200, data: Data("<html>not a PDF</html>".utf8))]
        await expect(.invalidResponse) { _ = try await service.downloadReport(period: period, token: "report-token") }
        transport.respond(Data(#"{"key":"unauthenticated","msg":"Expired"}"#.utf8), status: 401)
        await expect(.unauthenticated("Expired")) { _ = try await service.report(selection, token: "report-token") }
        precondition(invalidated == "report-token")
        transport.failure = URLError(.notConnectedToInternet)
        await expect(.offline) { _ = try await service.detailedReport(selection, token: "report-token") }
        transport.failure = URLError(.cancelled)
        do { _ = try await service.report(selection, token: "report-token"); preconditionFailure() } catch is CancellationError {}
        try await stores(report, populated, detail)
        await refreshes(report, populated, detail)
        print("Passed: live report contracts, populated/empty top offers, exact sales/currency/status/image mapping, totals/trends/labels, filters and dates, detail rows, download link/PDF handling, credential isolation, refresh lifetime/loading/data retention, account/range isolation, errors and cancellation.")
    }
    static func checkTopOfferDecoding() throws {
        let fixture = try JSONSerialization.jsonObject(with: fixture("MerchantReportTopOffers")) as! [String: Any]
        var offer = (fixture["offers"] as! [[String: Any]])[0]
        func decode() throws -> MerchantReportTopOffer {
            try JSONDecoder().decode(MerchantReportTopOffer.self, from: JSONSerialization.data(withJSONObject: offer))
        }
        offer["sales_total"] = "90071992547409.93"
        let precise = try decode()
        precondition(precise.salesTotal == Decimal(string: "90071992547409.93"))
        let numeric = try JSONDecoder().decode(MerchantReportTopOffer.self, from: Data(#"{"id":197,"name":"Test Offer","currency":"ريال","sales_count":1,"sales_total":0.29,"status":"active","status_text":"نشط"}"#.utf8))
        precondition(numeric.salesTotal == Decimal(string: "0.29"))
        offer["status"] = "inactive"; offer["status_text"] = "غير نشط"
        let inactive = try decode()
        precondition(inactive.status == "inactive" && inactive.statusText == "غير نشط")
        for image in ["", "/relative.png", "file:///image.png", "https://user:password@example.test/image.png", NSNull()] as [Any] {
            offer["image"] = image
            let fallback = try decode()
            precondition(fallback.image == nil)
        }
        offer.removeValue(forKey: "image")
        let missingImage = try decode()
        precondition(missingImage.image == nil)
        for invalid in ["NaN", "1.00oops", ""] {
            offer["sales_total"] = invalid
            do { _ = try decode(); preconditionFailure("Malformed sales total must fail") }
            catch {}
        }
        offer["sales_total"] = "1.00"; offer["sales_count"] = -1
        do { _ = try decode(); preconditionFailure("Negative sales count must fail") }
        catch {}
    }
    static func checkDetailPresentation() throws {
        let envelope = try JSONSerialization.jsonObject(with: fixture("MerchantDetailedReport")) as! [String: Any]
        var data = envelope["data"] as! [String: Any]
        data["from"] = "2026-05-20"; data["to"] = "2026-05-26"
        data["stats"] = ["orders_count": 8, "sales_total": "1248.29", "average_order_value": "156.03625"]
        data["totals"] = ["orders_count": 7, "sales_total": "90071992547409.93", "average_order_value": "0.005"]
        for (group, dates, highlighted) in [("day", ["2026-05-20", "2026-05-26"], ["2026-05-26"]),
                                           ("month", ["2026-04", "2026-05"], ["2026-05"]),
                                           ("year", ["2025", "2026"], ["2026"]),
                                           ("week", ["2026-W20", "2026-W21"], [])] {
            data["group_by"] = group
            data["rows"] = dates.map { ["date": $0, "label": "Server label", "orders_count": 1,
                                        "sales_total": "0.29", "average_order_value": "0.005"] as [String: Any] }
            let detail = try JSONDecoder().decode(MerchantReportDetail.self, from: JSONSerialization.data(withJSONObject: data))
            let model = MerchantReportDetailPresentation(report: detail)
            precondition(model.rows.filter(\.highlighted).map(\.date) == highlighted)
            precondition(model.rows.allSatisfy { $0.label == "Server label" && $0.totals.salesTotal == Decimal(string: "0.29") })
            precondition(model.stats.ordersCount == 8 && model.totals.ordersCount == 7)
            precondition(model.stats.averageOrderValue == Decimal(string: "156.03625"))
            precondition(model.totals.salesTotal == Decimal(string: "90071992547409.93") && model.totals.averageOrderValue == Decimal(string: "0.005"))
        }
        data["rows"] = []
        let empty = try JSONDecoder().decode(MerchantReportDetail.self, from: JSONSerialization.data(withJSONObject: data))
        precondition(MerchantReportDetailPresentation(report: empty).rows.isEmpty)
    }
    @MainActor static func stores(_ zero: MerchantReportSummary, _ populated: MerchantReportSummary, _ detail: MerchantReportDetail) async throws {
        let service = ReportServiceStub()
        var token: String? = "first"
        let store = MerchantReportStore(service: service, token: { token }, now: date(2026, 10, 25))
        precondition(!store.isPreview && store.days.isEmpty && store.summary == nil)
        precondition(store.period.end == date(2026, 10, 25) && store.period.start == date(2026, 10, 19) && store.filter == .week)
        var continuation: CheckedContinuation<MerchantReportSummary, Error>?
        service.summaryAction = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let first = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        precondition(store.isLoading && store.summary == nil)
        continuation!.resume(returning: zero); await first.value
        precondition(store.summary == zero && !store.isLoading && store.error == nil)
        service.summaryAction = { throw APIError.offline }; await store.reload()
        precondition(store.summary == zero && store.error == .offline)
        service.summaryAction = { populated }; await store.reload()
        precondition(store.summary == populated && store.error == nil)
        service.detailAction = { detail }; await store.reloadDetails()
        precondition(store.detail == detail && service.calls.last!.0 == "detail" && service.calls.last!.1 == store.request)
        continuation = nil
        service.summaryAction = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let stale = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        let period = MerchantReportPreset.month.period(ending: store.latestDate)
        precondition(store.apply(period, preset: .month) && store.summary == nil && store.detail == nil)
        service.summaryAction = { zero }; await store.reload()
        continuation!.resume(returning: populated); await stale.value
        precondition(store.summary == zero && store.filter == .month && service.calls.last!.1.filter == .month)
        precondition(!store.apply(.init(start: period.end, end: period.start)))
        continuation = nil
        service.summaryAction = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let cancelled = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        cancelled.cancel(); continuation!.resume(returning: populated); await cancelled.value
        precondition(store.summary == zero && store.error == nil)
        token = "second"
        service.summaryAction = { throw APIError.timeout }; await store.reload()
        precondition(store.summary == nil && store.detail == nil && store.error == .timeout)
        service.summaryAction = { zero }; await store.reload()
        continuation = nil
        service.summaryAction = { try await withCheckedThrowingContinuation { continuation = $0 } }
        let loggingOut = Task { await store.reload() }
        while continuation == nil { await Task.yield() }
        token = nil; continuation!.resume(returning: populated); await loggingOut.value
        precondition(store.summary == nil && store.detail == nil && store.error == nil)
        let count = service.calls.count; await store.reload()
        precondition(service.calls.count == count && store.error == .unauthenticated(nil))
        token = "third"; service.summaryAction = { zero }; await store.reload()
        service.summaryAction = { throw APIError.unauthenticated(nil) }; await store.reload()
        precondition(store.summary == nil && store.error == .unauthenticated(nil))
    }
    @MainActor static func refreshes(_ zero: MerchantReportSummary, _ populated: MerchantReportSummary, _ detail: MerchantReportDetail) async {
        let updatedDetail = MerchantReportDetail(period: detail.period, from: detail.from, to: detail.to,
            periodLabel: detail.periodLabel, currency: detail.currency, note: "Refreshed report",
            stats: detail.stats, groupBy: detail.groupBy, rows: [], totals: detail.totals)

        // Exercise the overview and detailed report through the same lifecycle scenarios.
        for isDetail in [false, true] {
            let service = ReportServiceStub()
            var token: String? = "first"
            let store = MerchantReportStore(service: service, token: { token }, now: date(2026, 10, 25))
            service.summaryAction = { populated }; service.detailAction = { detail }
            await store.reload(); await store.reloadDetails()
            let refresh: () async -> Void = {
                if isDetail { await store.refreshDetails() } else { await store.refresh() }
            }
            let reload: () async -> Void = {
                if isDetail { await store.reloadDetails() } else { await store.reload() }
            }
            let isLoading = { isDetail ? store.isLoadingDetails : store.isLoading }
            let error = { isDetail ? store.detailError : store.error }
            let isUpdated = { isDetail ? store.detail == updatedDetail : store.summary == zero }
            var continuation: CheckedContinuation<Void, Error>?
            var requestWasCancelled = false
            let waitForResponse: () async throws -> Void = {
                try await withCheckedThrowingContinuation { continuation = $0 }
                requestWasCancelled = Task.isCancelled
            }
            service.summaryAction = { try await waitForResponse(); return zero }
            service.detailAction = { try await waitForResponse(); return updatedDetail }
            let pull = Task { await refresh() }
            while continuation == nil { await Task.yield() }
            precondition(isLoading() && store.summary == populated && store.detail == detail,
                         "Loading stays visible and the previous report is retained during refresh")
            pull.cancel()
            continuation!.resume()
            await pull.value
            precondition(!requestWasCancelled && !isLoading() && error() == nil && isUpdated(),
                         "Cancelling the refresh action must not discard the new report")
            precondition(isDetail ? store.summary == populated : store.detail == detail,
                         "Refreshing one screen leaves the other report untouched")

            for failure: Error in [APIError.offline, CancellationError(), URLError(.cancelled)] {
                service.summaryAction = { throw failure }; service.detailAction = { throw failure }
                await refresh()
                precondition(isUpdated() && !isLoading(), "Failed/cancelled refreshes preserve the last successful report")
                precondition(error() == (failure is APIError ? .offline : nil))
            }

            continuation = nil; requestWasCancelled = false
            service.summaryAction = { try await waitForResponse(); return populated }
            service.detailAction = { try await waitForResponse(); return detail }
            let leaving = Task { await refresh() }
            while continuation == nil { await Task.yield() }
            store.cancelRefresh(detail: isDetail)
            continuation!.resume()
            await leaving.value
            precondition(requestWasCancelled && isUpdated() && !isLoading() && error() == nil,
                         "Screen exit cancels the request and preserves the current report")

            continuation = nil; requestWasCancelled = false
            let superseded = Task { await refresh() }
            while continuation == nil { await Task.yield() }
            service.summaryAction = { zero }; service.detailAction = { updatedDetail }
            await reload()
            continuation!.resume()
            await superseded.value
            precondition(requestWasCancelled && isUpdated() && !isLoading(),
                         "A newer reload cancels the old refresh and cannot be overwritten")

            continuation = nil; requestWasCancelled = false
            service.summaryAction = { try await waitForResponse(); return populated }
            service.detailAction = { try await waitForResponse(); return detail }
            let changingPeriod = Task { await refresh() }
            while continuation == nil { await Task.yield() }
            let period = MerchantReportPreset.month.period(ending: store.latestDate)
            precondition(store.apply(period, preset: .month))
            precondition(store.summary == nil && store.detail == nil && !isLoading())
            service.summaryAction = { zero }; service.detailAction = { updatedDetail }
            await reload()
            continuation!.resume()
            await changingPeriod.value
            precondition(requestWasCancelled && isUpdated() && !isLoading() && service.calls.last?.1.filter == .month,
                         "A response from the previous date range must not replace the new range")

            continuation = nil
            service.summaryAction = { try await waitForResponse(); return populated }
            service.detailAction = { try await waitForResponse(); return detail }
            let loggingOut = Task { await refresh() }
            while continuation == nil { await Task.yield() }
            token = nil
            continuation!.resume(throwing: APIError.offline)
            await loggingOut.value
            precondition(store.summary == nil && store.detail == nil && !isLoading() && error() == nil,
                         "Logout clears retained data even if the refresh fails")
        }
    }

    @MainActor static func check(_ request: URLRequest, path: String, language: String, filter: String) {
        precondition(request.url!.path == path && request.httpMethod == "GET" && request.httpBody == nil)
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer report-token" && request.value(forHTTPHeaderField: "lang") == language)
        precondition(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first!.value == filter)
    }
    @MainActor static func expect(_ expected: APIError, operation: () async throws -> Void) async {
        do { try await operation(); preconditionFailure("Expected \(expected)") }
        catch { precondition(error as? APIError == expected, "Unexpected \(error)") }
    }
}
