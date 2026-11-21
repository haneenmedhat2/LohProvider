import SwiftUI

struct MerchantStatusBadge: View {
    enum Kind { case success, warning, error, neutral }
    let title: String
    var kind: Kind = .success
    var prominent = false
    private var color: Color {
        switch kind {
        case .success: return MerchantTheme.success
        case .warning: return MerchantTheme.brand
        case .error: return MerchantTheme.error
        case .neutral: return MerchantTheme.muted
        }
    }
    private var fill: Color {
        if prominent, case .success = kind { return MerchantTheme.successTint }
        return color.opacity(0.09)
    }
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).merchantFont(12, .semibold)
        }
        .foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 4)
        .background(fill, in: Capsule())
    }
}
