import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum MerchantReportPDF {
    /// Draw a paginated report from the exact snapshot displayed by the app.
    static func render(_ report: MerchantReportSnapshot, arabic: Bool) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: merchantString("report_sales_report", arabic: arabic),
                               kCGPDFContextCreator as String: "LOH Provider"]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        func label(_ key: String) -> String { merchantString(key, arabic: arabic) }
        func draw(_ text: String, in rect: CGRect, size: CGFloat = 11, bold: Bool = false, color: UIColor = .darkGray) {
            let style = NSMutableParagraphStyle()
            style.alignment = arabic ? .right : .left
            style.baseWritingDirection = arabic ? .rightToLeft : .leftToRight
            let name = (arabic ? "Cairo" : "Poppins") + (bold ? "-Bold" : "-Regular")
            let font = UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
            (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        }
        return renderer.pdfData { context in
            var page = 0
            var y: CGFloat = 0
            func beginPage() {
                context.beginPage(); page += 1
                UIColor.white.setFill(); context.fill(bounds)
                draw(label("report_sales_report"), in: CGRect(x: 32, y: 28, width: 531, height: 32), size: 21, bold: true)
                draw(MerchantReportFormat.period(report.period, arabic: arabic), in: CGRect(x: 32, y: 65, width: 531, height: 25))
                draw(label("report_orders") + ": \(report.orders)    " + label("report_sales") + ": " + MerchantReportFormat.money(report.salesHalalas, arabic: arabic) + " " + label("settlement_currency"), in: CGRect(x: 32, y: 98, width: 531, height: 30), bold: true)
                draw(label("report_average") + ": " + MerchantReportFormat.money(report.averageHalalas, arabic: arabic) + " " + label("settlement_currency"), in: CGRect(x: 32, y: 130, width: 531, height: 25))
                let headers = [label("report_date"), label("report_orders_short"), label("report_sales"), label("report_average")]
                for index in 0..<4 { draw(headers[index], in: CGRect(x: 32 + CGFloat(index) * 133, y: 172, width: 125, height: 38), size: 10, bold: true) }
                draw(label("report_demo_footer") + " · \(page)", in: CGRect(x: 32, y: 795, width: 531, height: 24), size: 9)
                y = 220
            }
            beginPage()
            for day in report.rows {
                if Task.isCancelled { break }
                if y > 740 { beginPage() }
                let values = [MerchantReportFormat.date(day.date, arabic: arabic), String(day.orders), MerchantReportFormat.money(day.salesHalalas, arabic: arabic), MerchantReportFormat.money(day.averageHalalas, arabic: arabic)]
                for index in 0..<4 { draw(values[index], in: CGRect(x: 32 + CGFloat(index) * 133, y: y, width: 125, height: 30)) }
                UIColor(white: 0.93, alpha: 1).setFill()
                context.fill(CGRect(x: 32, y: y + 32, width: 531, height: 0.5))
                y += 38
            }
        }
    }
}
