import Foundation
import SwiftData

enum WalletType: String, Codable, CaseIterable {
    case bankAccount = "bank_account"
    case cash
    case stocks
    case crypto
    case other

    var displayName: String {
        switch self {
        case .bankAccount: return "Bank Account"
        case .cash: return "Cash"
        case .stocks: return "Stocks"
        case .crypto: return "Crypto"
        case .other: return "Other"
        }
    }

    var defaultIcon: String {
        switch self {
        case .bankAccount: return "building.columns"
        case .cash: return "banknote"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .crypto: return "bitcoinsign.circle"
        case .other: return "wallet.pass"
        }
    }
}

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

    // Wallet type with raw value storage for SwiftData compatibility
    private var walletTypeRaw: String = WalletType.other.rawValue
    var walletType: WalletType {
        get { WalletType(rawValue: walletTypeRaw) ?? .other }
        set { walletTypeRaw = newValue.rawValue }
    }

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
        walletType: WalletType = .other,
        iconName: String? = nil,
        colorHex: String = "#007AFF"
    ) {
        self.id = UUID()
        self.name = name
        self.currencyCode = currencyCode
        self.initialBalance = initialBalance
        self.currentBalance = initialBalance
        self.walletType = walletType
        self.iconName = iconName ?? walletType.defaultIcon
        self.colorHex = colorHex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isMonobankLinked: Bool {
        monobankAccountId != nil
    }

    /// Display name for UI (e.g., "monobank black UAH")
    var displayName: String {
        "\(name) \(currencyCode)"
    }
}
