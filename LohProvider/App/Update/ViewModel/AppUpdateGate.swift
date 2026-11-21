import Foundation
import Combine

@MainActor
final class MerchantAppUpdateGate: ObservableObject {
    private static let blockedVersionKey = "merchantAppUpdateBlockedVersion"

    enum State {
        case checking
        case ready
        case updateRequired(URL)
    }

    @Published private(set) var state: State
    private var isRefreshing = false
    private let checker: MerchantAppStoreVersionChecker
    private let defaults: UserDefaults

    init(checker: MerchantAppStoreVersionChecker = .live, defaults: UserDefaults = .standard) {
        self.checker = checker
        self.defaults = defaults
        if checker.bundleID == MerchantAppStoreVersionChecker.publishedBundleID,
           defaults.string(forKey: Self.blockedVersionKey) == checker.installedVersion {
            state = .updateRequired(MerchantAppStoreVersionChecker.fallbackStoreURL)
        } else {
            state = .checking
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            if let storeURL = try await checker.requiredUpdateURL() {
                defaults.set(checker.installedVersion, forKey: Self.blockedVersionKey)
                state = .updateRequired(storeURL)
            } else {
                defaults.removeObject(forKey: Self.blockedVersionKey)
                state = .ready
            }
        } catch {
            // Keep an existing gate when the Store is temporarily unavailable.
            if case .updateRequired = state { return }
            state = .ready
        }
    }
}

struct MerchantAppStoreVersionChecker {
    static let appStoreID = 6449736851
    static let publishedBundleID = "com.aait.LohProvider"
    static let fallbackStoreURL = URL(string: "https://apps.apple.com/sa/app/loh-provider/id6449736851")!

    static let live = MerchantAppStoreVersionChecker(
        installedVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        bundleID: Bundle.main.bundleIdentifier ?? "",
        fetch: {
            var components = URLComponents(string: "https://itunes.apple.com/lookup")!
            components.queryItems = [
                URLQueryItem(name: "id", value: String(appStoreID)),
                URLQueryItem(name: "country", value: "sa"),
                URLQueryItem(name: "entity", value: "software")
            ]
            var request = URLRequest(url: components.url!)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            return data
        }
    )

    let installedVersion: String
    let bundleID: String
    let fetch: () async throws -> Data

    func requiredUpdateURL() async throws -> URL? {
        // A differently signed development build cannot be updated by this listing.
        guard bundleID == Self.publishedBundleID else { return nil }
        let data = try await fetch()
        let response = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard let release = response.results.first(where: {
            $0.trackId == Self.appStoreID && $0.bundleId == bundleID
        }), Self.isNewer(release.version, than: installedVersion) else { return nil }

        if let url = URL(string: release.trackViewUrl ?? ""),
           url.scheme == "https", url.host == "apps.apple.com" {
            return url
        }
        return Self.fallbackStoreURL
    }

    static func isNewer(_ storeVersion: String, than installedVersion: String) -> Bool {
        func parts(_ version: String) -> [Int]? {
            let values = version.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
            guard !values.isEmpty, values.allSatisfy({ $0 != nil }) else { return nil }
            return values.compactMap { $0 }
        }
        guard let store = parts(storeVersion), let installed = parts(installedVersion) else { return false }
        for index in 0..<max(store.count, installed.count) {
            let new = index < store.count ? store[index] : 0
            let old = index < installed.count ? installed[index] : 0
            if new != old { return new > old }
        }
        return false
    }

    private struct LookupResponse: Decodable {
        let results: [Release]
    }

    private struct Release: Decodable {
        let trackId: Int
        let bundleId: String
        let version: String
        let trackViewUrl: String?
    }
}
