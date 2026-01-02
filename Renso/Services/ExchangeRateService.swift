import Foundation

struct StoredExchangeRate: Codable {
    let fromCurrency: String
    let toCurrency: String
    let rate: Double
    let buyRate: Double?
    let sellRate: Double?
    let updatedAt: Date

    var averageRate: Double {
        if let buy = buyRate, let sell = sellRate {
            return (buy + sell) / 2
        }
        return rate
    }
}

struct ExchangeRatesData: Codable {
    var rates: [StoredExchangeRate]
    var lastFetchedAt: Date

    static var empty: ExchangeRatesData {
        ExchangeRatesData(rates: [], lastFetchedAt: .distantPast)
    }
}

@MainActor
final class ExchangeRateService {
    static let shared = ExchangeRateService()

    private let fileManager = FileManager.default
    private let apiClient = MonobankAPIClient()
    private var cachedData: ExchangeRatesData?

    private var ratesFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("exchange_rates.json")
    }

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    var lastUpdated: Date? {
        cachedData?.lastFetchedAt
    }

    var hasRates: Bool {
        !(cachedData?.rates.isEmpty ?? true)
    }

    /// Fetches fresh exchange rates from Monobank API and saves them
    func fetchRates() async throws {
        let monobankRates = try await apiClient.getCurrencyRates()

        var storedRates: [StoredExchangeRate] = []
        let now = Date()

        for rate in monobankRates {
            guard let fromCurrency = ISO4217.alphaCode(for: rate.currencyCodeA),
                  let toCurrency = ISO4217.alphaCode(for: rate.currencyCodeB) else {
                continue
            }

            // Determine the rate to use
            let rateValue: Double
            if let cross = rate.rateCross {
                rateValue = cross
            } else if let buy = rate.rateBuy, let sell = rate.rateSell {
                rateValue = (buy + sell) / 2
            } else if let buy = rate.rateBuy {
                rateValue = buy
            } else if let sell = rate.rateSell {
                rateValue = sell
            } else {
                continue
            }

            let storedRate = StoredExchangeRate(
                fromCurrency: fromCurrency,
                toCurrency: toCurrency,
                rate: rateValue,
                buyRate: rate.rateBuy,
                sellRate: rate.rateSell,
                updatedAt: now
            )
            storedRates.append(storedRate)
        }

        cachedData = ExchangeRatesData(rates: storedRates, lastFetchedAt: now)
        saveToDisk()
    }

    /// Gets the exchange rate between two currencies
    func getRate(from: String, to: String) -> Double? {
        guard let data = cachedData else { return nil }

        // Same currency
        if from == to { return 1.0 }

        // Direct rate
        if let direct = data.rates.first(where: { $0.fromCurrency == from && $0.toCurrency == to }) {
            return direct.averageRate
        }

        // Inverse rate
        if let inverse = data.rates.first(where: { $0.fromCurrency == to && $0.toCurrency == from }) {
            return 1.0 / inverse.averageRate
        }

        // Cross rate through UAH (most Monobank rates are X/UAH)
        if from != "UAH" && to != "UAH" {
            if let fromToUAH = getRate(from: from, to: "UAH"),
               let uahToTarget = getRate(from: "UAH", to: to) {
                return fromToUAH * uahToTarget
            }
        }

        return nil
    }

    /// Converts an amount from one currency to another
    func convert(amount: Decimal, from: String, to: String) -> Decimal? {
        guard let rate = getRate(from: from, to: to) else { return nil }
        return amount * Decimal(rate)
    }

    /// Gets all available currency codes from stored rates
    func availableCurrencies() -> [String] {
        guard let data = cachedData else { return [] }

        var currencies = Set<String>()
        for rate in data.rates {
            currencies.insert(rate.fromCurrency)
            currencies.insert(rate.toCurrency)
        }
        return currencies.sorted()
    }

    /// Gets rates for a specific base currency
    func getRates(for baseCurrency: String) -> [(currency: String, rate: Double)] {
        let allCurrencies = ISO4217.allCurrencies.filter { $0 != baseCurrency }

        var result: [(currency: String, rate: Double)] = []
        for currency in allCurrencies {
            if let rate = getRate(from: baseCurrency, to: currency) {
                result.append((currency, rate))
            }
        }

        return result.sorted { $0.currency < $1.currency }
    }

    /// Checks if rates need to be refreshed (older than specified hours)
    func needsRefresh(olderThanHours: Int = 6) -> Bool {
        guard let lastFetch = cachedData?.lastFetchedAt else { return true }
        let hoursAgo = Date().addingTimeInterval(-Double(olderThanHours) * 3600)
        return lastFetch < hoursAgo
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: ratesFileURL.path) else {
            cachedData = .empty
            return
        }

        do {
            let data = try Data(contentsOf: ratesFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cachedData = try decoder.decode(ExchangeRatesData.self, from: data)
        } catch {
            print("Failed to load exchange rates: \(error)")
            cachedData = .empty
        }
    }

    private func saveToDisk() {
        guard let data = cachedData else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: ratesFileURL, options: .atomic)
        } catch {
            print("Failed to save exchange rates: \(error)")
        }
    }

    /// Clears all stored rates
    func clearRates() {
        cachedData = .empty
        try? fileManager.removeItem(at: ratesFileURL)
    }
}
