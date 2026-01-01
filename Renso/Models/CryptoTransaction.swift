import Foundation
import SwiftData

enum CryptoTransactionType: String, Codable, CaseIterable {
    case buy
    case sell
    case transfer
}

@Model
final class CryptoTransaction {
    var id: UUID = UUID()
    private var typeRaw: String = CryptoTransactionType.buy.rawValue
    var quantity: Decimal = 0
    var pricePerUnit: Decimal = 0
    var totalAmount: Decimal = 0
    var fee: Decimal?
    var currencyCode: String = "USD"
    var date: Date = Date()
    var note: String?
    var createdAt: Date = Date()

    var type: CryptoTransactionType {
        get { CryptoTransactionType(rawValue: typeRaw) ?? .buy }
        set { typeRaw = newValue.rawValue }
    }

    // Relationships
    var holding: CryptoHolding?

    var effectiveTotalAmount: Decimal {
        if totalAmount > 0 {
            return totalAmount
        }
        return quantity * pricePerUnit + (fee ?? 0)
    }

    init(
        type: CryptoTransactionType,
        quantity: Decimal,
        pricePerUnit: Decimal,
        currencyCode: String = "USD",
        fee: Decimal? = nil,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.totalAmount = quantity * pricePerUnit
        self.currencyCode = currencyCode
        self.fee = fee
        self.date = date
        self.note = note
        self.createdAt = Date()
    }
}
