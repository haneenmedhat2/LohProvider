import Foundation

struct MerchantSalesChartScale {
    let domain: ClosedRange<Double>
    let ticks: [Double]

    init(points: [MerchantReportPoint]) {
        let values = points.map { NSDecimalNumber(decimal: $0.value).doubleValue }.filter(\.isFinite)
        let low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 0)
        let rawStep = max(high - low, 1) / 4
        let magnitude = pow(10, floor(log10(rawStep)))
        let multiplier = [1.0, 2, 2.5, 5, 10].first { $0 >= rawStep / magnitude } ?? 10
        let step = multiplier * magnitude
        let bottom = floor(low / step) * step
        let top = high == low ? bottom + step * 4 : max(bottom + step, ceil(high / step) * step)
        domain = bottom...top
        ticks = (0...Int(((top - bottom) / step).rounded())).map { bottom + Double($0) * step }
    }

    static func labelIndices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let step = max(1, Int(ceil(Double(count - 1) / 6)))
        var values = Array(stride(from: 0, to: count, by: step))
        if values.last != count - 1 { values.append(count - 1) }
        return values
    }
}
