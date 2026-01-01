import Foundation
import SwiftData

@MainActor
final class CurrencyConverter {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Conversion

    /// Convert amount from one currency to another
    /// - Parameters:
    ///   - amount: Amount to convert
    ///   - from: Source currency code (e.g., "USD")
    ///   - to: Target currency code (e.g., "UAH")
    /// - Returns: Converted amount or nil if rate not available
    func convert(
        amount: Decimal,
        from sourceCurrency: String,
        to targetCurrency: String
    ) -> Decimal? {
        // Same currency, no conversion needed
        if sourceCurrency == targetCurrency {
            return amount
        }

        guard let rate = getRate(from: sourceCurrency, to: targetCurrency) else {
            return nil
        }

        return amount * rate
    }

    /// Get exchange rate between two currencies
    /// - Parameters:
    ///   - from: Source currency code
    ///   - to: Target currency code
    /// - Returns: Exchange rate or nil if not available
    func getRate(from sourceCurrency: String, to targetCurrency: String) -> Decimal? {
        // Same currency
        if sourceCurrency == targetCurrency {
            return 1
        }

        // Try direct rate
        if let directRate = fetchRate(from: sourceCurrency, to: targetCurrency) {
            return directRate
        }

        // Try inverse rate
        if let inverseRate = fetchRate(from: targetCurrency, to: sourceCurrency) {
            return 1 / inverseRate
        }

        // Try cross-rate through USD
        if sourceCurrency != "USD" && targetCurrency != "USD" {
            if let sourceToUSD = fetchRate(from: sourceCurrency, to: "USD"),
               let usdToTarget = fetchRate(from: "USD", to: targetCurrency) {
                return sourceToUSD * usdToTarget
            }
        }

        return nil
    }

    // MARK: - Fetch Rates

    private func fetchRate(from sourceCurrency: String, to targetCurrency: String) -> Decimal? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { rate in
                rate.fromCurrencyCode == sourceCurrency && rate.toCurrencyCode == targetCurrency
            },
            sortBy: [SortDescriptor(\ExchangeRate.fetchedAt, order: .reverse)]
        )

        guard let exchangeRate = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        // Check if rate is not too old (max 24 hours)
        let maxAge: TimeInterval = 24 * 60 * 60
        if Date().timeIntervalSince(exchangeRate.fetchedAt) > maxAge {
            return nil
        }

        return exchangeRate.rate
    }

    // MARK: - Save Rates

    /// Save exchange rate
    func saveRate(
        from sourceCurrency: String,
        to targetCurrency: String,
        rate: Decimal,
        buyRate: Decimal? = nil,
        sellRate: Decimal? = nil,
        source: String = "monobank"
    ) {
        // Check if rate already exists
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { exchangeRate in
                exchangeRate.fromCurrencyCode == sourceCurrency &&
                exchangeRate.toCurrencyCode == targetCurrency &&
                exchangeRate.source == source
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            // Update existing
            existing.rate = rate
            existing.buyRate = buyRate
            existing.sellRate = sellRate
            existing.fetchedAt = Date()
        } else {
            // Create new
            let newRate = ExchangeRate(
                fromCurrencyCode: sourceCurrency,
                toCurrencyCode: targetCurrency,
                rate: rate,
                buyRate: buyRate,
                sellRate: sellRate,
                source: source
            )
            modelContext.insert(newRate)
        }

        try? modelContext.save()
    }

    /// Save multiple exchange rates
    func saveRates(_ rates: [(from: String, to: String, rate: Decimal, buy: Decimal?, sell: Decimal?)], source: String = "monobank") {
        for rateData in rates {
            saveRate(
                from: rateData.from,
                to: rateData.to,
                rate: rateData.rate,
                buyRate: rateData.buy,
                sellRate: rateData.sell,
                source: source
            )
        }
    }

    // MARK: - Cleanup

    /// Delete old exchange rates (older than 7 days)
    func cleanupOldRates() {
        let maxAge: TimeInterval = 7 * 24 * 60 * 60
        let cutoffDate = Date().addingTimeInterval(-maxAge)

        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { rate in
                rate.fetchedAt < cutoffDate
            }
        )

        guard let oldRates = try? modelContext.fetch(descriptor) else {
            return
        }

        for rate in oldRates {
            modelContext.delete(rate)
        }

        try? modelContext.save()
    }
}
