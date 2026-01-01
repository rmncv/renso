import Foundation
import SwiftData

@Model
final class StockHolding {
    var id: UUID = UUID()
    var symbol: String = ""
    var companyName: String = ""
    var exchange: String?
    var quantity: Decimal = 0
    var averagePurchasePrice: Decimal = 0
    var purchaseCurrencyCode: String = "USD"
    var note: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // API integration
    var lastPrice: Decimal?
    var lastPriceUpdate: Date?
    var yahooTicker: String?

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \StockTransaction.holding)
    var transactions: [StockTransaction]?

    var totalInvested: Decimal {
        quantity * averagePurchasePrice
    }

    var currentValue: Decimal? {
        guard let price = lastPrice else { return nil }
        return quantity * price
    }

    var profitLoss: Decimal? {
        guard let current = currentValue else { return nil }
        return current - totalInvested
    }

    var profitLossPercentage: Decimal? {
        guard let pl = profitLoss, totalInvested > 0 else { return nil }
        return (pl / totalInvested) * 100
    }

    var effectiveTicker: String {
        yahooTicker ?? symbol
    }

    init(
        symbol: String,
        companyName: String,
        exchange: String? = nil,
        quantity: Decimal = 0,
        averagePurchasePrice: Decimal = 0,
        purchaseCurrencyCode: String = "USD"
    ) {
        self.id = UUID()
        self.symbol = symbol.uppercased()
        self.companyName = companyName
        self.exchange = exchange
        self.quantity = quantity
        self.averagePurchasePrice = averagePurchasePrice
        self.purchaseCurrencyCode = purchaseCurrencyCode
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func recalculateAveragePrice() {
        guard let txns = transactions, !txns.isEmpty else { return }

        var totalQuantity: Decimal = 0
        var totalCost: Decimal = 0

        for txn in txns.sorted(by: { $0.date < $1.date }) {
            switch txn.type {
            case .buy:
                totalCost += txn.quantity * txn.pricePerShare
                totalQuantity += txn.quantity
            case .sell:
                if totalQuantity > 0 {
                    let avgCost = totalCost / totalQuantity
                    totalCost -= txn.quantity * avgCost
                    totalQuantity -= txn.quantity
                }
            case .dividend, .split:
                break
            }
        }

        quantity = totalQuantity
        averagePurchasePrice = totalQuantity > 0 ? totalCost / totalQuantity : 0
        updatedAt = Date()
    }
}
