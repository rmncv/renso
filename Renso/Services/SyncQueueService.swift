import Foundation
import SwiftData
import Combine
import os.log

private let logger = Logger(subsystem: "com.denysrumiantsev.Renso", category: "SyncQueue")

// MARK: - Sync Task

enum SyncTaskType: String, Codable {
    case fetchClientInfo
    case fetchStatement
}

struct SyncTask: Identifiable, Equatable {
    let id: UUID
    let type: SyncTaskType
    let accountId: String?
    let createdAt: Date
    
    init(type: SyncTaskType, accountId: String? = nil) {
        self.id = UUID()
        self.type = type
        self.accountId = accountId
        self.createdAt = Date()
    }
    
    static func == (lhs: SyncTask, rhs: SyncTask) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sync Status

enum SyncStatus: Equatable {
    case idle
    case syncing(progress: String)
    case waitingForRateLimit(secondsRemaining: Int)
    case completed(accountsCount: Int, transactionsCount: Int)
    case failed(error: String)
}

// MARK: - Sync Queue Service

@MainActor
final class SyncQueueService: ObservableObject {
    static let shared = SyncQueueService()
    
    // MARK: - Published State
    
    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var pendingTasksCount: Int = 0
    @Published private(set) var lastSuccessfulSync: Date?
    
    // MARK: - Private Properties
    
    private var modelContext: ModelContext?
    private var syncService: MonobankSyncService?
    private var apiClient: MonobankAPIClient?
    
    private var taskQueue: [SyncTask] = []
    private var processingTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    
    private let rateLimitInterval: TimeInterval = 60 // Monobank rate limit: 60 seconds
    private var lastApiCallTime: Date?
    
    // Sync results tracking
    private var syncedAccountsCount: Int = 0
    private var syncedTransactionsCount: Int = 0
    
    // Saved account IDs for quick sync
    private let savedAccountIdsKey = "monobank_account_ids"
    
    // MARK: - Initialization
    
    private init() {}
    
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.syncService = MonobankSyncService(modelContext: modelContext)
        self.apiClient = MonobankAPIClient(token: Secrets.monobankToken)
        
        // Load last sync time from UserSettings
        loadLastSyncTime()
        
        logger.info("🔧 SyncQueueService configured")
        logger.info("📅 Last successful sync: \(self.lastSuccessfulSync?.description ?? "Never")")
    }
    
    // MARK: - Public API
    
    /// Enqueue a full sync (accounts + transactions for all accounts)
    /// Uses saved account IDs for faster sync, falls back to fetching client info if none saved
    func enqueueFullSync() {
        logger.info("📥 enqueueFullSync called")
        
        guard !Secrets.monobankToken.isEmpty else {
            logger.error("❌ Monobank token not configured")
            status = .failed(error: "Monobank token not configured")
            return
        }
        
        // Clear any existing queue and start fresh
        taskQueue.removeAll()
        syncedAccountsCount = 0
        syncedTransactionsCount = 0
        
        // Try to use saved account IDs first for faster sync
        var accountIds = savedAccountIds
        
        // If no saved IDs, try to load from existing wallets
        if accountIds.isEmpty {
            accountIds = loadAccountIdsFromWallets()
        }
        
        if !accountIds.isEmpty {
            // We have saved account IDs - queue transaction fetches directly
            logger.info("⚡ Using \(accountIds.count) saved account ID(s) for fast sync")
            syncedAccountsCount = accountIds.count
            
            for accountId in accountIds {
                taskQueue.append(SyncTask(type: .fetchStatement, accountId: accountId))
                logger.info("📋 Queued statement fetch for saved account: \(accountId)")
            }
        } else {
            // No saved account IDs - need to fetch client info first
            logger.info("🔄 No saved account IDs, fetching client info first")
            taskQueue.append(SyncTask(type: .fetchClientInfo))
        }
        
        pendingTasksCount = taskQueue.count
        logger.info("📋 Queue initialized with \(self.pendingTasksCount) task(s)")
        
        // Start processing if not already
        startProcessingIfNeeded()
    }
    
    /// Force a full sync that refreshes account info from Monobank
    /// Use this when you need to update account balances or detect new accounts
    func enqueueFullSyncWithAccountRefresh() {
        logger.info("📥 enqueueFullSyncWithAccountRefresh called")
        
        guard !Secrets.monobankToken.isEmpty else {
            logger.error("❌ Monobank token not configured")
            status = .failed(error: "Monobank token not configured")
            return
        }
        
        // Clear any existing queue and start fresh
        taskQueue.removeAll()
        syncedAccountsCount = 0
        syncedTransactionsCount = 0
        
        // Always fetch client info first to update accounts
        taskQueue.append(SyncTask(type: .fetchClientInfo))
        pendingTasksCount = taskQueue.count
        
        logger.info("📋 Queue initialized with account refresh")
        
        // Start processing if not already
        startProcessingIfNeeded()
    }
    
    /// Cancel all pending sync tasks
    func cancelSync() {
        processingTask?.cancel()
        countdownTask?.cancel()
        taskQueue.removeAll()
        pendingTasksCount = 0
        isProcessing = false
        status = .idle
    }
    
    /// Check if we should sync based on throttle interval
    func shouldSync(throttleInterval: TimeInterval = 30) -> Bool {
        guard let lastSync = lastSuccessfulSync else {
            logger.info("✅ shouldSync: true (never synced before)")
            return true
        }
        let timeSinceSync = Date().timeIntervalSince(lastSync)
        let should = timeSinceSync >= throttleInterval
        logger.info("🔍 shouldSync: \(should) (last sync \(Int(timeSinceSync))s ago, throttle: \(Int(throttleInterval))s)")
        return should
    }
    
    // MARK: - Private Methods
    
    private func startProcessingIfNeeded() {
        guard !isProcessing else {
            logger.info("⏸️ Already processing, skipping")
            return
        }
        guard !taskQueue.isEmpty else {
            logger.info("📭 Queue is empty, nothing to process")
            return
        }
        
        logger.info("🚀 Starting queue processing...")
        isProcessing = true
        processingTask = Task {
            await processQueue()
        }
    }
    
    private func processQueue() async {
        logger.info("🔄 processQueue started with \(self.taskQueue.count) task(s)")
        
        while !taskQueue.isEmpty {
            // Check if we need to wait for rate limit
            if let lastCall = lastApiCallTime {
                let timeSinceLastCall = Date().timeIntervalSince(lastCall)
                if timeSinceLastCall < rateLimitInterval {
                    let waitTime = Int(ceil(rateLimitInterval - timeSinceLastCall))
                    logger.info("⏳ Rate limit: waiting \(waitTime)s before next API call")
                    await waitForRateLimit(seconds: waitTime)
                }
            }
            
            // Get next task
            guard !taskQueue.isEmpty else { break }
            let task = taskQueue.removeFirst()
            pendingTasksCount = taskQueue.count
            
            logger.info("📤 Processing task: \(task.type.rawValue), remaining: \(self.pendingTasksCount)")
            
            // Process the task
            await processTask(task)
        }
        
        // All tasks completed
        isProcessing = false
        
        if syncedAccountsCount > 0 || syncedTransactionsCount > 0 {
            logger.info("✅ Sync completed: \(self.syncedAccountsCount) accounts, \(self.syncedTransactionsCount) transactions")
            status = .completed(accountsCount: syncedAccountsCount, transactionsCount: syncedTransactionsCount)
            lastSuccessfulSync = Date()
            saveLastSyncTime()
        } else {
            logger.info("⚠️ Sync finished but no data synced")
        }
    }
    
    private func waitForRateLimit(seconds: Int) async {
        for remaining in stride(from: seconds, through: 1, by: -1) {
            status = .waitingForRateLimit(secondsRemaining: remaining)
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if Task.isCancelled { return }
        }
    }
    
    private func processTask(_ task: SyncTask) async {
        switch task.type {
        case .fetchClientInfo:
            await fetchClientInfo()
            
        case .fetchStatement:
            if let accountId = task.accountId {
                await fetchStatement(accountId: accountId)
            }
        }
    }
    
    private func fetchClientInfo() async {
        guard let apiClient = apiClient, let syncService = syncService else {
            logger.error("❌ apiClient or syncService not configured")
            return
        }
        
        logger.info("📡 Fetching client info from Monobank...")
        status = .syncing(progress: "Fetching accounts...")
        lastApiCallTime = Date()
        
        do {
            // First sync currency rates (public endpoint, no rate limit)
            logger.info("💱 Syncing currency rates...")
            try await syncService.syncCurrencyRates()
            
            // Then fetch client info
            logger.info("👤 Fetching client info...")
            let clientInfo = try await apiClient.getClientInfo()
            logger.info("📊 Found \(clientInfo.accounts.count) account(s) for \(clientInfo.name)")
            
            // Sync accounts to wallets
            let wallets = try await syncService.syncAccountsFromClientInfo(clientInfo)
            syncedAccountsCount = wallets.count
            logger.info("💼 Synced \(wallets.count) wallet(s)")
            
            // Save account IDs for future fast syncs
            let accountIds = clientInfo.accounts.map { $0.id }
            saveAccountIds(accountIds)
            
            // Queue statement fetch for each account
            for account in clientInfo.accounts {
                taskQueue.append(SyncTask(type: .fetchStatement, accountId: account.id))
                logger.info("📋 Queued statement fetch for account: \(account.id)")
            }
            pendingTasksCount = taskQueue.count
            
        } catch {
            logger.error("❌ fetchClientInfo failed: \(error.localizedDescription)")
            status = .failed(error: error.localizedDescription)
            taskQueue.removeAll()
            pendingTasksCount = 0
        }
    }
    
    private func fetchStatement(accountId: String) async {
        guard let syncService = syncService else {
            logger.error("❌ syncService not configured")
            return
        }
        
        logger.info("📜 Fetching statement for account: \(accountId)")
        status = .syncing(progress: "Syncing transactions...")
        lastApiCallTime = Date()
        
        do {
            let count = try await syncService.syncTransactionsForAccount(accountId: accountId, daysBack: 30)
            syncedTransactionsCount += count
            logger.info("💳 Synced \(count) transaction(s) for account \(accountId)")
        } catch {
            // Log error but continue with other accounts
            logger.error("❌ Failed to sync account \(accountId): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadLastSyncTime() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            lastSuccessfulSync = settings.lastMonobankSync
        }
    }
    
    private func saveLastSyncTime() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.lastMonobankSync = lastSuccessfulSync
            try? modelContext.save()
        }
    }
    
    // MARK: - Account IDs Persistence
    
    private var savedAccountIds: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: savedAccountIdsKey) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: savedAccountIdsKey)
            logger.info("💾 Saved \(newValue.count) account ID(s)")
        }
    }
    
    private func saveAccountIds(_ accountIds: [String]) {
        savedAccountIds = accountIds
    }
    
    private func loadAccountIdsFromWallets() -> [String] {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Wallet>()
        guard let wallets = try? modelContext.fetch(descriptor) else { return [] }
        
        let accountIds = wallets.compactMap { $0.monobankAccountId }
        logger.info("📂 Loaded \(accountIds.count) account ID(s) from wallets")
        return accountIds
    }
}

