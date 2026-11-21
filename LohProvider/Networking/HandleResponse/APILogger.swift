import Foundation
import Alamofire

struct APILogger {
    private let output: (String) -> Void

    init(output: @escaping (String) -> Void = { print($0) }) {
        self.output = output
    }

    func request(_ request: URLRequest, queries: APIParameters?, body: APIParameters?) {
        #if DEBUG
        let queryValues = logParameters(queries)
        let bodyValues = logParameters(body)
        output("""

        ====================================
        🚀🚀FULL REQUEST COMPONENETS:::

        URL:: \(request.url?.absoluteString ?? "No URL Found")
        ---------------------------------
        Method:: \(request.httpMethod ?? "No httpMethod")
        ---------------------------------
        Header::
        \(json(request.allHTTPHeaderFields ?? [:]))
        ---------------------------------
        Queries::
        \(json(queryValues))
        ---------------------------------
        Body::
        \(json(bodyValues))

        ====================================

        """)
        #endif
    }

    func response(_ data: Data?, for url: String, statusCode: Int? = nil) {
        #if DEBUG
        if let statusCode { output("HTTP \(statusCode) — \(url)") }
        guard let data else {
            output("""

            ====================================
            ⚡️⚡️RESPONSE FOR \(url) IS::
            nil
            ====================================

            """)
            return
        }
        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            output("""

            ====================================
            ⚡️⚡️RESPONSE FOR \(url) IS::
            \(json(object))
            ====================================

            """)
            return
        }
        output("""

        ====================================
        ⚡️⚡️RESPONSE FOR \(url) IS::
        [Non-JSON response: \(data.count) bytes]
        ====================================

        """)
        #endif
    }

    func failure(_ error: Error, request: URLRequest) {
        #if DEBUG
        if let error = error as? AFError {
            let underlying = (error.underlyingError ?? error) as NSError
            let reason = error.isExplicitlyCancelledError
                ? "request canceled"
                : "\(underlying.domain) (\(underlying.code))"
            output("Request failed for \(request.url?.path ?? "unknown path"): HTTP \(error.responseCode?.description ?? "no response"), \(reason)")
        } else {
            let failure = error as NSError
            output("Request failed for \(request.url?.path ?? "unknown path"): HTTP no response, \(failure.domain) (\(failure.code))")
        }
        #endif
    }

    private func logParameters(_ parameters: APIParameters?) -> [String: Any] {
        guard let parameters else { return [:] }
        return Dictionary(uniqueKeysWithValues: parameters.compactMap { element in
            guard let value = element.value else { return nil }
            return (element.key, value as Any)
        })
    }

    private func json(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value,
                                                    options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
              let text = String(data: data, encoding: .utf8) else {
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
               let text = String(data: data, encoding: .utf8) { return text }
            return "[Unserializable log data]"
        }
        return text
    }
}
