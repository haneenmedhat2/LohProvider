//
//  Language.swift
//  NewSwiftUIBase
//
//  Created by Mohamed Hadwa on 22/07/2025.
//

import Foundation
import SwiftUI

class AppLanguageManager: ObservableObject {
    static let shared = AppLanguageManager()
    private static let overrideKey = "merchantLanguageOverride"
    private static let systemKey = "merchantSystemLanguage"
    private let defaults: UserDefaults
    private let preferredLanguages: () -> [String]

    @Published private(set) var selectedLanguage: String

    init(defaults: UserDefaults = .standard,
         preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages }) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
        let system = Self.resolve(preferredLanguages())
        // The old selectedLanguage key was seeded with English, not necessarily chosen.
        if defaults.string(forKey: Self.systemKey) == system,
           let selection = defaults.string(forKey: Self.overrideKey),
           ["ar", "en"].contains(selection) {
            selectedLanguage = selection
        } else {
            selectedLanguage = system
            defaults.removeObject(forKey: Self.overrideKey)
        }
        defaults.set(system, forKey: Self.systemKey)
    }

    static func resolve(_ preferences: [String]) -> String {
        for preference in preferences {
            let code = preference.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first.map(String.init)
            if let code, code == "ar" || code == "en" { return code }
        }
        return "en"
    }

    func refreshSystemLanguage() {
        let system = Self.resolve(preferredLanguages())
        guard defaults.string(forKey: Self.systemKey) != system else { return }
        defaults.removeObject(forKey: Self.overrideKey)
        defaults.set(system, forKey: Self.systemKey)
        selectedLanguage = system
    }

    enum Languages {
        static let en = "en"
        static let ar = "ar"
    }

    static func currentLanguage() -> String { shared.selectedLanguage }
    static func setAppLanguage(lang: String) { shared.setLanguage(lang) }
    static func apiLanguage() -> String { shared.apiLanguage }
    static func currentLang() -> appLanguage { shared.isRTL ? .arabic : .english }
    static func isRTL() -> Bool { shared.isRTL }
    var apiLanguage: String { selectedLanguage }
    var isRTL: Bool { selectedLanguage == "ar" }
    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }

    func toggleLanguage() { setLanguage(isRTL ? "en" : "ar") }

    func setLanguage(_ language: String) {
        let code = Self.resolve([language])
        defaults.set(code, forKey: Self.overrideKey)
        defaults.set(Self.resolve(preferredLanguages()), forKey: Self.systemKey)
        selectedLanguage = code
        // Do not write AppleLanguages: that preference is managed by iOS Settings.
    }

    var localizationBundle: Bundle {
        Bundle.main.path(forResource: selectedLanguage, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, bundle: AppLanguageManager.shared.localizationBundle, comment: "")
    }
    var validationLocalized: String {
        return NSLocalizedString(self, tableName: "ValidationLocalized", bundle: AppLanguageManager.shared.localizationBundle, value: "", comment: "")
    }
    var helperLocalizable: String {
        return NSLocalizedString(self, tableName: "HelperLocalizable", bundle: AppLanguageManager.shared.localizationBundle, value: "", comment: "")
    }
    
}
enum appLanguage: String {
    case english = "en"
    case arabic = "ar"
}

