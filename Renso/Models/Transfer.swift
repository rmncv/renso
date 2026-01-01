import Foundation
import SwiftData

@Model
final class Transfer {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var convertedAmount: Decimal?
    var manualExchangeRate: Decimal?
    var note: String?
    var date: Date = Date()
    var createdAt: Date = Date()

    // Relationships
    var sourceWallet: Wallet?
    var destinationWallet: Wallet?

    var hasConversion: Bool {
        convertedAmount != nil || manualExchangeRate != nil
    }

    var effectiveExchangeRate: Decimal? {
        if let rate = manualExchangeRate {
            return rate
        }
        guard let converted = convertedAmount, amount > 0 else { return nil }
        return converted / amount
    }

    init(
        amount: Decimal,
        from source: Wallet,
        to destination: Wallet,
        convertedAmount: Decimal? = nil,
        manualExchangeRate: Decimal? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.sourceWallet = source
        self.destinationWallet = destination
        self.convertedAmount = convertedAmount
        self.manualExchangeRate = manualExchangeRate
        self.note = note
        self.date = Date()
        self.createdAt = Date()
    }
}
