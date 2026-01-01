import Foundation
import SwiftData

@MainActor
@Observable
final class InvestmentsViewModel {
    private let modelContext: ModelContext
    private let priceFetchService: PriceFetchService
    private let converter: CurrencyConverter
    private let analytics: AnalyticsService

    // State
    var cryptoHoldings: [CryptoHolding] = []
    var stockHoldings: [StockHolding] = []
    var isLoading = false
    var isRefreshingPrices = false
    var errorMessage: String?
    var baseCurrency: String = "UAH"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.priceFetchService = PriceFetchService(modelContext: modelContext)
        self.converter = CurrencyConverter(modelContext: modelContext)
        self.analytics = AnalyticsService.shared

        loadBaseCurrency()
        loadHoldings()
    }

    // MARK: - Data Loading

    func loadHoldings() {
        isLoading = true
        errorMessage = nil

        do {
            let cryptoDescriptor = FetchDescriptor<CryptoHolding>(
                sortBy: [SortDescriptor(\CryptoHolding.symbol, order: .forward)]
            )
            cryptoHoldings = try modelContext.fetch(cryptoDescriptor)

            let stockDescriptor = FetchDescriptor<StockHolding>(
                sortBy: [SortDescriptor(\StockHolding.symbol, order: .forward)]
            )
            stockHoldings = try modelContext.fetch(stockDescriptor)
        } catch {
            errorMessage = "Failed to load holdings: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Crypto Operations

    func addCryptoHolding(
        symbol: String,
        name: String,
        coinmarketcapId: Int?,
        quantity: Decimal,
        averagePrice: Decimal,
        currencyCode: String
    ) {
        let holding = CryptoHolding(
            symbol: symbol,
            name: name,
            quantity: quantity,
            averagePurchasePrice: averagePrice,
            purchaseCurrencyCode: currencyCode
        )

        holding.coinmarketcapId = coinmarketcapId

        modelContext.insert(holding)

        do {
            try modelContext.save()
            loadHoldings()
            analytics.trackCryptoAdded(symbol: symbol, quantity: quantity)
        } catch {
            errorMessage = "Failed to add crypto holding: \(error.localizedDescription)"
        }
    }

    func recordCryptoTransaction(
        holding: CryptoHolding,
        type: CryptoTransactionType,
        quantity: Decimal,
        pricePerUnit: Decimal,
        fee: Decimal?,
        currencyCode: String,
        date: Date,
        note: String?
    ) {
        let transaction = CryptoTransaction(
            type: type,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            currencyCode: currencyCode,
            fee: fee,
            date: date,
            note: note
        )

        transaction.holding = holding
        modelContext.insert(transaction)

        // Recalculate average price and quantity
        holding.recalculateAveragePrice()

        do {
            try modelContext.save()
            loadHoldings()
            analytics.track(.cryptoTransactionRecorded)
        } catch {
            errorMessage = "Failed to record transaction: \(error.localizedDescription)"
        }
    }

    func deleteCryptoHolding(_ holding: CryptoHolding) {
        modelContext.delete(holding)

        do {
            try modelContext.save()
            loadHoldings()
        } catch {
            errorMessage = "Failed to delete holding: \(error.localizedDescription)"
        }
    }

    // MARK: - Stock Operations

    func addStockHolding(
        symbol: String,
        companyName: String,
        exchange: String,
        yahooTicker: String,
        quantity: Decimal,
        averagePrice: Decimal,
        currencyCode: String
    ) {
        let holding = StockHolding(
            symbol: symbol,
            companyName: companyName,
            exchange: exchange,
            quantity: quantity,
            averagePurchasePrice: averagePrice,
            purchaseCurrencyCode: currencyCode
        )

        holding.yahooTicker = yahooTicker
        modelContext.insert(holding)

        do {
            try modelContext.save()
            loadHoldings()
            analytics.trackStockAdded(symbol: symbol, quantity: quantity)
        } catch {
            errorMessage = "Failed to add stock holding: \(error.localizedDescription)"
        }
    }

    func recordStockTransaction(
        holding: StockHolding,
        type: StockTransactionType,
        quantity: Decimal,
        pricePerShare: Decimal,
        fee: Decimal?,
        currencyCode: String,
        date: Date,
        note: String?
    ) {
        let transaction = StockTransaction(
            type: type,
            quantity: quantity,
            pricePerShare: pricePerShare,
            currencyCode: currencyCode,
            fee: fee,
            date: date,
            note: note
        )

        transaction.holding = holding
        modelContext.insert(transaction)

        // Recalculate average price and quantity
        holding.recalculateAveragePrice()

        do {
            try modelContext.save()
            loadHoldings()
            analytics.track(.stockTransactionRecorded)
        } catch {
            errorMessage = "Failed to record transaction: \(error.localizedDescription)"
        }
    }

    func deleteStockHolding(_ holding: StockHolding) {
        modelContext.delete(holding)

        do {
            try modelContext.save()
            loadHoldings()
        } catch {
            errorMessage = "Failed to delete holding: \(error.localizedDescription)"
        }
    }

    // MARK: - Price Updates

    func refreshPrices() async {
        isRefreshingPrices = true

        do {
            try await priceFetchService.fetchAllPrices()
            loadHoldings()
        } catch {
            errorMessage = "Failed to refresh prices: \(error.localizedDescription)"
        }

        isRefreshingPrices = false
    }

    // MARK: - Search

    func searchCrypto(symbol: String) async throws -> Int? {
        return try await priceFetchService.searchCrypto(symbol: symbol)
    }

    func searchStocks(query: String) async throws -> [YahooSearchQuote] {
        return try await priceFetchService.searchStocks(query: query)
    }

    // MARK: - Helpers

    private func loadBaseCurrency() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            baseCurrency = settings.baseCurrencyCode
        }
    }

    func getCryptoValue(_ holding: CryptoHolding) -> Decimal {
        let currentValue = holding.quantity * (holding.lastPrice ?? 0)
        return converter.convert(
            amount: currentValue,
            from: holding.purchaseCurrencyCode,
            to: baseCurrency
        ) ?? currentValue
    }

    func getStockValue(_ holding: StockHolding) -> Decimal {
        let currentValue = holding.quantity * (holding.lastPrice ?? 0)
        return converter.convert(
            amount: currentValue,
            from: holding.purchaseCurrencyCode,
            to: baseCurrency
        ) ?? currentValue
    }

    // MARK: - Computed Properties

    var totalCryptoValue: Decimal {
        cryptoHoldings.reduce(0) { $0 + getCryptoValue($1) }
    }

    var totalStockValue: Decimal {
        stockHoldings.reduce(0) { $0 + getStockValue($1) }
    }

    var totalInvestmentValue: Decimal {
        totalCryptoValue + totalStockValue
    }
}
