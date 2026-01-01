import Foundation
import SwiftData

@MainActor
@Observable
final class TransferViewModel {
    private let modelContext: ModelContext
    private let converter: CurrencyConverter
    private let analytics: AnalyticsService

    // State
    var sourceWallet: Wallet?
    var destinationWallet: Wallet?
    var amount: Decimal = 0
    var useManualExchangeRate = false
    var manualExchangeRate: Decimal?
    var note: String = ""
    var date: Date = Date()

    var isProcessing = false
    var errorMessage: String?

    // Available wallets
    var wallets: [Wallet] = []

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.converter = CurrencyConverter(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadWallets()
    }

    // MARK: - Data Loading

    func loadWallets() {
        let descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Wallet.sortOrder, order: .forward)]
        )

        do {
            wallets = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load wallets: \(error.localizedDescription)"
        }
    }

    // MARK: - Transfer Execution

    func executeTransfer() async -> Bool {
        guard validate() else { return false }

        guard let source = sourceWallet,
              let destination = destinationWallet else {
            errorMessage = "Please select both source and destination wallets"
            return false
        }

        isProcessing = true
        errorMessage = nil

        do {
            // Calculate converted amount
            let convertedAmount: Decimal
            if useManualExchangeRate, let manualRate = manualExchangeRate {
                convertedAmount = amount * manualRate
            } else if let autoRate = converter.getRate(from: source.currencyCode, to: destination.currencyCode) {
                convertedAmount = amount * autoRate
            } else {
                errorMessage = "Exchange rate not available. Please set manual rate."
                isProcessing = false
                return false
            }

            // Create transfer record
            let transfer = Transfer(
                amount: amount,
                from: source,
                to: destination,
                convertedAmount: convertedAmount,
                manualExchangeRate: useManualExchangeRate ? manualExchangeRate : nil,
                note: note.isEmpty ? nil : note
            )

            transfer.date = date

            // Update wallet balances
            source.currentBalance -= amount
            destination.currentBalance += convertedAmount

            modelContext.insert(transfer)
            try modelContext.save()

            analytics.track(.transferCompleted, properties: [
                "amount": NSDecimalNumber(decimal: amount).doubleValue,
                "from_currency": source.currencyCode,
                "to_currency": destination.currencyCode,
                "manual_rate": useManualExchangeRate
            ])

            reset()
            isProcessing = false
            return true

        } catch {
            errorMessage = "Failed to execute transfer: \(error.localizedDescription)"
            isProcessing = false
            return false
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        guard let source = sourceWallet else {
            errorMessage = "Please select source wallet"
            return false
        }

        guard let destination = destinationWallet else {
            errorMessage = "Please select destination wallet"
            return false
        }

        guard source.id != destination.id else {
            errorMessage = "Source and destination must be different"
            return false
        }

        guard amount > 0 else {
            errorMessage = "Amount must be greater than zero"
            return false
        }

        guard amount <= source.currentBalance else {
            errorMessage = "Insufficient balance in source wallet"
            return false
        }

        if useManualExchangeRate {
            guard let rate = manualExchangeRate, rate > 0 else {
                errorMessage = "Please enter a valid exchange rate"
                return false
            }
        }

        return true
    }

    // MARK: - Helpers

    func reset() {
        sourceWallet = nil
        destinationWallet = nil
        amount = 0
        useManualExchangeRate = false
        manualExchangeRate = nil
        note = ""
        date = Date()
        errorMessage = nil
    }

    func swapWallets() {
        let temp = sourceWallet
        sourceWallet = destinationWallet
        destinationWallet = temp
    }

    // MARK: - Computed Properties

    var convertedAmount: Decimal? {
        guard let source = sourceWallet,
              let destination = destinationWallet,
              amount > 0 else {
            return nil
        }

        if useManualExchangeRate, let manualRate = manualExchangeRate {
            return amount * manualRate
        }

        if let rate = converter.getRate(from: source.currencyCode, to: destination.currencyCode) {
            return amount * rate
        }

        return nil
    }

    var currentExchangeRate: Decimal? {
        guard let source = sourceWallet,
              let destination = destinationWallet else {
            return nil
        }

        if useManualExchangeRate {
            return manualExchangeRate
        }

        return converter.getRate(from: source.currencyCode, to: destination.currencyCode)
    }

    var canExecuteTransfer: Bool {
        guard let source = sourceWallet,
              let destination = destinationWallet else {
            return false
        }

        return source.id != destination.id &&
               amount > 0 &&
               amount <= source.currentBalance &&
               (!useManualExchangeRate || (manualExchangeRate ?? 0) > 0) &&
               !isProcessing
    }

    var availableWalletsForDestination: [Wallet] {
        guard let source = sourceWallet else {
            return wallets
        }

        return wallets.filter { $0.id != source.id }
    }

    // MARK: - History

    func loadTransferHistory(limit: Int = 20) -> [Transfer] {
        let descriptor = FetchDescriptor<Transfer>(
            sortBy: [SortDescriptor(\Transfer.date, order: .reverse)]
        )

        guard let transfers = try? modelContext.fetch(descriptor) else {
            return []
        }

        return Array(transfers.prefix(limit))
    }
}
