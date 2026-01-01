import Foundation

// MARK: - DTOs

struct YahooFinanceQuoteResponse: Codable {
    let quoteResponse: YahooQuoteResponseData
}

struct YahooQuoteResponseData: Codable {
    let result: [YahooQuote]?
    let error: YahooError?
}

struct YahooQuote: Codable {
    let symbol: String
    let regularMarketPrice: Double?
    let regularMarketChange: Double?
    let regularMarketChangePercent: Double?
    let regularMarketTime: Int64?
    let regularMarketDayHigh: Double?
    let regularMarketDayLow: Double?
    let regularMarketVolume: Int64?
    let regularMarketPreviousClose: Double?
    let regularMarketOpen: Double?
    let fiftyTwoWeekLow: Double?
    let fiftyTwoWeekHigh: Double?
    let shortName: String?
    let longName: String?
    let currency: String?
    let exchange: String?
    let quoteType: String?
    let marketCap: Int64?
}

struct YahooError: Codable {
    let code: String
    let description: String
}

struct YahooSearchResponse: Codable {
    let quotes: [YahooSearchQuote]
}

struct YahooSearchQuote: Codable {
    let symbol: String
    let shortname: String?
    let longname: String?
    let exchange: String?
    let quoteType: String?
    let score: Double?
}

// MARK: - API Client

enum YahooFinanceAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case noData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .noData:
            return "No data available for this symbol"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

@MainActor
final class YahooFinanceAPIClient {
    private let baseURL = "https://query1.finance.yahoo.com"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Request Builder

    private func buildRequest(endpoint: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)\(endpoint)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw YahooFinanceAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    // MARK: - Generic Request Handler

    private func performRequest<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, queryItems: queryItems)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YahooFinanceAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw YahooFinanceAPIError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw YahooFinanceAPIError.decodingError(error)
        }
    }

    // MARK: - API Endpoints

    /// Get quote for a single stock symbol
    /// - Parameter symbol: Stock ticker symbol (e.g., "AAPL", "GOOGL")
    func getQuote(symbol: String) async throws -> YahooQuote {
        let quotes = try await getQuotes(symbols: [symbol])
        guard let quote = quotes.first else {
            throw YahooFinanceAPIError.noData
        }
        return quote
    }

    /// Get quotes for multiple stock symbols
    /// - Parameter symbols: Array of stock ticker symbols
    func getQuotes(symbols: [String]) async throws -> [YahooQuote] {
        let symbolsString = symbols.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "symbols", value: symbolsString)
        ]

        let response: YahooFinanceQuoteResponse = try await performRequest(
            endpoint: "/v7/finance/quote",
            queryItems: queryItems
        )

        if let error = response.quoteResponse.error {
            throw YahooFinanceAPIError.apiError(error.description)
        }

        guard let result = response.quoteResponse.result, !result.isEmpty else {
            throw YahooFinanceAPIError.noData
        }

        return result
    }

    /// Search for stocks by query
    /// - Parameter query: Search query (company name or symbol)
    func search(query: String) async throws -> [YahooSearchQuote] {
        let queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "quotesCount", value: "10")
        ]

        let response: YahooSearchResponse = try await performRequest(
            endpoint: "/v1/finance/search",
            queryItems: queryItems
        )

        return response.quotes
    }

    /// Batch fetch prices for multiple stocks
    /// - Parameter symbols: Array of stock ticker symbols
    /// - Returns: Dictionary mapping symbol to price
    func batchFetchPrices(symbols: [String]) async throws -> [String: Double] {
        let quotes = try await getQuotes(symbols: symbols)

        var prices: [String: Double] = [:]
        for quote in quotes {
            if let price = quote.regularMarketPrice {
                prices[quote.symbol] = price
            }
        }

        return prices
    }

    /// Get current price for a single stock
    /// - Parameter symbol: Stock ticker symbol
    /// - Returns: Current market price or nil if unavailable
    func getPrice(symbol: String) async throws -> Double? {
        let quote = try await getQuote(symbol: symbol)
        return quote.regularMarketPrice
    }

    /// Validate if a stock symbol exists
    /// - Parameter symbol: Stock ticker symbol
    /// - Returns: True if the symbol exists and has data
    func validateSymbol(_ symbol: String) async -> Bool {
        do {
            let quote = try await getQuote(symbol: symbol)
            return quote.regularMarketPrice != nil
        } catch {
            return false
        }
    }
}
