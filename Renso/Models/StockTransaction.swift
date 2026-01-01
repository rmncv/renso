import Foundation
import SwiftData

enum StockTransactionType: String, Codable, CaseIterable {
    case buy
    case sell
    case dividend
    case split
}

@Model
final class StockTransaction {
    var id: UUID = UUID()
    private var typeRaw: String = StockTransactionType.buy.rawValue
    var quantity: Decimal = 0
    var pricePerShare: Decimal = 0
    var totalAmount: Decimal = 0
    var fee: Decimal?
    var currencyCode: String = "USD"
    var date: Date = Date()
    var note: String?
    var createdAt: Date = Date()

    var type: StockTransactionType {
        get { StockTransactionType(rawValue: typeRaw) ?? .buy }
        set { typeRaw = newValue.rawValue }
    }

    // For splits
    var splitRatio: String?

    // Relationships
    var holding: StockHolding?

    var effectiveTotalAmount: Decimal {
        if totalAmount > 0 {
            return totalAmount
        }
        return quantity * pricePerShare + (fee ?? 0)
    }

    init(
        type: StockTransactionType,
        quantity: Decimal,
        pricePerShare: Decimal,
        currencyCode: String = "USD",
        fee: Decimal? = nil,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.quantity = quantity
        self.pricePerShare = pricePerShare
        self.totalAmount = quantity * pricePerShare
        self.currencyCode = currencyCode
        self.fee = fee
        self.date = date
        self.note = note
        self.createdAt = Date()
    }
}
