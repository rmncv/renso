import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case dashboard
    case transactions
    case analytics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .transactions: return "Transactions"
        case .analytics: return "Analytics"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gear"
        }
    }
}

@Observable
final class NavigationRouter {
    var selectedTab: Tab = .dashboard
    
    // Flag to show uncategorized transactions when switching to transactions tab
    var showUncategorizedTransactions = false

    // Navigation paths for each tab
    var dashboardPath = NavigationPath()
    var transactionsPath = NavigationPath()
    var analyticsPath = NavigationPath()
    var settingsPath = NavigationPath()

    func resetToRoot() {
        dashboardPath = NavigationPath()
        transactionsPath = NavigationPath()
        analyticsPath = NavigationPath()
        settingsPath = NavigationPath()
    }

    func navigate<T: Hashable>(to destination: T, in tab: Tab) {
        selectedTab = tab
        switch tab {
        case .dashboard:
            dashboardPath.append(destination)
        case .transactions:
            transactionsPath.append(destination)
        case .analytics:
            analyticsPath.append(destination)
        case .settings:
            settingsPath.append(destination)
        }
    }

    func pop(in tab: Tab) {
        switch tab {
        case .dashboard:
            if !dashboardPath.isEmpty { dashboardPath.removeLast() }
        case .transactions:
            if !transactionsPath.isEmpty { transactionsPath.removeLast() }
        case .analytics:
            if !analyticsPath.isEmpty { analyticsPath.removeLast() }
        case .settings:
            if !settingsPath.isEmpty { settingsPath.removeLast() }
        }
    }
    
    func navigateToUncategorizedTransactions() {
        showUncategorizedTransactions = true
        selectedTab = .transactions
    }
}

// MARK: - Navigation Destinations

enum WalletDestination: Hashable {
    case detail(Wallet)
    case create
    case edit(Wallet)
    case transfer
}

enum TransactionDestination: Hashable {
    case detail(Transaction)
    case create(wallet: Wallet?)
    case filters
}

enum InvestmentDestination: Hashable {
    case cryptoDetail(CryptoHolding)
    case stockDetail(StockHolding)
    case addCrypto
    case addStock
    case recordCryptoTransaction(CryptoHolding)
    case recordStockTransaction(StockHolding)
}

enum SettingsDestination: Hashable {
    case monobank
    case wallets
    case investments
    case categories
    case createCategory
    case subCategories(Category)
    case rules
    case createRule
    case currency
    case about
}
