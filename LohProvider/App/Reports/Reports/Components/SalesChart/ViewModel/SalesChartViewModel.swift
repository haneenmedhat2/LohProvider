import Foundation
import Combine

@MainActor
final class MerchantSalesChartViewModel: ObservableObject {
    @Published private(set) var selectedIndex: Int?
    private var points: [MerchantReportPoint] = []
    var selectedPoint: MerchantReportPoint? {
        guard let selectedIndex, points.indices.contains(selectedIndex) else { return nil }
        return points[selectedIndex]
    }

    func update(points: [MerchantReportPoint]) {
        guard self.points != points else { return }
        self.points = points
        clear()
    }

    func select(at coordinate: Double, toggle: Bool = false) {
        guard coordinate.isFinite, !points.isEmpty else { clear(); return }
        let index = Int(min(max(coordinate.rounded(), 0), Double(points.count - 1)))
        selectedIndex = toggle && selectedIndex == index ? nil : index
    }

    func move(forward: Bool) {
        guard !points.isEmpty else { return }
        let index = selectedIndex.map { $0 + (forward ? 1 : -1) } ?? (forward ? 0 : points.count - 1)
        select(at: Double(index))
    }

    func clear() { selectedIndex = nil }
}
