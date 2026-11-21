import Foundation

@main
struct AppLanguageChecks {
    static func main() {
        let name = "LOH.LanguageChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var preferences = ["ar-SA", "en-US"]
        defaults.set("en", forKey: "selectedLanguage")
        let manager = AppLanguageManager(defaults: defaults, preferredLanguages: { preferences })
        precondition(manager.selectedLanguage == "ar" && manager.isRTL, "Arabic must win over legacy English default")
        precondition(AppLanguageManager.resolve(["ar_EG"]) == "ar")
        precondition(AppLanguageManager.resolve(["en-GB", "ar"]) == "en")
        precondition(AppLanguageManager.resolve(["fr-FR", "ar-SA"]) == "ar")
        precondition(AppLanguageManager.resolve([]) == "en")
        manager.setLanguage("en")
        let relaunched = AppLanguageManager(defaults: defaults, preferredLanguages: { preferences })
        precondition(relaunched.selectedLanguage == "en", "Explicit choice persists")
        preferences = ["en-US", "ar-SA"]
        manager.refreshSystemLanguage()
        manager.setLanguage("en")
        preferences = ["ar-SA", "en-US"]
        manager.refreshSystemLanguage()
        precondition(manager.selectedLanguage == "ar" && manager.isRTL, "Settings change must supersede in-app choice")
        let afterSettings = AppLanguageManager(defaults: defaults, preferredLanguages: { preferences })
        precondition(afterSettings.selectedLanguage == "ar")
        precondition(defaults.persistentDomain(forName: name)?["AppleLanguages"] == nil, "App must not overwrite iOS language preferences")
        print("Passed: device/app language, regional codes, stale English migration, explicit selection, Settings changes, and RTL.")
    }
}
