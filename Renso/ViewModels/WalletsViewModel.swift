import Foundation
import SwiftData

@MainActor
@Observable
final class WalletsViewModel {
    private let modelContext: ModelContext
    private let converter: CurrencyConverter
    private let analytics: AnalyticsService

    // State
    var wallets: [Wallet] = []
    var isLoading = false
    var errorMessage: String?
    var baseCurrency: String = "UAH"

    // Filter
    var showArchived = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.converter = CurrencyConverter(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadBaseCurrency()
        loadWallets()
    }

    // MARK: - Data Loading

    func loadWallets() {
        isLoading = true
        errorMessage = nil

        let predicate: Predicate<Wallet>
        if showArchived {
            predicate = #Predicate { _ in true }
        } else {
            predicate = #Predicate { !$0.isArchived }
        }

        let descriptor = FetchDescriptor<Wallet>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Wallet.sortOrder, order: .forward)]
        )

        do {
            wallets = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load wallets: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func createWallet(
        name: String,
        currencyCode: String,
        initialBalance: Decimal,
        iconName: String = "wallet.pass.fill",
        colorHex: String = "#007AFF"
    ) {
        let wallet = Wallet(
            name: name,
            currencyCode: currencyCode,
            initialBalance: initialBalance,
            iconName: iconName,
            colorHex: colorHex
        )
        wallet.sortOrder = wallets.count

        modelContext.insert(wallet)

        do {
            try modelContext.save()
            loadWallets()

            analytics.trackWalletCreated(
                currencyCode: currencyCode,
                hasMonobank: wallet.monobankAccountId != nil
            )
        } catch {
            errorMessage = "Failed to create wallet: \(error.localizedDescription)"
        }
    }

    func updateWallet(
        _ wallet: Wallet,
        name: String,
        iconName: String,
        colorHex: String
    ) {
        wallet.name = name
        wallet.iconName = iconName
        wallet.colorHex = colorHex

        do {
            try modelContext.save()
            loadWallets()
            analytics.track(.walletEdited)
        } catch {
            errorMessage = "Failed to update wallet: \(error.localizedDescription)"
        }
    }

    func archiveWallet(_ wallet: Wallet) {
        wallet.isArchived = true

        do {
            try modelContext.save()
            loadWallets()
            analytics.track(.walletArchived)
        } catch {
            errorMessage = "Failed to archive wallet: \(error.localizedDescription)"
        }
    }

    func unarchiveWallet(_ wallet: Wallet) {
        wallet.isArchived = false

        do {
            try modelContext.save()
            loadWallets()
        } catch {
            errorMessage = "Failed to unarchive wallet: \(error.localizedDescription)"
        }
    }

    func deleteWallet(_ wallet: Wallet) {
        modelContext.delete(wallet)

        do {
            try modelContext.save()
            loadWallets()
            analytics.track(.walletDeleted)
        } catch {
            errorMessage = "Failed to delete wallet: \(error.localizedDescription)"
        }
    }

    // MARK: - Reordering

    func moveWallet(from source: IndexSet, to destination: Int) {
        var updatedWallets = wallets
        updatedWallets.move(fromOffsets: source, toOffset: destination)

        for (index, wallet) in updatedWallets.enumerated() {
            wallet.sortOrder = index
        }

        do {
            try modelContext.save()
            loadWallets()
        } catch {
            errorMessage = "Failed to reorder wallets: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func loadBaseCurrency() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            baseCurrency = settings.baseCurrencyCode
        }
    }

    func getTotalValue() -> Decimal {
        var total: Decimal = 0

        for wallet in wallets where !wallet.isArchived {
            let valueInBase = converter.convert(
                amount: wallet.currentBalance,
                from: wallet.currencyCode,
                to: baseCurrency
            ) ?? wallet.currentBalance

            total += valueInBase
        }

        return total
    }

    func getWalletValueInBaseCurrency(_ wallet: Wallet) -> Decimal {
        return converter.convert(
            amount: wallet.currentBalance,
            from: wallet.currencyCode,
            to: baseCurrency
        ) ?? wallet.currentBalance
    }

    // MARK: - Computed Properties

    var totalValueFormatted: String {
        Formatters.currency(getTotalValue(), currencyCode: baseCurrency)
    }

    var activeWalletsCount: Int {
        wallets.filter { !$0.isArchived }.count
    }

    var hasMonobankWallets: Bool {
        wallets.contains { $0.monobankAccountId != nil }
    }
}
