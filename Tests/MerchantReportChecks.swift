import Foundation

@main
struct MerchantReportChecks {
    @MainActor static func main() {
        let store = MerchantReportStore.preview()
        let initial = store.snapshot
        precondition(initial.rows.count == 7 && initial.orders == 398)
        precondition(initial.salesHalalas == 269000)
        precondition(initial.offerSales.reduce(0, +) == initial.salesHalalas)
        precondition(initial.averageHalalas == 676)
        precondition(initial.previousOrders > 0 && initial.previousSales > 0)
        precondition(initial.rows.first!.date == initial.period.start && initial.rows.last!.date == initial.period.end)
        for preset in MerchantReportPreset.allCases {
            let period = preset.period(ending: MerchantReportStore.latest)
            precondition(store.apply(period))
            let expected = preset.days ?? 146
            precondition(store.snapshot.rows.count == expected)
            precondition(store.snapshot.rows.allSatisfy { period.contains($0.date) })
            precondition(store.snapshot.orders == store.snapshot.rows.reduce(0) { $0 + $1.orders })
        }
        let prior = store.period
        precondition(!store.apply(.init(start: prior.end, end: prior.start)))
        precondition(store.period == prior, "Invalid ranges must not change the report")
        precondition(store.apply(.init(start: MerchantReportStore.latest, end: MerchantReportStore.latest)))
        precondition(store.snapshot.rows.count == 1 && store.snapshot.orders == 20)
        let zero = MerchantReportSnapshot(period: store.period, rows: [], previousOrders: 0, previousSales: 0)
        precondition(zero.averageHalalas == 0 && zero.salesChange == nil && zero.ordersChange == nil)
        precondition(MerchantReportFormat.money(676, arabic: false) == "6.76")
        precondition(store.apply(MerchantReportPreset.week.period(ending: MerchantReportStore.latest)))
        precondition(store.snapshot.salesHalalas == initial.salesHalalas)
        print("Passed: default period, all presets, inclusive dates, invalid-range preservation, one-day reports, totals, averages, offer totals, comparison data, and reset.")
    }
}
