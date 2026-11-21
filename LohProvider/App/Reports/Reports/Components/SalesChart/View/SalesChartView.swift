import SwiftUI
import Charts

struct MerchantSalesChartView: View {
    @Environment(\.locale) private var locale
    @StateObject private var selection = MerchantSalesChartViewModel()
    let points: [MerchantReportPoint]
    let currency: String
    private var arabic: Bool { locale.language.languageCode?.identifier == "ar" }

    private func chartIndex(_ index: Int) -> Double {
        Double(arabic ? points.count - 1 - index : index)
    }

    var body: some View {
        Group {
            if points.isEmpty {
                Text(merchantString("report_no_sales", locale: locale)).merchantFont(14).foregroundStyle(MerchantTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 214)
            } else { chart }
        }
        .onAppear { selection.update(points: points) }
        .onChange(of: points) { selection.update(points: $0) }
    }

    private var chart: some View {
        let scale = MerchantSalesChartScale(points: points)
        return Chart { marks }
        .chartXAxis {
            AxisMarks(values: MerchantSalesChartScale.labelIndices(count: points.count).map(chartIndex)) { value in
                AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled) {
                    if let coordinate = value.as(Double.self) {
                        let index = arabic ? points.count - 1 - Int(coordinate) : Int(coordinate)
                        if points.indices.contains(index) {
                            Text(points[index].label).merchantFont(9).foregroundStyle(MerchantTheme.muted)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: scale.ticks) { value in
                AxisGridLine().foregroundStyle(MerchantTheme.subtle)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.locale(Locale(identifier: "en_US"))))
                            .merchantFont(9).foregroundStyle(MerchantTheme.muted)
                    }
                }
            }
        }
        .chartYScale(domain: scale.domain)
        .chartXScale(domain: points.count == 1 ? -0.5...0.5 : 0...Double(points.count - 1), range: .plotDimension(padding: 6))
        .chartOverlay { proxy in chartOverlay(proxy) }
        .frame(height: 214)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(merchantString("report_sales_heading", locale: locale))
        .accessibilityValue(selection.selectedPoint.map { $0.label + ", " + $0.date + ", " + MerchantReportOverview.number($0.value) + " " + currency } ?? merchantString("report_chart_hint", locale: locale))
        .accessibilityHint(merchantString("report_chart_accessibility_hint", locale: locale))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selection.move(forward: true)
            case .decrement: selection.move(forward: false)
            @unknown default: break
            }
        }
        .accessibilityAction(named: Text(merchantString("report_clear_selection", locale: locale))) { selection.clear() }
        .accessibilityIdentifier("merchantSalesChart")
    }

    @ChartContentBuilder
    private var marks: some ChartContent {
        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
            let value = NSDecimalNumber(decimal: point.value).doubleValue
            AreaMark(x: .value("Period", chartIndex(index)), y: .value("Sales", value))
                .foregroundStyle(LinearGradient(colors: [MerchantTheme.success.opacity(0.2), MerchantTheme.success.opacity(0.01)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Period", chartIndex(index)), y: .value("Sales", value))
                .foregroundStyle(MerchantTheme.success).lineStyle(StrokeStyle(lineWidth: 2.5))
            if points.count <= 31 || selection.selectedIndex == index {
                PointMark(x: .value("Period", chartIndex(index)), y: .value("Sales", value))
                    .symbol {
                        Circle().fill(MerchantTheme.success)
                            .frame(width: selection.selectedIndex == index ? 11 : 8, height: selection.selectedIndex == index ? 11 : 8)
                            .overlay(Circle().stroke(MerchantTheme.surface, lineWidth: 1.5))
                    }
            }
        }
        if let index = selection.selectedIndex, points.indices.contains(index) {
            RuleMark(x: .value("Selected period", chartIndex(index)))
                .foregroundStyle(MerchantTheme.success.opacity(0.45)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    private func chartOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            let plot = geometry[proxy.plotAreaFrame]
            Rectangle().fill(.clear).contentShape(Rectangle())
                .onTapGesture(count: 1, coordinateSpace: .local) { location in
                    guard plot.contains(location) else { selection.clear(); return }
                    select(location, plot: plot, proxy: proxy, toggle: true)
                }
                .simultaneousGesture(DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard plot.contains(value.startLocation), abs(value.translation.width) >= abs(value.translation.height) else { return }
                        select(value.location, plot: plot, proxy: proxy)
                    })
            if let index = selection.selectedIndex, let point = selection.selectedPoint,
               let x = proxy.position(forX: chartIndex(index)) {
                let width = min(180.0, plot.width)
                MerchantSalesChartSelectionView(point: point, currency: currency) { selection.clear() }
                    .environment(\.layoutDirection, locale.language.languageCode?.identifier == "ar" ? .rightToLeft : .leftToRight)
                    .frame(width: width)
                    .position(x: min(max(plot.minX + x, width / 2), geometry.size.width - width / 2), y: 42)
            }
        }
    }

    private func select(_ location: CGPoint, plot: CGRect, proxy: ChartProxy, toggle: Bool = false) {
        let x = min(max(location.x - plot.minX, 0), plot.width)
        guard let coordinate = proxy.value(atX: x, as: Double.self) else { return }
        selection.select(at: arabic ? Double(points.count - 1) - coordinate : coordinate, toggle: toggle)
    }
}
