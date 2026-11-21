import Foundation

@main
struct MerchantAppUpdateChecks {
    @MainActor static func main() async throws {
        precondition(MerchantAppStoreVersionChecker.isNewer("1.10", than: "1.9"))
        precondition(MerchantAppStoreVersionChecker.isNewer("2.0", than: "1.99.9"))
        precondition(!MerchantAppStoreVersionChecker.isNewer("1.4.0", than: "1.4"))
        precondition(!MerchantAppStoreVersionChecker.isNewer("1.3", than: "1.4"))
        precondition(!MerchantAppStoreVersionChecker.isNewer("invalid", than: "1.4"))

        let valid = Data(#"{"results":[{"trackId":6449736851,"bundleId":"com.aait.LohProvider","version":"1.4","trackViewUrl":"https://apps.apple.com/sa/app/loh-provider/id6449736851"}]}"#.utf8)
        let outdated = MerchantAppStoreVersionChecker(installedVersion: "1.3", bundleID: "com.aait.LohProvider", fetch: { valid })
        let outdatedURL = try await outdated.requiredUpdateURL()
        precondition(outdatedURL == MerchantAppStoreVersionChecker.fallbackStoreURL)

        let current = MerchantAppStoreVersionChecker(installedVersion: "1.4", bundleID: "com.aait.LohProvider", fetch: { valid })
        let currentURL = try await current.requiredUpdateURL()
        precondition(currentURL == nil)

        let otherApp = MerchantAppStoreVersionChecker(installedVersion: "1.0", bundleID: "com.aait.LohProviderr", fetch: { valid })
        let otherAppURL = try await otherApp.requiredUpdateURL()
        precondition(otherAppURL == nil)

        let invalidURL = Data(#"{"results":[{"trackId":6449736851,"bundleId":"com.aait.LohProvider","version":"1.4","trackViewUrl":"https://example.com/bad"}]}"#.utf8)
        let fallback = MerchantAppStoreVersionChecker(installedVersion: "1.3", bundleID: "com.aait.LohProvider", fetch: { invalidURL })
        let fallbackURL = try await fallback.requiredUpdateURL()
        precondition(fallbackURL == MerchantAppStoreVersionChecker.fallbackStoreURL)

        let defaults = UserDefaults(suiteName: "MerchantAppUpdateChecks.\(UUID().uuidString)")!
        let gate = MerchantAppUpdateGate(checker: outdated, defaults: defaults)
        await gate.refresh()
        if case .updateRequired = gate.state {} else { preconditionFailure("Old versions must be blocked") }

        let offline = MerchantAppStoreVersionChecker(installedVersion: "1.3", bundleID: "com.aait.LohProvider", fetch: {
            throw URLError(.notConnectedToInternet)
        })
        let relaunched = MerchantAppUpdateGate(checker: offline, defaults: defaults)
        if case .updateRequired = relaunched.state {} else { preconditionFailure("The update gate must survive relaunch") }
        await relaunched.refresh()
        if case .updateRequired = relaunched.state {} else { preconditionFailure("An offline check must keep the gate") }

        let upgraded = MerchantAppUpdateGate(checker: current, defaults: defaults)
        if case .checking = upgraded.state {} else { preconditionFailure("A new installed version must clear the cached block") }
        await upgraded.refresh()
        if case .ready = upgraded.state {} else { preconditionFailure("The current version must open the app") }

        print("Passed: version ordering, trusted App Store URLs, and a forced gate that survives offline relaunch.")
    }
}
