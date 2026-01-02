import Foundation
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: "com.denysrumiantsev.Renso", category: "Settings")

@MainActor
@Observable
final class SettingsViewModel {
    private let modelContext: ModelContext
    private let syncService: MonobankSyncService
    private let syncQueueService: SyncQueueService
    private let keychain: KeychainService
    private let analytics: AnalyticsService
    private var cancellables = Set<AnyCancellable>()

    // State
    var settings: UserSettings?
    var isLoading = false
    var isSyncing = false
    var isValidating = false
    var errorMessage: String?
    var successMessage: String?

    // Monobank
    var hasMonobankToken = false
    var isMonobankConnected = false
    var monobankClientName: String?
    var monobankAccountsCount: Int = 0
    var lastSyncDate: Date?

    // Currency
    var baseCurrency: String = "UAH"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.syncService = MonobankSyncService(modelContext: modelContext)
        self.syncQueueService = SyncQueueService.shared
        self.keychain = KeychainService.shared
        self.analytics = AnalyticsService.shared
        
        // Configure sync queue service
        syncQueueService.configure(modelContext: modelContext)
        
        // Observe sync status
        observeSyncStatus()

        loadSettings()
        checkMonobankToken()
    }
    
    private func observeSyncStatus() {
        syncQueueService.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status {
                case .completed(let accounts, let transactions):
                    self.isSyncing = false
                    self.successMessage = "Synced \(transactions) transactions from \(accounts) accounts"
                    self.lastSyncDate = Date()
                    self.loadSettings()
                    logger.info("✅ Sync completed via queue")
                    
                case .failed(let error):
                    self.isSyncing = false
                    self.errorMessage = "Sync failed: \(error)"
                    logger.error("❌ Sync failed: \(error)")
                    
                case .syncing, .waitingForRateLimit:
                    self.isSyncing = true
                    
                case .idle:
                    break
                }
            }
            .store(in: &cancellables)
        
        syncQueueService.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                self?.isSyncing = isProcessing
            }
            .store(in: &cancellables)
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
        // Check if token is configured in Secrets
        hasMonobankToken = syncService.hasToken
    }
    
    /// Validates the Monobank connection by fetching client info
    func validateMonobankConnection() async {
        guard hasMonobankToken else {
            errorMessage = "Monobank token not configured"
            isMonobankConnected = false
            return
        }
        
        isValidating = true
        errorMessage = nil
        
        do {
            let clientInfo = try await syncService.validateToken()
            isMonobankConnected = true
            monobankClientName = clientInfo.name
            monobankAccountsCount = clientInfo.accounts.count
            
            settings?.hasMonobankToken = true
            try? modelContext.save()
        } catch {
            isMonobankConnected = false
            monobankClientName = nil
            monobankAccountsCount = 0
            errorMessage = "Connection failed: \(error.localizedDescription)"
        }
        
        isValidating = false
    }

    func syncWithMonobank() async {
        guard hasMonobankToken else {
            errorMessage = "Please configure Monobank token first"
            return
        }

        logger.info("🔄 Manual sync triggered from Settings")
        isSyncing = true
        errorMessage = nil
        successMessage = nil

        analytics.track(.monobankSyncStarted)
        
        // Use queue service with full account refresh for manual sync
        syncQueueService.enqueueFullSyncWithAccountRefresh()
        
        // The sync status will be updated via the observer
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
