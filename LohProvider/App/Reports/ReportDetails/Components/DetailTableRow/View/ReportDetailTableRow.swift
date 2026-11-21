import SwiftUI

struct MerchantReportDetailTableRow: View {
    let values: [String]
    let width: CGFloat
    var header = false
    var highlighted = false
    var selected = false
    @ScaledMetric private var rowHeight = 44.0
    @ScaledMetric private var headerHeight = 64.0

    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value).merchantFont(header ? 10 : 12, header || highlighted || selected ? .bold : .medium)
                    .foregroundStyle(header ? MerchantTheme.muted : selected ? MerchantTheme.heading : highlighted ? MerchantTheme.brand : MerchantTheme.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6).padding(.vertical, header ? 10 : 12)
                    .frame(width: (width - 3) / 4, alignment: .center)
                    .frame(minHeight: header ? headerHeight : rowHeight, maxHeight: .infinity, alignment: header ? .top : .center)
                    .background(header ? MerchantTheme.reportTableHeader : selected ? MerchantTheme.brandTint : highlighted ? MerchantTheme.reportTableHighlight : MerchantTheme.surface)
            }
        }.frame(width: width).fixedSize(horizontal: false, vertical: true)
            .background(MerchantTheme.subtle.opacity(0.65))
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 2).fill(MerchantTheme.brand)
                        .frame(width: 3).padding(.vertical, 8)
                }
            }
            .contentShape(Rectangle())
    }
}
