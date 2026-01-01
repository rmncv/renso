import Foundation
import SwiftData

@MainActor
final class PriceFetchService {
    private let modelContext: ModelContext
    private let cryptoAPI: CoinMarketCapAPIClient
    private let stockAPI: YahooFinanceAPIClient

    // Minimum interval between price updates (15 minutes)
    private let minimumUpdateInterval: TimeInterval = 15 * 60

    init(
        modelContext: ModelContext,
        cryptoAPIKey: String? = nil
    ) {
        self.modelContext = modelContext
        self.cryptoAPI = CoinMarketCapAPIClient(apiKey: cryptoAPIKey)
        self.stockAPI = YahooFinanceAPIClient()
    }

    func setCryptoAPIKey(_ key: String) {
        cryptoAPI.setAPIKey(key)
    }

    // MARK: - Fetch All Prices

    /// Fetch and update prices for all holdings (both crypto and stocks)
    func fetchAllPrices() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.fetchCryptoPrices()
            }

            group.addTask {
                try await self.fetchStockPrices()
            }

            try await group.waitForAll()
        }
    }

    // MARK: - Crypto Prices

    /// Fetch and update prices for all crypto holdings
    func fetchCryptoPrices() async throws {
        let descriptor = FetchDescriptor<CryptoHolding>()
        let holdings = try modelContext.fetch(descriptor)

        guard !holdings.isEmpty else { return }

        // Filter holdings that need updating
        let holdingsToUpdate = holdings.filter { holding in
            guard let lastUpdate = holding.lastPriceUpdate else { return true }
            return Date().timeIntervalSince(lastUpdate) > minimumUpdateInterval
        }

        guard !holdingsToUpdate.isEmpty else { return }

        // Fetch prices in batches
        let symbols = holdingsToUpdate.map { $0.symbol }
        let prices = try await cryptoAPI.batchFetchPrices(symbols: symbols)

        // Update holdings
        for holding in holdingsToUpdate {
            if let price = prices[holding.symbol] {
                holding.lastPrice = Decimal(price)
                holding.lastPriceUpdate = Date()
            }
        }

        try modelContext.save()
    }

    /// Fetch price for a specific crypto holding
    func fetchCryptoPrice(for holding: CryptoHolding) async throws {
        let prices = try await cryptoAPI.batchFetchPrices(symbols: [holding.symbol])

        if let price = prices[holding.symbol] {
            holding.lastPrice = Decimal(price)
            holding.lastPriceUpdate = Date()
            try modelContext.save()
        }
    }

    // MARK: - Stock Prices

    /// Fetch and update prices for all stock holdings
    func fetchStockPrices() async throws {
        let descriptor = FetchDescriptor<StockHolding>()
        let holdings = try modelContext.fetch(descriptor)

        guard !holdings.isEmpty else { return }

        // Filter holdings that need updating
        let holdingsToUpdate = holdings.filter { holding in
            guard let lastUpdate = holding.lastPriceUpdate else { return true }
            return Date().timeIntervalSince(lastUpdate) > minimumUpdateInterval
        }

        guard !holdingsToUpdate.isEmpty else { return }

        // Fetch prices in batches (filter out holdings without yahoo ticker)
        let symbols = holdingsToUpdate.compactMap { $0.yahooTicker }
        guard !symbols.isEmpty else { return }

        let prices = try await stockAPI.batchFetchPrices(symbols: symbols)

        // Update holdings
        for holding in holdingsToUpdate {
            guard let ticker = holding.yahooTicker else { continue }
            if let price = prices[ticker] {
                holding.lastPrice = Decimal(price)
                holding.lastPriceUpdate = Date()
            }
        }

        try modelContext.save()
    }

    /// Fetch price for a specific stock holding
    func fetchStockPrice(for holding: StockHolding) async throws {
        guard let ticker = holding.yahooTicker else { return }

        let price = try await stockAPI.getPrice(symbol: ticker)

        if let price = price {
            holding.lastPrice = Decimal(price)
            holding.lastPriceUpdate = Date()
            try modelContext.save()
        }
    }

    // MARK: - Search and Validation

    /// Search for cryptocurrency by symbol
    func searchCrypto(symbol: String) async throws -> Int? {
        return try await cryptoAPI.searchCryptocurrency(symbol: symbol)
    }

    /// Search for stocks by query
    func searchStocks(query: String) async throws -> [YahooSearchQuote] {
        return try await stockAPI.search(query: query)
    }

    /// Validate stock symbol exists
    func validateStockSymbol(_ symbol: String) async -> Bool {
        return await stockAPI.validateSymbol(symbol)
    }

    // MARK: - Background Refresh

    /// Schedule background price refresh
    /// Call this on app launch or when entering foreground
    func scheduleBackgroundRefresh() {
        Task {
            do {
                try await fetchAllPrices()
            } catch {
                print("Background price refresh failed: \(error)")
            }
        }
    }

    // MARK: - Force Refresh

    /// Force refresh prices ignoring the minimum update interval
    func forceRefreshAllPrices() async throws {
        // Temporarily clear last update times
        let cryptoDescriptor = FetchDescriptor<CryptoHolding>()
        let cryptoHoldings = try modelContext.fetch(cryptoDescriptor)
        for holding in cryptoHoldings {
            holding.lastPriceUpdate = nil
        }

        let stockDescriptor = FetchDescriptor<StockHolding>()
        let stockHoldings = try modelContext.fetch(stockDescriptor)
        for holding in stockHoldings {
            holding.lastPriceUpdate = nil
        }

        try await fetchAllPrices()
    }
}
