import Foundation
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    private let modelContext: ModelContext
    private let syncService: MonobankSyncService
    private let keychain: KeychainService
    private let analytics: AnalyticsService

    // State
    var settings: UserSettings?
    var isLoading = false
    var isSyncing = false
    var errorMessage: String?
    var successMessage: String?

    // Monobank
    var hasMonobankToken = false
    var lastSyncDate: Date?

    // Currency
    var baseCurrency: String = "UAH"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.syncService = MonobankSyncService(modelContext: modelContext)
        self.keychain = KeychainService.shared
        self.analytics = AnalyticsService.shared

        loadSettings()
        checkMonobankToken()
    }

    // MARK: - Data Loading

    func loadSettings() {
        isLoading = true

        let descriptor = FetchDescriptor<UserSettings>()

        do {
            let allSettings = try modelContext.fetch(descriptor)

            if let existing = allSettings.first {
                settings = existing
            } else {
                // Create default settings
                let newSettings = UserSettings()
                newSettings.baseCurrencyCode = "UAH"
                modelContext.insert(newSettings)
                try modelContext.save()
                settings = newSettings
            }

            baseCurrency = settings?.baseCurrencyCode ?? "UAH"
            lastSyncDate = settings?.lastMonobankSync
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Monobank

    func checkMonobankToken() {
        hasMonobankToken = keychain.exists(for: .monobankToken)

        if let token = keychain.monobankToken {
            syncService.setToken(token)
        }
    }

    func saveMonobankToken(_ token: String) {
        keychain.monobankToken = token
        syncService.setToken(token)
        checkMonobankToken()

        settings?.hasMonobankToken = true
        try? modelContext.save()

        successMessage = "Monobank token saved successfully"
        analytics.track(.monobankTokenConfigured)
    }

    func removeMonobankToken() {
        keychain.monobankToken = nil
        checkMonobankToken()

        settings?.hasMonobankToken = false
        settings?.lastMonobankSync = nil
        try? modelContext.save()

        successMessage = "Monobank token removed"
    }

    func syncWithMonobank() async {
        guard hasMonobankToken else {
            errorMessage = "Please configure Monobank token first"
            return
        }

        isSyncing = true
        errorMessage = nil
        successMessage = nil

        analytics.track(.monobankSyncStarted)
        let startTime = Date()

        do {
            let result = try await syncService.performFullSync()

            let duration = Date().timeIntervalSince(startTime)
            lastSyncDate = Date()

            successMessage = "Synced \(result.transactionsCount) transactions from \(result.accountsCount) accounts"

            analytics.trackSyncCompleted(
                transactionsCount: result.transactionsCount,
                duration: duration
            )
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
            analytics.trackSyncFailed(error: error.localizedDescription)
        }

        isSyncing = false
        loadSettings()
    }

    // MARK: - Currency

    func updateBaseCurrency(_ currencyCode: String) {
        settings?.baseCurrencyCode = currencyCode
        baseCurrency = currencyCode

        do {
            try modelContext.save()
            successMessage = "Base currency updated to \(currencyCode)"
            analytics.track(.currencyChanged, properties: ["currency": currencyCode])
        } catch {
            errorMessage = "Failed to update currency: \(error.localizedDescription)"
        }
    }

    // MARK: - Auto-Sync

    func toggleAutoSync() {
        guard let settings = settings else { return }

        settings.autoSyncEnabled.toggle()

        do {
            try modelContext.save()
            analytics.track(.settingsChanged, properties: ["auto_sync": settings.autoSyncEnabled])
        } catch {
            errorMessage = "Failed to update auto-sync: \(error.localizedDescription)"
        }
    }

    func updateSyncInterval(_ minutes: Int) {
        settings?.syncIntervalMinutes = minutes

        do {
            try modelContext.save()
            analytics.track(.settingsChanged, properties: ["sync_interval": minutes])
        } catch {
            errorMessage = "Failed to update sync interval: \(error.localizedDescription)"
        }
    }

    // MARK: - CoinMarketCap API

    func saveCoinMarketCapAPIKey(_ apiKey: String) {
        keychain.coinmarketcapAPIKey = apiKey
        successMessage = "CoinMarketCap API key saved"
        analytics.track(.settingsChanged, properties: ["coinmarketcap_configured": true])
    }

    func removeCoinMarketCapAPIKey() {
        keychain.coinmarketcapAPIKey = nil
        successMessage = "CoinMarketCap API key removed"
    }

    var hasCoinMarketCapAPIKey: Bool {
        keychain.exists(for: .coinmarketcapAPIKey)
    }

    // MARK: - Analytics

    func toggleAnalytics() {
        // Toggle PostHog opt-in/opt-out
        if analytics.isFeatureEnabled("analytics_enabled") {
            analytics.optOut()
        } else {
            analytics.optIn()
        }

        analytics.track(.settingsChanged, properties: ["analytics_enabled": !analytics.isFeatureEnabled("analytics_enabled")])
    }

    // MARK: - Data Management

    func exportData() async -> URL? {
        // TODO: Implement data export
        return nil
    }

    func clearAllData() {
        // TODO: Implement with confirmation dialog
    }

    // MARK: - Computed Properties

    var autoSyncEnabled: Bool {
        settings?.autoSyncEnabled ?? false
    }

    var syncIntervalMinutes: Int {
        settings?.syncIntervalMinutes ?? 60
    }

    var lastSyncText: String {
        guard let date = lastSyncDate else {
            return "Never"
        }

        return Formatters.smartDate(date)
    }

    var canSync: Bool {
        hasMonobankToken && !isSyncing
    }
}
