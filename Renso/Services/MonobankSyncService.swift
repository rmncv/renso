import Foundation
import SwiftData

enum MonobankSyncError: LocalizedError {
    case noToken
    case apiError(Error)
    case noAccounts
    case invalidData
    case walletNotFound

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Monobank token not configured"
        case .apiError(let error):
            return "API error: \(error.localizedDescription)"
        case .noAccounts:
            return "No accounts found"
        case .invalidData:
            return "Invalid data received from Monobank"
        case .walletNotFound:
            return "Wallet not found for account"
        }
    }
}

@MainActor
final class MonobankSyncService {
    private let modelContext: ModelContext
    private let apiClient: MonobankAPIClient
    private let rulesEngine: RulesEngine
    private let converter: CurrencyConverter
    
    /// Cached client info after successful validation
    private(set) var clientInfo: MonobankClientInfo?

    init(modelContext: ModelContext, token: String? = nil) {
        self.modelContext = modelContext
        // Use provided token, or fall back to Secrets configuration
        let effectiveToken = token ?? Secrets.monobankToken
        self.apiClient = MonobankAPIClient(token: effectiveToken)
        self.rulesEngine = RulesEngine(modelContext: modelContext)
        self.converter = CurrencyConverter(modelContext: modelContext)
    }

    func setToken(_ token: String) {
        apiClient.setToken(token)
    }
    
    // MARK: - Token Validation
    
    /// Validates the configured token by fetching client info
    /// Returns the client info if successful, throws on failure
    @discardableResult
    func validateToken() async throws -> MonobankClientInfo {
        let info = try await apiClient.getClientInfo()
        self.clientInfo = info
        return info
    }
    
    /// Check if the token is configured
    var hasToken: Bool {
        !Secrets.monobankToken.isEmpty
    }
    
    /// Get client name if available
    var clientName: String? {
        clientInfo?.name
    }
    
    /// Get number of accounts
    var accountsCount: Int {
        clientInfo?.accounts.count ?? 0
    }

    // MARK: - Full Sync

    /// Perform full sync: accounts + transactions + currency rates
    func performFullSync() async throws -> SyncResult {
        let startTime = Date()

        // Step 1: Sync currency rates (public endpoint, no rate limit)
        try await syncCurrencyRates()

        // Step 2: Sync accounts (requires token)
        let accounts = try await syncAccounts()

        guard !accounts.isEmpty else {
            throw MonobankSyncError.noAccounts
        }

        // Step 3: Sync transactions for each account
        var totalTransactions = 0

        for account in accounts {
            let count = try await syncTransactions(for: account)
            totalTransactions += count
        }

        let duration = Date().timeIntervalSince(startTime)

        // Update last sync time in UserSettings
        updateLastSyncTime()

        return SyncResult(
            accountsCount: accounts.count,
            transactionsCount: totalTransactions,
            duration: duration
        )
    }

    // MARK: - Sync Currency Rates

    func syncCurrencyRates() async throws {
        let rates = try await apiClient.getCurrencyRates()

        for rate in rates {
            // Convert numeric currency codes to alpha codes
            guard let fromCode = ISO4217.alphaCode(for: rate.currencyCodeA),
                  let toCode = ISO4217.alphaCode(for: rate.currencyCodeB) else {
                continue
            }

            // Use cross rate if available, otherwise calculate from buy/sell
            let effectiveRate: Decimal
            if let cross = rate.rateCross {
                effectiveRate = Decimal(cross)
            } else if let buy = rate.rateBuy, let sell = rate.rateSell {
                effectiveRate = Decimal((buy + sell) / 2)
            } else {
                continue
            }

            converter.saveRate(
                from: fromCode,
                to: toCode,
                rate: effectiveRate,
                buyRate: rate.rateBuy.map { Decimal($0) },
                sellRate: rate.rateSell.map { Decimal($0) },
                source: "monobank"
            )
        }
    }

    // MARK: - Sync Accounts

    func syncAccounts() async throws -> [Wallet] {
        let clientInfo = try await apiClient.getClientInfo()

        var syncedWallets: [Wallet] = []

        for account in clientInfo.accounts {
            let wallet = try await syncAccount(account)
            syncedWallets.append(wallet)
        }

        try modelContext.save()

        return syncedWallets
    }

    private func syncAccount(_ account: MonobankAccount) async throws -> Wallet {
        // Check if wallet already exists
        let descriptor = FetchDescriptor<Wallet>()
        let allWallets = try? modelContext.fetch(descriptor)
        let existingWallet = allWallets?.first { $0.monobankAccountId == account.id }

        let wallet: Wallet

        if let existing = existingWallet {
            // Update existing wallet
            wallet = existing
            wallet.monobankIBAN = account.iban
            wallet.monobankCardType = account.type
        } else {
            // Create new wallet
            guard let currencyCode = ISO4217.alphaCode(for: account.currencyCode) else {
                throw MonobankSyncError.invalidData
            }

            let balance = ISO4217.fromMinorUnits(account.balance, currencyCode: currencyCode)
            let walletName = generateWalletName(account: account, currencyCode: currencyCode)

            wallet = Wallet(
                name: walletName,
                currencyCode: currencyCode,
                initialBalance: balance,
                walletType: .bankAccount
            )

            wallet.monobankAccountId = account.id
            wallet.monobankIBAN = account.iban
            wallet.monobankCardType = account.type

            modelContext.insert(wallet)
        }

        // Update balance and sync time
        let currentBalance = ISO4217.fromMinorUnits(account.balance, currencyCode: wallet.currencyCode)
        wallet.currentBalance = currentBalance
        wallet.lastSyncDate = Date()

        return wallet
    }
    
    /// Generate a user-friendly wallet name from Monobank account info
    /// Format: "Monobank {CardType} {Currency}" e.g. "Monobank Black UAH"
    private func generateWalletName(account: MonobankAccount, currencyCode: String) -> String {
        let cardType = formatCardType(account.type)
        return "Monobank \(cardType) \(currencyCode)"
    }
    
    /// Format card type to proper case
    private func formatCardType(_ type: String) -> String {
        let typeMapping: [String: String] = [
            "black": "Black",
            "white": "White",
            "platinum": "Platinum",
            "iron": "Iron",
            "fop": "FOP",
            "yellow": "Yellow",
            "eAid": "eAid",
            "rebuilding": "Rebuilding"
        ]
        return typeMapping[type.lowercased()] ?? type.capitalized
    }

    // MARK: - Queue-Based Sync Methods
    
    /// Sync accounts from already-fetched client info (used by SyncQueueService)
    func syncAccountsFromClientInfo(_ clientInfo: MonobankClientInfo) async throws -> [Wallet] {
        self.clientInfo = clientInfo
        
        var syncedWallets: [Wallet] = []
        
        for account in clientInfo.accounts {
            let wallet = try await syncAccount(account)
            syncedWallets.append(wallet)
        }
        
        try modelContext.save()
        
        return syncedWallets
    }
    
    /// Sync transactions for a specific account by ID (used by SyncQueueService)
    func syncTransactionsForAccount(accountId: String, daysBack: Int = 30) async throws -> Int {
        // Find the wallet for this account
        let descriptor = FetchDescriptor<Wallet>()
        let allWallets = try modelContext.fetch(descriptor)
        
        guard let wallet = allWallets.first(where: { $0.monobankAccountId == accountId }) else {
            throw MonobankSyncError.walletNotFound
        }
        
        let to = Int64(Date().timeIntervalSince1970)
        let from = to - Int64(daysBack * 24 * 60 * 60)
        
        let statements = try await apiClient.getStatement(
            accountId: accountId,
            from: from,
            to: to
        )
        
        var newTransactionsCount = 0
        
        for statement in statements {
            if try await createOrUpdateTransaction(from: statement, wallet: wallet) {
                newTransactionsCount += 1
            }
        }
        
        try modelContext.save()
        
        // Apply rules to new transactions
        if newTransactionsCount > 0 {
            let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
            let uncategorized = allTransactions.filter { $0.wallet?.id == wallet.id && $0.category == nil }
            rulesEngine.applyRules(to: uncategorized)
        }
        
        // Update last sync time
        updateLastSyncTime()
        
        return newTransactionsCount
    }

    // MARK: - Sync Transactions

    func syncTransactions(for wallet: Wallet, daysBack: Int = 30) async throws -> Int {
        guard let accountId = wallet.monobankAccountId else {
            return 0
        }

        let to = Int64(Date().timeIntervalSince1970)
        let from = to - Int64(daysBack * 24 * 60 * 60)

        let statements = try await apiClient.getStatement(
            accountId: accountId,
            from: from,
            to: to
        )

        var newTransactionsCount = 0

        for statement in statements {
            if try await createOrUpdateTransaction(from: statement, wallet: wallet) {
                newTransactionsCount += 1
            }
        }

        try modelContext.save()

        // Apply rules to new transactions
        if newTransactionsCount > 0 {
            let allTransactions = try modelContext.fetch(FetchDescriptor<Transaction>())
            let uncategorized = allTransactions.filter { $0.wallet?.id == wallet.id && $0.category == nil }
            rulesEngine.applyRules(to: uncategorized)
        }

        return newTransactionsCount
    }

    private func createOrUpdateTransaction(
        from statement: MonobankStatementItem,
        wallet: Wallet
    ) async throws -> Bool {
        // Check if transaction already exists
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = try? modelContext.fetch(descriptor)
        let existing = allTransactions?.first { $0.externalId == statement.id }

        if let existing = existing {
            // Update existing transaction
            existing.isHold = statement.hold
            existing.balanceAfter = ISO4217.fromMinorUnits(statement.balance, currencyCode: wallet.currencyCode)
            return false
        }

        // Create new transaction
        let amount = ISO4217.fromMinorUnits(statement.amount, currencyCode: wallet.currencyCode)
        let originalAmount = ISO4217.fromMinorUnits(
            statement.operationAmount,
            currencyCode: ISO4217.alphaCode(for: statement.currencyCode) ?? wallet.currencyCode
        )

        let transaction = Transaction(
            amount: amount,
            description: statement.description,
            date: Date(timeIntervalSince1970: TimeInterval(statement.time)),
            mcc: statement.mcc
        )

        transaction.externalId = statement.id
        transaction.wallet = wallet
        transaction.originalAmount = originalAmount
        transaction.originalCurrencyCode = ISO4217.alphaCode(for: statement.currencyCode)
        transaction.isHold = statement.hold
        transaction.mcc = statement.mcc
        transaction.cashbackAmount = ISO4217.fromMinorUnits(statement.cashbackAmount, currencyCode: wallet.currencyCode)
        transaction.commissionAmount = ISO4217.fromMinorUnits(statement.commissionRate, currencyCode: wallet.currencyCode)
        transaction.balanceAfter = ISO4217.fromMinorUnits(statement.balance, currencyCode: wallet.currencyCode)
        transaction.isFromBank = true  // Mark as bank transaction (read-only)

        modelContext.insert(transaction)

        return true
    }

    // MARK: - Helpers

    private func updateLastSyncTime() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.lastMonobankSync = Date()
            try? modelContext.save()
        }
    }

    // MARK: - Webhook

    func setupWebhook(url: String) async throws {
        try await apiClient.setWebhook(url: url)
    }
}

// MARK: - Sync Result

struct SyncResult {
    let accountsCount: Int
    let transactionsCount: Int
    let duration: TimeInterval
}
