import Foundation
import SwiftData

@MainActor
@Observable
final class DashboardViewModel {
    private let modelContext: ModelContext
    private let netWorthService: NetWorthService
    private let priceFetchService: PriceFetchService
    private let analytics: AnalyticsService

    // State
    var netWorth: NetWorthBreakdown?
    var recentTransactions: [Transaction] = []
    var isLoadingNetWorth = false
    var isLoadingTransactions = false
    var isRefreshingPrices = false
    var errorMessage: String?

    // Settings
    var baseCurrency: String = "UAH"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.netWorthService = NetWorthService(modelContext: modelContext)
        self.priceFetchService = PriceFetchService(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadBaseCurrency()
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        Task {
            await loadNetWorth()
            await loadRecentTransactions()
        }
    }

    func loadNetWorth() async {
        isLoadingNetWorth = true
        errorMessage = nil

        do {
            // Fetch latest prices if needed
            try await priceFetchService.fetchAllPrices()

            // Calculate net worth
            netWorth = netWorthService.calculateNetWorth(baseCurrency: baseCurrency)
        } catch {
            errorMessage = "Failed to load net worth: \(error.localizedDescription)"
        }

        isLoadingNetWorth = false
    }

    func loadRecentTransactions() async {
        isLoadingTransactions = true

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )

        do {
            let allTransactions = try modelContext.fetch(descriptor)
            recentTransactions = Array(allTransactions.prefix(10))
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }

        isLoadingTransactions = false
    }

    // MARK: - Actions

    func refresh() async {
        await loadNetWorth()
        await loadRecentTransactions()
    }

    func refreshPrices() async {
        isRefreshingPrices = true

        do {
            try await priceFetchService.forceRefreshAllPrices()
            await loadNetWorth()
            analytics.track(.chartViewed, properties: ["type": "net_worth_refresh"])
        } catch {
            errorMessage = "Failed to refresh prices: \(error.localizedDescription)"
        }

        isRefreshingPrices = false
    }

    // MARK: - Helpers

    private func loadBaseCurrency() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            baseCurrency = settings.baseCurrencyCode
        }
    }

    // MARK: - Computed Properties

    var totalNetWorthFormatted: String {
        guard let netWorth = netWorth else { return "—" }
        return Formatters.currency(netWorth.totalInBaseCurrency, currencyCode: baseCurrency)
    }

    var hasInvestments: Bool {
        guard let netWorth = netWorth else { return false }
        return netWorth.cryptoValue > 0 || netWorth.stocksValue > 0
    }

    var walletsCount: Int {
        netWorth?.walletBreakdown.count ?? 0
    }

    var cryptoHoldingsCount: Int {
        netWorth?.cryptoBreakdown.count ?? 0
    }

    var stockHoldingsCount: Int {
        netWorth?.stockBreakdown.count ?? 0
    }
}
