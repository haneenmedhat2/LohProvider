import SwiftUI

struct MerchantReportExportPDFIcon: View {
    var body: some View {
        ZStack {
            Image("LOHReportExportPDFPage").frame(width: 37, height: 41)
            Image("LOHReportExportPDFBand").frame(width: 36, height: 12).offset(y: 14)
            Text("PDF").font(.system(size: 8, weight: .bold)).foregroundStyle(.white).offset(y: 15)
            Image("LOHReportExportPDFLines").frame(width: 24, height: 18).clipped().offset(y: -3)
            Image("LOHReportExportPDFFold").frame(width: 8.5, height: 6.5).offset(x: 7.75, y: -8.75)
        }.frame(width: 36, height: 40).clipped().environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}
