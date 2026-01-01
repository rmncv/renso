# Renso - iOS Finance Tracker Implementation Plan

## Overview
Build a comprehensive iOS finance tracking app with Monobank API integration, multi-currency wallet management, crypto/stock portfolio tracking, and automatic transaction categorization.

## Tech Stack
- Swift, SwiftUI, MVVM architecture
- SwiftData + CloudKit sync
- XcodeGen for project generation (https://github.com/yonaskolb/XcodeGen)

## User Preferences
- **Architecture**: Single target first, folder-based organization (modularize later)
- **Investments**: Track individual buy/sell transactions, auto-calculate weighted average price
- **Rules**: User-creatable rules from the start (full UI)
- **Base Currency**: UAH (Ukrainian Hryvnia) as default
- **Price APIs**: Fetch crypto (CoinMarketCap) and stock (Yahoo Finance) prices via API
- **Refunds**: Link refund income to expense category to reduce displayed total
- **Categories**: Support sub-categories for expenses/income
- **Analytics**: PostHog for user analytics and event tracking

---

## Phase 1: Project Foundation

### 1.1 Create AGENTS.md
Create `/Users/rumiantsevd/Renso/AGENTS.md` with complete project requirements, architecture decisions, and implementation guidelines for AI assistants.

### 1.2 Project Structure (XcodeGen)
Use XcodeGen with `project.yml` for project generation.

**Dependencies (via SPM):**
- `posthog-ios` - Analytics and event tracking

```
Renso/
├── project.yml              # XcodeGen configuration
├── AGENTS.md
├── Renso/
│   ├── App/
│   │   ├── RensoApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── Wallet.swift
│   │   ├── Transaction.swift
│   │   ├── Category.swift
│   │   ├── SubCategory.swift
│   │   ├── Rule.swift
│   │   ├── Transfer.swift
│   │   ├── CryptoHolding.swift
│   │   ├── CryptoTransaction.swift
│   │   ├── StockHolding.swift
│   │   ├── StockTransaction.swift
│   │   ├── ExchangeRate.swift
│   │   └── UserSettings.swift
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift
│   │   ├── WalletsViewModel.swift
│   │   ├── TransactionsViewModel.swift
│   │   ├── AnalyticsViewModel.swift
│   │   ├── InvestmentsViewModel.swift
│   │   ├── TransferViewModel.swift
│   │   ├── CategoriesViewModel.swift
│   │   ├── RulesViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── Dashboard/
│   │   ├── Transactions/
│   │   ├── Analytics/
│   │   ├── Settings/
│   │   ├── Wallets/
│   │   ├── Investments/
│   │   └── Components/
│   ├── Services/
│   │   ├── API/
│   │   │   ├── MonobankAPIClient.swift
│   │   │   ├── CoinMarketCapAPIClient.swift
│   │   │   └── YahooFinanceAPIClient.swift
│   │   ├── Analytics/
│   │   │   └── AnalyticsService.swift
│   │   ├── MonobankSyncService.swift
│   │   ├── PriceFetchService.swift
│   │   ├── RulesEngine.swift
│   │   ├── NetWorthService.swift
│   │   ├── CurrencyConverter.swift
│   │   ├── KeychainService.swift
│   │   └── DataSeeder.swift
│   ├── Utilities/
│   │   ├── ISO4217.swift
│   │   ├── Formatters.swift
│   │   └── Extensions/
│   ├── Navigation/
│   │   └── NavigationRouter.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   └── Info.plist
│   └── Renso.entitlements
└── Tuist.swift              # Can be deleted (using XcodeGen)
```

### 1.3 Configure CloudKit
**File:** `Renso/Renso.entitlements`
- Add iCloud container identifier: `iCloud.com.denysrumiantsev.Renso`

---

## Phase 2: Data Models

**Location:** `Renso/Models/`

### SwiftData Models to Create:

1. **Wallet.swift**
   - Properties: id, name, currencyCode, initialBalance, currentBalance, iconName, colorHex, isArchived, sortOrder
   - Monobank fields: monobankAccountId, monobankIBAN, monobankCardType, lastSyncDate
   - Relationships: transactions, outgoingTransfers, incomingTransfers

2. **Transaction.swift**
   - Properties: id, externalId, amount, originalAmount, originalCurrencyCode, description, **note** (user-editable), date, isHold, mcc, cashbackAmount, commissionAmount, balanceAfter
   - **Refund linking**: refundForCategory (optional) - links income refund to expense category
   - Relationships: wallet, category, subCategory, rule, refundForCategory

3. **Category.swift** (Parent category)
   - Properties: id, name, iconName (SF Symbol), colorHex, type (expense/income), isDefault, sortOrder, isArchived
   - Relationships: transactions, rules, subCategories, parentCategory (for nesting)

4. **SubCategory.swift** (or use Category with parent relationship)
   - Properties: id, name, iconName, colorHex, sortOrder
   - Relationships: parentCategory, transactions

5. **Rule.swift**
   - Properties: id, name, ruleType (mcc/description/descriptionExact/amount), matchValue, isActive, priority
   - Relationships: category, subCategory, appliedTransactions

6. **Transfer.swift**
   - Properties: id, amount, convertedAmount, **manualExchangeRate** (user-settable), note, date
   - Relationships: sourceWallet, destinationWallet

7. **CryptoHolding.swift**
   - Properties: id, symbol, name, quantity, averagePurchasePrice, purchaseCurrencyCode, **lastPrice** (from API), lastPriceUpdate, coinmarketcapId
   - Relationships: transactions (CryptoTransaction)

8. **CryptoTransaction.swift**
   - Properties: id, type (buy/sell/transfer), quantity, pricePerUnit, totalAmount, fee, date, note
   - Relationship: holding

9. **StockHolding.swift**
   - Properties: id, symbol, companyName, exchange, quantity, averagePurchasePrice, purchaseCurrencyCode, **lastPrice** (from API), lastPriceUpdate, yahooTicker
   - Relationships: transactions (StockTransaction)

10. **StockTransaction.swift**
    - Properties: id, type (buy/sell/dividend/split), quantity, pricePerShare, totalAmount, fee, date, note
    - Relationship: holding

11. **ExchangeRate.swift**
    - Properties: id, fromCurrencyCode, toCurrencyCode, rate, buyRate, sellRate, source, fetchedAt

12. **UserSettings.swift**
    - Properties: id, baseCurrencyCode, hasMonobankToken, lastMonobankSync, autoSyncEnabled, syncIntervalMinutes

### Supporting Files:
- `Utilities/ISO4217.swift` - Currency code mappings (numeric ↔ alpha)
- `Models/ModelContainerSetup.swift` - Schema and container configuration

---

## Phase 3: Networking & Services

**Location:** `Renso/Services/`

### 3.1 Monobank API Client
**File:** `API/MonobankAPIClient.swift`

**Endpoints:**
- `GET /personal/client-info` - Get accounts
- `GET /personal/statement/{account}/{from}/{to}` - Get transactions
- `GET /bank/currency` - Get exchange rates (public)
- `POST /personal/webhook` - Set webhook URL

**DTOs:** `MonobankDTOs.swift` - ClientInfo, Account, StatementItem, CurrencyRate

### 3.2 CoinMarketCap API Client (Crypto prices)
**File:** `API/CoinMarketCapAPIClient.swift`
- `GET /v1/cryptocurrency/quotes/latest` - Get current prices
- `GET /v1/cryptocurrency/info` - Get coin metadata
- `GET /v1/cryptocurrency/map` - List all cryptocurrencies
- Requires API key (free tier: 10,000 calls/month)

### 3.3 Yahoo Finance API Client (Stock prices)
**File:** `API/YahooFinanceAPIClient.swift`
- Get current stock prices by ticker
- Get historical data
- Search for stocks by symbol/name

### 3.4 PriceFetchService
**File:** `PriceFetchService.swift`
- Batch fetch crypto prices from CoinMarketCap
- Batch fetch stock prices from Yahoo Finance
- Update holdings with latest prices
- Background refresh scheduling

### 3.5 KeychainService
**File:** `KeychainService.swift` - Secure storage for Monobank token

### 3.6 MonobankSyncService
- Sync accounts from Monobank
- Sync transactions with duplicate detection
- Sync currency rates
- Handle rate limiting (60s between requests)

### 3.7 RulesEngine
- Match transactions by MCC code
- Match by description (contains/exact)
- Match by amount range
- Priority-based rule application (MCC=10, Description=20, User=30+)
- Support sub-category assignment

### 3.8 NetWorthService
- Calculate total across wallets (with currency conversion to UAH)
- Calculate crypto portfolio value (using API prices)
- Calculate stock portfolio value (using API prices)
- **Refund deduction**: Subtract refunds from expense category totals
- Return breakdown percentages

### 3.9 CurrencyConverter
- Convert between currencies using stored rates
- Get rate between two currencies

### 3.10 DataSeeder
- Seed default expense categories with sub-categories
- Seed default income categories with sub-categories
- Seed default MCC-based rules
- Create initial UserSettings with UAH as base currency

### 3.11 AnalyticsService (PostHog)
**File:** `Analytics/AnalyticsService.swift`
**Dependency:** `posthog-ios` via SPM
- Initialize PostHog with API key
- Track events: transaction_created, wallet_created, transfer_completed, sync_started, etc.
- Track screens: dashboard_viewed, transactions_viewed, analytics_viewed, settings_viewed
- User identification (anonymous by default, optional sign-in)
- Feature flags support for A/B testing

---

## Phase 4: Views & ViewModels

### 4 Tabs: Dashboard, Transactions, Analytics, Settings

### 4.1 Dashboard Tab
**ViewModel:** `DashboardViewModel`
**Views:**
- `DashboardView` - Main dashboard with overview
- `NetWorthCard` - Summary with breakdown chart (wallets, crypto, stocks)
- `InsightsSection` - Quick insights (spending trends, etc.)
- `RecentTransactionsWidget` - Latest transactions list
- `QuickActionsBar` - Add transaction, transfer, sync

### 4.2 Transactions Tab
**ViewModel:** `TransactionsViewModel`
**Views:**
- `TransactionsListView` - All transactions with filtering
- `TransactionDetailView` - Single transaction with **note editing**
- `CreateTransactionView` - Manual transaction entry
- `TransactionFiltersSheet` - Date/category/wallet/subcategory filters

### 4.3 Analytics Tab
**ViewModel:** `AnalyticsViewModel`
**Views:**
- `AnalyticsView` - Main analytics dashboard
- `SpendingByCategoryChart` - Pie/bar chart by category (with refunds deducted)
- `IncomeVsExpenseChart` - Income vs expense over time
- `TrendCharts` - Monthly/weekly trends
- `CategoryBreakdownView` - Drill-down into category with sub-categories

### 4.4 Settings Tab
**ViewModels:** `SettingsViewModel`, `CategoriesViewModel`, `RulesViewModel`
**Views:**
- `SettingsView` - Main settings menu
- `MonobankSetupView` - Token configuration
- `WalletsManagementView` - Manage all wallets
- `InvestmentsManagementView` - Manage crypto/stocks
- `CategoriesView`, `CreateCategoryView`, `SubCategoriesView` - Category management with sub-categories
- `RulesView`, `CreateRuleView` - User-creatable auto-categorization rules
- `CurrencySettingsView` - Base currency selection

### 4.5 Shared Views (accessible from multiple tabs)

**Wallets:**
- `WalletsListView`, `WalletDetailView`, `CreateWalletView`, `EditWalletView`

**Investments (Crypto + Stocks):**
- `InvestmentsView` - Combined overview with live prices
- `CryptoListView`, `CryptoDetailView`, `AddCryptoView`, `RecordCryptoTransactionView`
- `StockListView`, `StockDetailView`, `AddStockView`, `RecordStockTransactionView`

**Transfer:**
- `TransferView` - Transfer form with **manual exchange rate** option
- `TransferConfirmationView` - Review before executing
- `TransferHistoryView` - Past transfers

---

## Phase 5: Navigation & App Entry

**Location:** `Renso/`

### Navigation Architecture
- `NavigationRouter.swift` - Centralized navigation state
- `Tab` enum: **dashboard, transactions, analytics, settings** (4 tabs)

### Main Files
- `App/RensoApp.swift` - App entry with ModelContainer
- `App/ContentView.swift` - TabView with **4 tabs**
- `Navigation/NavigationRouter.swift` - Tab and navigation state

---

## Default Categories

### Expenses (13)
| Name | SF Symbol | Color |
|------|-----------|-------|
| Groceries | cart.fill | #34C759 |
| Restaurants | fork.knife | #FF9500 |
| Transport | car.fill | #007AFF |
| Entertainment | theatermasks.fill | #AF52DE |
| Shopping | bag.fill | #FF2D55 |
| Health | heart.fill | #FF3B30 |
| Bills & Utilities | bolt.fill | #FFCC00 |
| Education | book.fill | #5856D6 |
| Travel | airplane | #00C7BE |
| Subscriptions | repeat | #8E8E93 |
| Transfers | arrow.left.arrow.right | #636366 |
| ATM | banknote.fill | #48484A |
| Other | ellipsis.circle.fill | #AEAEB2 |

### Income (6)
| Name | SF Symbol | Color |
|------|-----------|-------|
| Salary | briefcase.fill | #34C759 |
| Freelance | laptopcomputer | #007AFF |
| Investments | chart.line.uptrend.xyaxis | #5856D6 |
| Gifts | gift.fill | #FF2D55 |
| Refunds | arrow.uturn.backward | #FF9500 |
| Other Income | plus.circle.fill | #00C7BE |

---

## Implementation Order

1. **Create AGENTS.md** - Document all requirements for AI assistants
2. **Create project.yml** - XcodeGen configuration file
3. **Create folder structure** - Organize source files into folders
4. **SwiftData models** - All 12 models (including SubCategory) with relationships
5. **Configure CloudKit** - Add container to entitlements
6. **Utilities** - ISO4217, Formatters, Extensions
7. **API Clients** - Monobank, CoinMarketCap, Yahoo Finance
8. **Analytics** - PostHog integration (AnalyticsService)
9. **Services** - Sync, Rules, NetWorth, PriceFetch, DataSeeder
10. **Navigation** - Router, Tab enum (4 tabs)
11. **ViewModels** - All view models
12. **Views - Dashboard** - Overview, insights, recent transactions
13. **Views - Transactions** - List, detail with note editing, create, filters
14. **Views - Analytics** - Charts, category breakdown with refunds
15. **Views - Settings** - Monobank, wallets, investments, categories (with sub-categories), rules
16. **Views - Transfer** - Form with manual exchange rate option
17. **Views - Shared** - Wallets, Investments management
18. **App entry** - RensoApp.swift, ContentView.swift with 4-tab TabView
19. **Delete old files** - Tuist.swift, Item.swift

---

## Key Files to Modify/Create

| File | Action |
|------|--------|
| `AGENTS.md` | Create |
| `project.yml` | Create (XcodeGen config) |
| `Tuist.swift` | Delete |
| `Renso/Renso.entitlements` | Modify (add iCloud container) |
| `Renso/Item.swift` | Delete |
| `Renso/App/RensoApp.swift` | Create (move from root) |
| `Renso/App/ContentView.swift` | Create (4-tab TabView) |
| `Renso/Models/*.swift` | Create (12 model files) |
| `Renso/ViewModels/*.swift` | Create (9 viewmodel files) |
| `Renso/Services/API/*.swift` | Create (3 API clients) |
| `Renso/Services/Analytics/AnalyticsService.swift` | Create (PostHog) |
| `Renso/Services/*.swift` | Create (7 service files) |
| `Renso/Views/**/*.swift` | Create (all view files) |
| `Renso/Navigation/NavigationRouter.swift` | Create |
| `Renso/Utilities/*.swift` | Create |

---

## Architecture Decisions

1. **Decimal for money** - Avoid floating-point precision issues
2. **@Observable ViewModels** - iOS 17+ fine-grained observation
3. **Protocol-based services** - Enable testing and flexibility
4. **Rules priority system** - MCC (10) < Description (20) < User rules (30+)
5. **CloudKit-compatible models** - No unique constraints, optional relationships
6. **Single target with folders** - Simple start, modularize later when needed
7. **Transaction-based investment tracking** - Record each buy/sell, auto-calculate weighted average
8. **API price fetching** - CoinMarketCap for crypto, Yahoo Finance for stocks
9. **Refund linking** - Income refunds linked to expense categories, deducted from totals
10. **Sub-categories** - Hierarchical category structure
11. **XcodeGen** - project.yml for project generation instead of Tuist
12. **PostHog analytics** - Event tracking, screen views, feature flags
