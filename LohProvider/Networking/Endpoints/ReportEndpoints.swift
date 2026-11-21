import Foundation

struct ReportEndpoints {
    private init() {}
}

extension ReportEndpoints {
    static func summary(query: [URLQueryItem], token: String) -> Endpoint<APIEnvelope<MerchantReportSummary>> {
        var queries: APIParameters = [:]
        for item in query { queries[item.name] = item.value }
        return Endpoint(path: "vendor/report", queries: queries, headerType: .authorized(token: token))
    }

    static func details(query: [URLQueryItem], token: String) -> Endpoint<APIEnvelope<MerchantReportDetail>> {
        var queries: APIParameters = [:]
        for item in query { queries[item.name] = item.value }
        return Endpoint(path: "vendor/detailed-report", queries: queries, headerType: .authorized(token: token))
    }

    static func download(from: String, to: String, token: String) -> Endpoint<APIEnvelope<MerchantReportDownloadLink>> {
        return Endpoint(path: "vendor/download-report/\(from)/\(to)", headerType: .authorized(token: token))
    }
}
