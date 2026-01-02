import Foundation
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: "com.denysrumiantsev.Renso", category: "Dashboard")

@MainActor
@Observable
final class DashboardViewModel {
    private let modelContext: ModelContext
    private let netWorthService: NetWorthService
    private let priceFetchService: PriceFetchService
    private let analytics: AnalyticsService
    private let syncQueueService: SyncQueueService

    // State
    var netWorth: NetWorthBreakdown?
    var recentTransactions: [Transaction] = []
    var uncategorizedCountThisMonth: Int = 0
    var isLoadingNetWorth = false
    var isLoadingTransactions = false
    var isRefreshingPrices = false
    var errorMessage: String?
    
    // Monobank sync state
    var syncStatus: SyncStatus = .idle
    var isSyncingMonobank = false
    
    // Throttle settings
    private static let minSyncInterval: TimeInterval = 30 // seconds
    
    // Combine
    private var cancellables = Set<AnyCancellable>()

    // Settings
    var baseCurrency: String = "UAH"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.netWorthService = NetWorthService(modelContext: modelContext)
        self.priceFetchService = PriceFetchService(modelContext: modelContext)
        self.analytics = AnalyticsService.shared
        self.syncQueueService = SyncQueueService.shared
        
        // Configure sync queue service
        syncQueueService.configure(modelContext: modelContext)
        
        // Observe sync status changes
        observeSyncStatus()

        loadBaseCurrency()
        loadData()
    }
    
    // MARK: - Sync Status Observation
    
    private func observeSyncStatus() {
        syncQueueService.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
                self?.isSyncingMonobank = self?.syncQueueService.isProcessing ?? false
                
                // Log status changes
                switch status {
                case .idle:
                    logger.info("📊 Sync status: idle")
                case .syncing(let progress):
                    logger.info("📊 Sync status: syncing - \(progress)")
                case .waitingForRateLimit(let seconds):
                    logger.info("📊 Sync status: waiting for rate limit (\(seconds)s)")
                case .completed(let accounts, let transactions):
                    logger.info("📊 Sync status: completed (\(accounts) accounts, \(transactions) transactions)")
                case .failed(let error):
                    logger.error("📊 Sync status: failed - \(error)")
                }
                
                // Refresh data when sync completes
                if case .completed = status {
                    Task { [weak self] in
                        await self?.refresh()
                    }
                }
            }
            .store(in: &cancellables)
        
        syncQueueService.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                self?.isSyncingMonobank = isProcessing
                logger.info("🔄 isProcessing changed to: \(isProcessing)")
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() {
        Task {
            await loadNetWorth()
            await loadRecentTransactions()
            await loadUncategorizedCount()
        }
    }

    func loadNetWorth() async {
        isLoadingNetWorth = true
        errorMessage = nil

        do {
            // Fetch latest prices if needed
            try await priceFetchService.fetchAllPrices()

            // Calculate net worth
            netWorth = netWorthService.calculateNetWorth(baseCurrency: baseCurrency)
        } catch {
            errorMessage = "Failed to load net worth: \(error.localizedDescription)"
        }

        isLoadingNetWorth = false
    }

    func loadRecentTransactions() async {
        isLoadingTransactions = true

        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )

        do {
            let allTransactions = try modelContext.fetch(descriptor)
            recentTransactions = Array(allTransactions.prefix(10))
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }

        isLoadingTransactions = false
    }
    
    func loadUncategorizedCount() async {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) else {
            return
        }
        
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        
        do {
            let allTransactions = try modelContext.fetch(descriptor)
            uncategorizedCountThisMonth = allTransactions.filter { transaction in
                transaction.category == nil &&
                transaction.date >= startOfMonth &&
                transaction.date <= endOfMonth
            }.count
        } catch {
            logger.error("Failed to load uncategorized count: \(error.localizedDescription)")
        }
    }

    // MARK: - Actions

    func refresh() async {
        await loadNetWorth()
        await loadRecentTransactions()
        await loadUncategorizedCount()
    }
    
    /// Trigger Monobank sync if enough time has passed since last sync
    func triggerMonobankSyncIfNeeded() {
        logger.info("🔄 triggerMonobankSyncIfNeeded called")
        
        // Check if Monobank is configured
        guard !Secrets.monobankToken.isEmpty else {
            logger.info("⏭️ Skipping sync: Monobank token not configured")
            return
        }
        
        // Check if enough time has passed (30 seconds throttle)
        guard syncQueueService.shouldSync(throttleInterval: Self.minSyncInterval) else {
            logger.info("⏭️ Skipping sync: throttle interval not passed")
            return
        }
        
        // Don't start a new sync if one is already in progress
        guard !syncQueueService.isProcessing else {
            logger.info("⏭️ Skipping sync: already processing")
            return
        }
        
        logger.info("✅ Starting Monobank sync...")
        // Enqueue the sync
        syncQueueService.enqueueFullSync()
    }

    func refreshPrices() async {
        isRefreshingPrices = true

        do {
            try await priceFetchService.forceRefreshAllPrices()
            await loadNetWorth()
            analytics.track(.chartViewed, properties: ["type": "net_worth_refresh"])
        } catch {
            errorMessage = "Failed to refresh prices: \(error.localizedDescription)"
        }

        isRefreshingPrices = false
    }

    // MARK: - Helpers

    private func loadBaseCurrency() {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            baseCurrency = settings.baseCurrencyCode
        }
    }

    // MARK: - Computed Properties

    var totalNetWorthFormatted: String {
        guard let netWorth = netWorth else { return "—" }
        return Formatters.currency(netWorth.totalInBaseCurrency, currencyCode: baseCurrency)
    }

    var hasInvestments: Bool {
        guard let netWorth = netWorth else { return false }
        return netWorth.cryptoValue > 0 || netWorth.stocksValue > 0
    }

    var walletsCount: Int {
        netWorth?.walletBreakdown.count ?? 0
    }

    var cryptoHoldingsCount: Int {
        netWorth?.cryptoBreakdown.count ?? 0
    }

    var stockHoldingsCount: Int {
        netWorth?.stockBreakdown.count ?? 0
    }
}
