import Foundation

@main
struct MerchantLanguageSelectionChecks {
    @MainActor static func main() async {
        let suite = "LOH.LanguageSelection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = AppLanguageManager(defaults: defaults, preferredLanguages: { ["ar-SA"] })
        let draft = MerchantLanguageSelection(current: manager.selectedLanguage)
        draft.select("en")
        precondition(manager.selectedLanguage == "ar", "Selection must stay pending")
        let reopened = MerchantLanguageSelection(current: manager.selectedLanguage)
        precondition(reopened.selected == "ar", "Back without Apply discards the draft")
        var pending: CheckedContinuation<Void, Never>?
        var requests: [String] = []
        let apply = Task {
            await draft.apply(using: manager) { language in
                requests.append(language)
                await withCheckedContinuation { pending = $0 }
            }
        }
        while pending == nil { await Task.yield() }
        precondition(draft.isApplying && draft.applied == nil && manager.selectedLanguage == "ar")
        draft.select("ar")
        precondition(draft.selected == "en", "Selection stays fixed during the request")
        await draft.apply(using: manager) { requests.append($0) }
        precondition(requests == ["en"], "Apply must not send duplicate requests")
        pending!.resume()
        await apply.value
        precondition(manager.selectedLanguage == "en" && draft.applied == "en")
        precondition(!manager.isRTL && !draft.isApplying && draft.error == nil)
        draft.dismissSuccess()
        precondition(draft.applied == nil && manager.selectedLanguage == "en")
        draft.select("ar")
        await draft.apply(using: manager) { _ in throw APIError.offline }
        precondition(manager.selectedLanguage == "en" && draft.applied == nil && draft.error == .offline)
        precondition(draft.selected == "ar" && !draft.isApplying, "Failure preserves the draft for retry")
        await draft.apply(using: manager) { language in requests.append(language) }
        precondition(manager.isRTL && draft.applied == "ar")
        precondition(draft.error == nil && requests == ["en", "ar"])
        draft.select("fr")
        precondition(draft.selected == "ar", "Only supported languages are selectable")
        let relaunched = AppLanguageManager(defaults: defaults, preferredLanguages: { ["ar-SA"] })
        precondition(relaunched.selectedLanguage == "ar")

        draft.select("en")
        await draft.apply(using: manager) { _ in throw CancellationError() }
        precondition(manager.selectedLanguage == "ar" && draft.applied == nil && draft.error == nil)
        pending = nil
        let cancelled = Task {
            await draft.apply(using: manager) { _ in await withCheckedContinuation { pending = $0 } }
        }
        while pending == nil { await Task.yield() }
        cancelled.cancel()
        pending!.resume()
        await cancelled.value
        precondition(manager.selectedLanguage == "ar" && draft.applied == nil && !draft.isApplying)

        pending = nil
        let superseded = Task {
            await draft.apply(using: manager) { _ in await withCheckedContinuation { pending = $0 } }
        }
        while pending == nil { await Task.yield() }
        draft.synchronize(current: "ar")
        pending!.resume()
        await superseded.value
        precondition(draft.selected == "ar" && manager.selectedLanguage == "ar" && draft.applied == nil)
        print("Passed: staged language selection, server-first apply, duplicate prevention, failure/retry, cancellation, superseded draft, success dismissal, and persistence.")
    }
}
