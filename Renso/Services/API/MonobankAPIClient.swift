import Foundation

// MARK: - DTOs

struct MonobankClientInfo: Codable {
    let clientId: String
    let name: String
    let webHookUrl: String?
    let permissions: String?
    let accounts: [MonobankAccount]
}

struct MonobankAccount: Codable {
    let id: String
    let sendId: String
    let balance: Int64
    let creditLimit: Int64
    let type: String
    let currencyCode: Int
    let cashbackType: String?
    let maskedPan: [String]?
    let iban: String?
}

struct MonobankStatementItem: Codable {
    let id: String
    let time: Int64
    let description: String
    let mcc: Int
    let originalMcc: Int?
    let hold: Bool
    let amount: Int64
    let operationAmount: Int64
    let currencyCode: Int
    let commissionRate: Int64
    let cashbackAmount: Int64
    let balance: Int64
    let comment: String?
    let receiptId: String?
    let invoiceId: String?
    let counterEdrpou: String?
    let counterIban: String?
    let counterName: String?
}

struct MonobankCurrencyRate: Codable {
    let currencyCodeA: Int
    let currencyCodeB: Int
    let date: Int64
    let rateSell: Double?
    let rateBuy: Double?
    let rateCross: Double?
}

struct MonobankWebhookRequest: Codable {
    let webHookUrl: String
}

// MARK: - API Client

enum MonobankAPIError: LocalizedError {
    case invalidURL
    case noToken
    case rateLimitExceeded
    case unauthorized
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case serverError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noToken:
            return "Monobank token not configured"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before making another request"
        case .unauthorized:
            return "Unauthorized. Please check your Monobank token"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        }
    }
}

@MainActor
final class MonobankAPIClient {
    private let baseURL = "https://api.monobank.ua"
    private let session: URLSession
    private var token: String?

    // Note: Rate limiting is now handled by SyncQueueService
    // which queues requests with 60-second delays between them

    init(token: String? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.token = token
    }

    func setToken(_ token: String) {
        self.token = token
    }

    // MARK: - Request Builder

    private func buildRequest(endpoint: String, requiresAuth: Bool = true) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw MonobankAPIError.invalidURL
        }

        var request = URLRequest(url: url)

        if requiresAuth {
            guard let token = token else {
                throw MonobankAPIError.noToken
            }
            request.setValue(token, forHTTPHeaderField: "X-Token")
        }

        return request
    }

    // MARK: - Generic Request Handler

    private func performRequest<T: Decodable>(
        endpoint: String,
        requiresAuth: Bool = true
    ) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, requiresAuth: requiresAuth)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MonobankAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                throw MonobankAPIError.decodingError(error)
            }

        case 401:
            throw MonobankAPIError.unauthorized

        case 429:
            throw MonobankAPIError.rateLimitExceeded

        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw MonobankAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }

    // MARK: - API Endpoints

    /// Get client info and accounts
    /// Rate limit: 1 request per 60 seconds
    func getClientInfo() async throws -> MonobankClientInfo {
        return try await performRequest(endpoint: "/personal/client-info")
    }

    /// Get account statement
    /// - Parameters:
    ///   - accountId: Account ID from client info
    ///   - from: Start date (Unix timestamp in seconds)
    ///   - to: End date (Unix timestamp in seconds). Max 31 days + 1 hour from `from`
    /// Rate limit: 1 request per 60 seconds
    func getStatement(
        accountId: String,
        from: Int64,
        to: Int64
    ) async throws -> [MonobankStatementItem] {
        let endpoint = "/personal/statement/\(accountId)/\(from)/\(to)"
        return try await performRequest(endpoint: endpoint)
    }

    /// Get currency exchange rates (public endpoint, no auth required)
    /// No rate limit for this endpoint
    func getCurrencyRates() async throws -> [MonobankCurrencyRate] {
        return try await performRequest(
            endpoint: "/bank/currency",
            requiresAuth: false
        )
    }

    /// Set webhook URL
    /// - Parameter webhookUrl: URL to receive transaction notifications
    /// Note: Rate limiting handled by SyncQueueService
    func setWebhook(url: String) async throws {
        var request = try buildRequest(endpoint: "/personal/webhook")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = MonobankWebhookRequest(webHookUrl: url)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MonobankAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return

        case 401:
            throw MonobankAPIError.unauthorized

        case 429:
            throw MonobankAPIError.rateLimitExceeded

        default:
            let errorMessage = String(data: data, encoding: .utf8)
            throw MonobankAPIError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
}
