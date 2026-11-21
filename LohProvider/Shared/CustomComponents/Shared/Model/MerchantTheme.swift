import SwiftUI
import UIKit

enum MerchantTheme {
    static let brand = Color("LOHBrand")
    static let background = Color("LOHBackground")
    static let notificationCanvas = Color("LOHNotificationCanvas")
    static let loginBackground = Color("LOHLoginBackground")
    static let surface = Color("LOHSurface")
    static let heading = Color("LOHHeading")
    static let ink = Color("LOHInk")
    static let body = Color("LOHBody")
    static let secondary = Color("LOHSecondary")
    static let muted = Color("LOHMuted")
    static let border = Color("LOHBorder")
    static let brandTint = Color("LOHBrandTint")
    static let subtle = Color("LOHSubtle")
    static let placeholder = Color("LOHPlaceholder")
    static let success = Color("LOHSuccess")
    static let successTint = Color("LOHSuccessTint")
    static let reportOrdersTint = Color("LOHReportOrdersTint")
    static let reportTableHeader = Color("LOHReportTableHeader")
    static let reportTableHighlight = Color("LOHReportTableHighlight")
    static let reportPDFTint = Color("LOHReportPDFTint")
    static let error = Color("LOHError")

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    enum Radius {
        static let field: CGFloat = 12
        static let button: CGFloat = 14
        static let card: CGFloat = 16
        static let loginCard: CGFloat = 20
    }
}

enum MerchantFontWeight: String {
    case regular = "Regular", medium = "Medium", semibold = "SemiBold"
    case bold = "Bold", extraBold = "ExtraBold", black = "Black"

    var systemWeight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold, .extraBold: return .bold
        case .black: return .black
        }
    }
}

enum MerchantTypography {
    static func font(_ size: CGFloat, weight: MerchantFontWeight = .regular, arabic: Bool) -> Font {
        let suffix: String
        switch weight {
        case .bold: suffix = "Bold"
        case .regular, .medium, .semibold, .extraBold, .black: suffix = weight.rawValue
        }
        let name = "\(arabic ? "Cairo" : "Poppins")-\(suffix)"
        // Poppins is selected once its font files are bundled and registered in UIAppFonts.
        guard UIFont(name: name, size: size) != nil else {
            return .system(size: size, weight: weight.systemWeight, design: .rounded)
        }
        return .custom(name, size: size)
    }
}

/// A dedicated table avoids collisions with legacy localization keys.
func merchantString(_ key: String, arabic: Bool) -> String {
    let code = arabic ? "ar" : "en"
    let bundle = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    return bundle.localizedString(forKey: key, value: key, table: "Merchant")
}

/// Resolve merchant strings from the locale injected by the application root.
func merchantString(_ key: String, locale: Locale) -> String {
    merchantString(key, arabic: locale.language.languageCode?.identifier == "ar")
}
