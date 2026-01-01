import Foundation
import SwiftData

@Model
final class Wallet {
    var id: UUID = UUID()
    var name: String = ""
    var currencyCode: String = "UAH"
    var initialBalance: Decimal = 0
    var currentBalance: Decimal = 0
    var iconName: String = "wallet.pass"
    var colorHex: String = "#007AFF"
    var isArchived: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Monobank integration
    var monobankAccountId: String?
    var monobankIBAN: String?
    var monobankCardType: String?
    var lastSyncDate: Date?

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Transaction.wallet)
    var transactions: [Transaction]?

    @Relationship(inverse: \Transfer.sourceWallet)
    var outgoingTransfers: [Transfer]?

    @Relationship(inverse: \Transfer.destinationWallet)
    var incomingTransfers: [Transfer]?

    init(
        name: String,
        currencyCode: String = "UAH",
        initialBalance: Decimal = 0,
        iconName: String = "wallet.pass",
        colorHex: String = "#007AFF"
    ) {
        self.id = UUID()
        self.name = name
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
        self.currentBalance = initialBalance
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isMonobankLinked: Bool {
        monobankAccountId != nil
    }
}
