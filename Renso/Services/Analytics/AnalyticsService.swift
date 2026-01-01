import Foundation
import PostHog

// MARK: - Analytics Events

enum AnalyticsEvent: String {
    // User Actions
    case appLaunched = "app_launched"
    case appBackgrounded = "app_backgrounded"
    case appForegrounded = "app_foregrounded"

    // Wallet Events
    case walletCreated = "wallet_created"
    case walletEdited = "wallet_edited"
    case walletArchived = "wallet_archived"
    case walletDeleted = "wallet_deleted"

    // Transaction Events
    case transactionCreated = "transaction_created"
    case transactionEdited = "transaction_edited"
    case transactionDeleted = "transaction_deleted"
    case transactionCategorized = "transaction_categorized"

    // Transfer Events
    case transferCompleted = "transfer_completed"

    // Investment Events
    case cryptoHoldingAdded = "crypto_holding_added"
    case cryptoTransactionRecorded = "crypto_transaction_recorded"
    case stockHoldingAdded = "stock_holding_added"
    case stockTransactionRecorded = "stock_transaction_recorded"

    // Category Events
    case categoryCreated = "category_created"
    case categoryEdited = "category_edited"
    case categoryDeleted = "category_deleted"

    // Rule Events
    case ruleCreated = "rule_created"
    case ruleEdited = "rule_edited"
    case ruleDeleted = "rule_deleted"
    case ruleApplied = "rule_applied"

    // Sync Events
    case monobankSyncStarted = "monobank_sync_started"
    case monobankSyncCompleted = "monobank_sync_completed"
    case monobankSyncFailed = "monobank_sync_failed"
    case monobankTokenConfigured = "monobank_token_configured"

    // Analytics Events
    case chartViewed = "chart_viewed"
    case filterApplied = "filter_applied"
    case exportStarted = "export_started"
    case exportCompleted = "export_completed"

    // Settings Events
    case settingsChanged = "settings_changed"
    case currencyChanged = "currency_changed"
}

enum AnalyticsScreen: String {
    case dashboard = "dashboard"
    case transactions = "transactions"
    case transactionDetail = "transaction_detail"
    case createTransaction = "create_transaction"
    case analytics = "analytics"
    case settings = "settings"
    case wallets = "wallets"
    case walletDetail = "wallet_detail"
    case createWallet = "create_wallet"
    case investments = "investments"
    case cryptoDetail = "crypto_detail"
    case stockDetail = "stock_detail"
    case categories = "categories"
    case rules = "rules"
    case createRule = "create_rule"
    case monobank = "monobank_settings"
}

// MARK: - Analytics Service

final class AnalyticsService {
    static let shared = AnalyticsService()

    private var isConfigured = false

    private init() {}

    // MARK: - Setup

    func configure(apiKey: String) {
        guard !isConfigured else { return }

        let config = PostHogConfig(apiKey: apiKey)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        PostHogSDK.shared.setup(config)

        isConfigured = true
    }

    // MARK: - User Identification

    func identify(userId: String, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    func reset() {
        guard isConfigured else { return }
        PostHogSDK.shared.reset()
    }

    // MARK: - Event Tracking

    func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    func trackScreen(_ screen: AnalyticsScreen, properties: [String: Any]? = nil) {
        guard isConfigured else { return }
        PostHogSDK.shared.screen(screen.rawValue, properties: properties)
    }

    // MARK: - User Properties

    func setUserProperties(_ properties: [String: Any]) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify("", userProperties: properties)
    }

    func incrementUserProperty(_ key: String, by value: Double = 1) {
        guard isConfigured else { return }
        PostHogSDK.shared.identify("", userProperties: [key: value])
    }

    // MARK: - Feature Flags

    func isFeatureEnabled(_ key: String) -> Bool {
        guard isConfigured else { return false }
        return PostHogSDK.shared.isFeatureEnabled(key)
    }

    func getFeatureFlagPayload(_ key: String) -> Any? {
        guard isConfigured else { return nil }
        return PostHogSDK.shared.getFeatureFlagPayload(key)
    }

    // MARK: - Flush

    func flush() {
        guard isConfigured else { return }
        PostHogSDK.shared.flush()
    }

    // MARK: - Opt Out

    func optOut() {
        guard isConfigured else { return }
        PostHogSDK.shared.optOut()
    }

    func optIn() {
        guard isConfigured else { return }
        PostHogSDK.shared.optIn()
    }
}

// MARK: - Convenience Extensions

extension AnalyticsService {
    // Wallet tracking
    func trackWalletCreated(currencyCode: String, hasMonobank: Bool) {
        track(.walletCreated, properties: [
            "currency_code": currencyCode,
            "has_monobank": hasMonobank
        ])
    }

    // Transaction tracking
    func trackTransactionCreated(amount: Decimal, categoryName: String, isIncome: Bool) {
        track(.transactionCreated, properties: [
            "amount": NSDecimalNumber(decimal: amount).doubleValue,
            "category": categoryName,
            "is_income": isIncome
        ])
    }

    // Sync tracking
    func trackSyncCompleted(transactionsCount: Int, duration: TimeInterval) {
        track(.monobankSyncCompleted, properties: [
            "transactions_count": transactionsCount,
            "duration_seconds": duration
        ])
    }

    func trackSyncFailed(error: String) {
        track(.monobankSyncFailed, properties: [
            "error": error
        ])
    }

    // Investment tracking
    func trackCryptoAdded(symbol: String, quantity: Decimal) {
        track(.cryptoHoldingAdded, properties: [
            "symbol": symbol,
            "quantity": NSDecimalNumber(decimal: quantity).doubleValue
        ])
    }

    func trackStockAdded(symbol: String, quantity: Decimal) {
        track(.stockHoldingAdded, properties: [
            "symbol": symbol,
            "quantity": NSDecimalNumber(decimal: quantity).doubleValue
        ])
    }

    // Rule tracking
    func trackRuleCreated(ruleType: String, categoryName: String) {
        track(.ruleCreated, properties: [
            "rule_type": ruleType,
            "category": categoryName
        ])
    }

    func trackRuleApplied(ruleType: String, transactionCount: Int) {
        track(.ruleApplied, properties: [
            "rule_type": ruleType,
            "transaction_count": transactionCount
        ])
    }
}
