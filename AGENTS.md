# Renso - AI Agent Guidelines

This document provides comprehensive guidelines for AI assistants working on the Renso iOS finance tracker app.

## Project Overview

**Renso** is an iOS finance tracking application that helps users manage their finances across multiple currencies, track investments (crypto and stocks), and automatically categorize transactions from Monobank.

### Key Features
1. **Monobank Integration** - Auto-sync accounts and transactions via Monobank API
2. **Multi-Currency Wallets** - Create wallets with different currencies and initial balances
3. **Transfers** - Transfer money between wallets with manual exchange rate option
4. **Net Worth Tracking** - Calculate total across wallets, crypto, and stocks
5. **Crypto Portfolio** - Track holdings with live prices from CoinMarketCap API
6. **Stock Portfolio** - Track holdings with live prices from Yahoo Finance API
7. **Auto-Categorization Rules** - User-creatable rules based on MCC, description, or amount
8. **Sub-Categories** - Hierarchical category structure for detailed tracking
9. **Refund Linking** - Link income refunds to expense categories to reduce displayed totals
10. **Analytics** - Spending charts, trends, and category breakdowns

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with @Observable (iOS 17+)
- **Data Persistence**: SwiftData with CloudKit sync
- **Project Generation**: XcodeGen (`project.yml`)
- **Analytics**: PostHog (`posthog-ios` via SPM)
- **Minimum iOS**: 17.0

## Project Structure

```
Renso/
├── project.yml              # XcodeGen configuration
├── AGENTS.md                # This file
├── plan.md                  # Implementation plan
├── Renso/
│   ├── App/                 # App entry point
│   ├── Models/              # SwiftData models (12 files)
│   ├── ViewModels/          # @Observable view models (9 files)
│   ├── Views/               # SwiftUI views by feature
│   │   ├── Dashboard/
│   │   ├── Transactions/
│   │   ├── Analytics/
│   │   ├── Settings/
│   │   ├── Wallets/
│   │   ├── Investments/
│   │   └── Components/
│   ├── Services/            # Business logic and API clients
│   │   ├── API/
│   │   └── Analytics/
│   ├── Utilities/           # Helpers, extensions, formatters
│   ├── Navigation/          # Navigation router
│   └── Resources/           # Assets, Info.plist
```

## Architecture Guidelines

### MVVM Pattern
- **Models**: SwiftData `@Model` classes in `Models/`
- **ViewModels**: `@Observable` classes in `ViewModels/`
- **Views**: SwiftUI views in `Views/`

### SwiftData Models
All models must be CloudKit-compatible:
- Use `UUID` as primary identifier
- All properties must have default values or be optional
- All relationships must be optional
- NO `@Attribute(.unique)` constraints

### ViewModels
Use the `@Observable` macro (iOS 17+):
```swift
@Observable
@MainActor
final class SomeViewModel {
    var items: [Item] = []
    var isLoading = false
    var errorMessage: String?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}
```

### Services
All services should:
- Implement a protocol for testability
- Be `@MainActor` when accessing SwiftData
- Handle errors gracefully

## Data Models (12 Total)

| Model | Purpose |
|-------|---------|
| `Wallet` | Bank accounts, cash wallets (supports Monobank sync) |
| `Transaction` | Income/expense transactions with refund linking |
| `Category` | Parent categories for transactions |
| `SubCategory` | Child categories under parents |
| `Rule` | Auto-categorization rules (MCC, description, amount) |
| `Transfer` | Money transfers between wallets |
| `CryptoHolding` | Cryptocurrency holdings |
| `CryptoTransaction` | Buy/sell/transfer for crypto |
| `StockHolding` | Stock holdings |
| `StockTransaction` | Buy/sell/dividend for stocks |
| `ExchangeRate` | Currency exchange rates |
| `UserSettings` | App settings (base currency, sync preferences) |

## API Integrations

### Monobank API
- Base URL: `https://api.monobank.ua`
- Auth: `X-Token` header
- Rate limit: 1 request per 60 seconds for personal endpoints
- Docs: https://api.monobank.ua/docs/index.html

### CoinMarketCap API
- Base URL: `https://pro-api.coinmarketcap.com`
- Auth: `X-CMC_PRO_API_KEY` header
- Free tier: 10,000 calls/month
- Docs: https://coinmarketcap.com/api/documentation/v1/

### Yahoo Finance API
- Use yfinance-style endpoints or unofficial API
- No auth required for basic quotes
- Rate limit: Be respectful, cache results

## Navigation Structure

**4 Tabs:**
1. **Dashboard** - Net worth, insights, recent transactions
2. **Transactions** - Full transaction list with filters
3. **Analytics** - Charts, spending breakdown, trends
4. **Settings** - Monobank setup, wallets, categories, rules

## Coding Conventions

### Swift Style
- Use Swift's native types (`Decimal` for money, not `Double`)
- Prefer `async/await` over completion handlers
- Use `@MainActor` for UI-related code
- Follow Swift API Design Guidelines

### SwiftUI Best Practices
- Extract reusable components to `Views/Components/`
- Use `@Environment(\.modelContext)` for data access in views
- Prefer `@Query` for simple data fetching in views
- Use ViewModels for complex business logic

### Error Handling
- Define domain-specific error types
- Show user-friendly error messages
- Log errors for debugging (use PostHog for analytics)

### Localization
- Use `String(localized:)` for all user-facing strings
- Default to English, support Ukrainian
- Currency formatting should use `Locale`

## Default Categories

### Expenses (13)
| Name | SF Symbol | Color | MCC Codes |
|------|-----------|-------|-----------|
| Groceries | cart.fill | #34C759 | 5411, 5422, 5441, 5451, 5462 |
| Restaurants | fork.knife | #FF9500 | 5812, 5813, 5814 |
| Transport | car.fill | #007AFF | 4111, 4121, 4131, 5541, 5542 |
| Entertainment | theatermasks.fill | #AF52DE | 7832, 7841, 7911, 7922, 7929 |
| Shopping | bag.fill | #FF2D55 | 5311, 5611, 5621, 5631, 5641 |
| Health | heart.fill | #FF3B30 | 5912, 8011, 8021, 8031, 8041 |
| Bills & Utilities | bolt.fill | #FFCC00 | 4814, 4816, 4899, 4900 |
| Education | book.fill | #5856D6 | 8211, 8220, 8241, 8244, 8249 |
| Travel | airplane | #00C7BE | 3000-3299, 4511, 4722, 7011 |
| Subscriptions | repeat | #8E8E93 | - |
| Transfers | arrow.left.arrow.right | #636366 | - |
| ATM | banknote.fill | #48484A | 6010, 6011 |
| Other | ellipsis.circle.fill | #AEAEB2 | - |

### Income (6)
| Name | SF Symbol | Color |
|------|-----------|-------|
| Salary | briefcase.fill | #34C759 |
| Freelance | laptopcomputer | #007AFF |
| Investments | chart.line.uptrend.xyaxis | #5856D6 |
| Gifts | gift.fill | #FF2D55 |
| Refunds | arrow.uturn.backward | #FF9500 |
| Other Income | plus.circle.fill | #00C7BE |

## Rules Engine Priority

| Priority | Rule Type | Description |
|----------|-----------|-------------|
| 10 | MCC | Match by Merchant Category Code |
| 20 | Description | Match by description pattern (contains) |
| 30+ | User-created | Custom rules created by user |

Higher priority rules are evaluated first and override lower priority matches.

## Key Business Logic

### Refund Deduction
When a transaction is marked as a refund with `refundForCategory` set:
- The refund amount is subtracted from the expense category total in analytics
- Example: Spent 1000 UAH on Transport, got 200 UAH refund → Analytics shows 800 UAH

### Weighted Average Price (Investments)
For crypto/stocks, calculate average price from transaction history:
```
newAvgPrice = (oldQuantity * oldAvgPrice + newQuantity * newPrice) / totalQuantity
```

### Net Worth Calculation
Sum of:
- All wallet balances (converted to base currency)
- Crypto holdings value (quantity × lastPrice, converted)
- Stock holdings value (quantity × lastPrice, converted)

## Testing Guidelines

- Write unit tests for services (especially RulesEngine, NetWorthService)
- Use SwiftData in-memory store for testing
- Mock API clients with protocols
- Test CloudKit sync edge cases

## Common Tasks

### Adding a New Model
1. Create model file in `Models/`
2. Add to schema in `ModelContainerSetup.swift`
3. Create ViewModel if needed
4. Update DataSeeder if default data required

### Adding a New API Endpoint
1. Add method to appropriate API client
2. Create/update DTOs if needed
3. Add to sync service if applicable
4. Handle rate limiting

### Adding a New View
1. Create view file in appropriate `Views/` subfolder
2. Create ViewModel if complex logic needed
3. Add navigation destination if navigable
4. Track screen view in PostHog

## Environment Variables / Secrets

Store in Keychain or environment:
- `MONOBANK_TOKEN` - User's Monobank API token
- `COINMARKETCAP_API_KEY` - CoinMarketCap API key
- `POSTHOG_API_KEY` - PostHog project API key

Never commit secrets to the repository.

## Helpful Commands

```bash
# Generate Xcode project
xcodegen generate

# Run tests
xcodebuild test -scheme Renso -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for release
xcodebuild archive -scheme Renso -archivePath ./build/Renso.xcarchive
```

## Resources

- [Monobank API Docs](https://api.monobank.ua/docs/index.html)
- [CoinMarketCap API Docs](https://coinmarketcap.com/api/documentation/v1/)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [PostHog iOS SDK](https://posthog.com/docs/libraries/ios)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
