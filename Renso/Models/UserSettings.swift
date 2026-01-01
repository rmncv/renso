import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID = UUID()
    var baseCurrencyCode: String = "UAH"
    var hasMonobankToken: Bool = false
    var lastMonobankSync: Date?
    var autoSyncEnabled: Bool = true
    var syncIntervalMinutes: Int = 60
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // API Keys stored flag (actual keys in Keychain)
    var hasCoinMarketCapKey: Bool = false
    var hasPostHogKey: Bool = false

    // UI Preferences
    var showCentsInAmounts: Bool = true
    var defaultTransactionType: String = "expense"
    var enableHapticFeedback: Bool = true

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var syncInterval: TimeInterval {
        TimeInterval(syncIntervalMinutes * 60)
    }

    var shouldAutoSync: Bool {
        guard autoSyncEnabled, hasMonobankToken else { return false }

        if let lastSync = lastMonobankSync {
            return Date().timeIntervalSince(lastSync) >= syncInterval
        }
        return true
    }
}
