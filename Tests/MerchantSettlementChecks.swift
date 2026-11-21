import Foundation

@main
struct MerchantSettlementChecks {
    @MainActor static func main() {
        let records = MerchantSettlement.samples
        precondition(records.count == 6)
        precondition(Set(records.map(\.id)).count == records.count)
        precondition(records.map(\.transferredHalalas) == [124800, 118000, 98000, 102000, 92000, 75000])
        for record in records {
            precondition(record.salesHalalas == record.commissionHalalas + record.transferredHalalas)
            precondition(MerchantSettlement.find(record.id)?.date == record.date)
            precondition(record.orderCount > 0)
        }
        precondition(zip(records, records.dropFirst()).allSatisfy { $0.date > $1.date })
        precondition(MerchantSettlement.find("missing") == nil)
        precondition(MerchantSettlementFormat.money(124800, arabic: false) == "1,248.00")
        precondition(MerchantSettlementFormat.money(124800, arabic: false, decimals: false) == "1,248")
        precondition(MerchantSettlementFormat.date(records[0].date, arabic: false).contains("Tuesday"))
        precondition(MerchantSettlementFormat.money(124800, arabic: true) != "1,248.00")
        let navigation = MerchantTabsCoordinator()
        navigation.select(.settlements)
        navigation.settlements.push(.settlementDetails(records[2].id))
        navigation.select(.account)
        navigation.select(.settlements)
        precondition(navigation.settlements.path == [.settlementDetails(records[2].id)])
        navigation.settlements.pop()
        precondition(navigation.settlements.path.isEmpty)
        print("Passed: settlement amounts, commission arithmetic, unique record lookup, date order, localized formatting, and detail navigation.")
    }
}
