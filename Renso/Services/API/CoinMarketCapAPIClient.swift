import Foundation

// MARK: - DTOs

struct CoinMarketCapQuotesResponse: Codable {
    let data: [String: CoinMarketCapCoinData]
    let status: CoinMarketCapStatus
}

struct CoinMarketCapCoinData: Codable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let quote: [String: CoinMarketCapQuote]
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, slug, quote
        case lastUpdated = "last_updated"
    }
}

struct CoinMarketCapQuote: Codable {
    let price: Double
    let volume24h: Double?
    let percentChange1h: Double?
    let percentChange24h: Double?
    let percentChange7d: Double?
    let percentChange30d: Double?
    let marketCap: Double?
    let lastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case price
        case volume24h = "volume_24h"
        case percentChange1h = "percent_change_1h"
        case percentChange24h = "percent_change_24h"
        case percentChange7d = "percent_change_7d"
        case percentChange30d = "percent_change_30d"
        case marketCap = "market_cap"
        case lastUpdated = "last_updated"
    }
}

struct CoinMarketCapStatus: Codable {
    let timestamp: String
    let errorCode: Int
    let errorMessage: String?
    let elapsed: Int
    let creditCount: Int

    enum CodingKeys: String, CodingKey {
        case timestamp
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case elapsed
        case creditCount = "credit_count"
    }
}

struct CoinMarketCapMapResponse: Codable {
    let data: [CoinMarketCapMapData]
    let status: CoinMarketCapStatus
}

struct CoinMarketCapMapData: Codable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let isActive: Int
    let rank: Int?
    let firstHistoricalData: String?
    let lastHistoricalData: String?
    let platform: CoinMarketCapPlatform?

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, slug, rank, platform
        case isActive = "is_active"
        case firstHistoricalData = "first_historical_data"
        case lastHistoricalData = "last_historical_data"
    }
}

struct CoinMarketCapPlatform: Codable {
    let id: Int
    let name: String
    let symbol: String
    let slug: String
    let tokenAddress: String

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, slug
        case tokenAddress = "token_address"
    }
}

// MARK: - API Client

enum CoinMarketCapAPIError: LocalizedError {
    case invalidURL
    case noAPIKey
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noAPIKey:
            return "CoinMarketCap API key not configured"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API error (\(code)): \(message)"
        }
    }
}

@MainActor
final class CoinMarketCapAPIClient {
    private let baseURL = "https://pro-api.coinmarketcap.com/v1"
    private let session: URLSession
    private var apiKey: String?

    init(apiKey: String? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.apiKey = apiKey
    }

    func setAPIKey(_ key: String) {
        self.apiKey = key
    }

    // MARK: - Request Builder

    private func buildRequest(endpoint: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard let apiKey = apiKey else {
            throw CoinMarketCapAPIError.noAPIKey
        }

        var components = URLComponents(string: "\(baseURL)\(endpoint)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw CoinMarketCapAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")
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
            throw CoinMarketCapAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CoinMarketCapAPIError.apiError(httpResponse.statusCode, errorMessage)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw CoinMarketCapAPIError.decodingError(error)
        }
    }

    // MARK: - API Endpoints

    /// Get latest quotes for cryptocurrencies by symbol
    /// - Parameters:
    ///   - symbols: Comma-separated list of symbols (e.g., "BTC,ETH,USDT")
    ///   - convert: Currency to convert to (default: "USD")
    func getQuotes(symbols: [String], convert: String = "USD") async throws -> CoinMarketCapQuotesResponse {
        let symbolsString = symbols.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "symbol", value: symbolsString),
            URLQueryItem(name: "convert", value: convert)
        ]
        return try await performRequest(endpoint: "/cryptocurrency/quotes/latest", queryItems: queryItems)
    }

    /// Get latest quotes for cryptocurrencies by CoinMarketCap ID
    /// - Parameters:
    ///   - ids: Comma-separated list of CoinMarketCap IDs (e.g., "1,1027,825")
    ///   - convert: Currency to convert to (default: "USD")
    func getQuotesByIds(ids: [Int], convert: String = "USD") async throws -> CoinMarketCapQuotesResponse {
        let idsString = ids.map { String($0) }.joined(separator: ",")
        let queryItems = [
            URLQueryItem(name: "id", value: idsString),
            URLQueryItem(name: "convert", value: convert)
        ]
        return try await performRequest(endpoint: "/cryptocurrency/quotes/latest", queryItems: queryItems)
    }

    /// Get CoinMarketCap ID mapping for cryptocurrencies
    /// - Parameters:
    ///   - symbols: Optional filter by symbols (e.g., ["BTC", "ETH"])
    ///   - start: Starting rank (default: 1)
    ///   - limit: Number of results (default: 100, max: 5000)
    func getCryptocurrencyMap(
        symbols: [String]? = nil,
        start: Int = 1,
        limit: Int = 100
    ) async throws -> CoinMarketCapMapResponse {
        var queryItems = [
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        if let symbols = symbols {
            queryItems.append(URLQueryItem(name: "symbol", value: symbols.joined(separator: ",")))
        }

        return try await performRequest(endpoint: "/cryptocurrency/map", queryItems: queryItems)
    }

    /// Search for cryptocurrency by symbol and get its CoinMarketCap ID
    /// - Parameter symbol: Cryptocurrency symbol (e.g., "BTC")
    /// - Returns: CoinMarketCap ID or nil if not found
    func searchCryptocurrency(symbol: String) async throws -> Int? {
        let response: CoinMarketCapMapResponse = try await getCryptocurrencyMap(
            symbols: [symbol],
            start: 1,
            limit: 1
        )
        return response.data.first?.id
    }

    /// Batch fetch prices for multiple cryptocurrencies
    /// - Parameters:
    ///   - symbols: Array of crypto symbols
    ///   - convert: Currency to convert to
    /// - Returns: Dictionary mapping symbol to price
    func batchFetchPrices(
        symbols: [String],
        convert: String = "USD"
    ) async throws -> [String: Double] {
        let response = try await getQuotes(symbols: symbols, convert: convert)

        var prices: [String: Double] = [:]
        for (symbol, data) in response.data {
            if let quote = data.quote[convert] {
                prices[symbol] = quote.price
            }
        }

        return prices
    }
}
