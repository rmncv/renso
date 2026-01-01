import Foundation
import SwiftData

enum MonobankSyncError: LocalizedError {
    case noToken
    case apiError(Error)
    case noAccounts
    case invalidData

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
        }
    }
}

@MainActor
final class MonobankSyncService {
    private let modelContext: ModelContext
    private let apiClient: MonobankAPIClient
    private let rulesEngine: RulesEngine
    private let converter: CurrencyConverter

    init(modelContext: ModelContext, token: String? = "u1wWQSCeThK6aC8ZNrFIjgNbwAb78gFj2PYhI_7e5f2I") {
        self.modelContext = modelContext
        self.apiClient = MonobankAPIClient(token: token)
        self.rulesEngine = RulesEngine(modelContext: modelContext)
        self.converter = CurrencyConverter(modelContext: modelContext)
    }

    func setToken(_ token: String) {
        apiClient.setToken(token)
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

            wallet = Wallet(
                name: account.iban ?? "Monobank \(account.type)",
                currencyCode: currencyCode,
                initialBalance: balance
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
