import Foundation

@main struct MerchantReportChartChecks {
    @MainActor static func main() throws {
        let values: [Decimal] = [120, 270, 440, 390, 510, 430, 642]
        let points = values.enumerated().map { index, value in
            MerchantReportPoint(date: "2026-05-\(20 + index)", label: "May \(20 + index)", value: value)
        }
        let scale = MerchantSalesChartScale(points: points)
        precondition(scale.domain == 0...800 && scale.ticks == [0, 200, 400, 600, 800])
        precondition(MerchantSalesChartScale.labelIndices(count: 7) == Array(0..<7))
        let monthLabels = MerchantSalesChartScale.labelIndices(count: 31)
        precondition(monthLabels.first == 0 && monthLabels.last == 30 && monthLabels.count <= 8)
        precondition(MerchantSalesChartScale.labelIndices(count: 0).isEmpty)
        precondition(MerchantSalesChartScale.labelIndices(count: 1) == [0])
        let zero = MerchantSalesChartScale(points: [.init(date: "2026-01", label: "January", value: 0)])
        precondition(zero.domain == 0...1 && zero.ticks.count == 5)
        let negative = MerchantSalesChartScale(points: [.init(date: "2026-01", label: "January", value: -125)])
        precondition(negative.domain.contains(-125) && negative.domain.contains(0))
        precondition(MerchantReportOverview.number(1248) == "1,248")
        precondition(MerchantReportOverview.number(Decimal(string: "1248.005")!) == "1,248.005")

        let model = MerchantSalesChartViewModel()
        model.select(at: 2)
        precondition(model.selectedPoint == nil)
        model.update(points: points)
        model.select(at: 1.8)
        precondition(model.selectedIndex == 2 && model.selectedPoint?.value == 440)
        model.select(at: 2.49, toggle: true)
        precondition(model.selectedIndex == nil)
        model.select(at: -20)
        precondition(model.selectedIndex == 0)
        model.select(at: 1e100)
        precondition(model.selectedPoint?.value == 642)
        model.move(forward: false)
        precondition(model.selectedIndex == 5)
        model.clear(); model.move(forward: true)
        precondition(model.selectedIndex == 0)
        model.clear(); model.move(forward: false)
        precondition(model.selectedIndex == 6)
        model.update(points: points)
        precondition(model.selectedIndex == 6, "Unchanged refresh should retain a valid selection")
        model.update(points: [.init(date: "2026-06", label: "June", value: Decimal(string: "0.01")!)])
        precondition(model.selectedPoint == nil, "Changing period/data must clear the previous point")
        model.select(at: 0)
        precondition(model.selectedPoint?.value == Decimal(string: "0.01"))
        model.select(at: .nan)
        precondition(model.selectedIndex == nil)
        model.select(at: .infinity)
        precondition(model.selectedIndex == nil)
        model.update(points: [])
        model.move(forward: true)
        precondition(model.selectedPoint == nil)

        let data = try Data(contentsOf: URL(fileURLWithPath: "Tests/Fixtures/MerchantReport.json"))
        let envelope = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let summary = try JSONDecoder().decode(MerchantReportSummary.self, from: JSONSerialization.data(withJSONObject: envelope["data"]!))
        let overview = MerchantReportOverview(report: summary)
        precondition(overview.currency == summary.stats.currency && overview.points == summary.chart.points)
        precondition(overview.sales.total == summary.stats.sales.total && overview.orders.total == summary.stats.orders.total)
        print("Passed: report presentation, exact values, chart scales, nearest-point selection, dismiss/toggle, accessibility navigation, and data-change resets.")
    }
}
