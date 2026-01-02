import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID = UUID()
    var externalId: String?
    var amount: Decimal = 0
    var originalAmount: Decimal?
    var originalCurrencyCode: String?
    var transactionDescription: String = ""
    var note: String?
    var date: Date = Date()
    var isHold: Bool = false
    var mcc: Int?
    var cashbackAmount: Decimal?
    var commissionAmount: Decimal?
    var balanceAfter: Decimal?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    /// Indicates this transaction was synced from a bank (Monobank)
    /// Bank transactions cannot be edited or deleted by the user
    var isFromBank: Bool = false

    // Relationships
    var wallet: Wallet?
    var category: Category?
    var subCategory: SubCategory?
    var rule: Rule?

    // Refund linking - if this is an income marked as refund for an expense category
    var refundForCategory: Category?

    var isExpense: Bool {
        amount < 0
    }

    var isIncome: Bool {
        amount > 0
    }

    var isRefund: Bool {
        refundForCategory != nil
    }

    var absoluteAmount: Decimal {
        abs(amount)
    }
    
    /// Bank transactions cannot be edited or deleted
    var isEditable: Bool {
        !isFromBank
    }

    init(
        amount: Decimal,
        description: String,
        date: Date = Date(),
        mcc: Int? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.transactionDescription = description
        self.date = date
        self.mcc = mcc
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
