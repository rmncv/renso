import Foundation

enum Formatters {
    // MARK: - Currency Formatters

    /// Format amount with currency symbol
    static func currency(
        _ amount: Decimal,
        currencyCode: String,
        showCents: Bool = true,
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale

        if !showCents {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = ISO4217.decimalPlaces(for: currencyCode)
        }

        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// Format amount with custom symbol
    static func amount(
        _ amount: Decimal,
        currencyCode: String,
        showSymbol: Bool = true,
        showCents: Bool = true
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = showCents ? ISO4217.decimalPlaces(for: currencyCode) : 0
        formatter.maximumFractionDigits = showCents ? ISO4217.decimalPlaces(for: currencyCode) : 0

        let formatted = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"

        if showSymbol {
            let symbol = ISO4217.symbol(for: currencyCode)
            return "\(formatted) \(symbol)"
        }

        return formatted
    }

    /// Format amount with sign (+ or -)
    static func signedAmount(
        _ amount: Decimal,
        currencyCode: String,
        showCents: Bool = true
    ) -> String {
        let sign = amount >= 0 ? "+" : ""
        let formatted = self.amount(abs(amount), currencyCode: currencyCode, showCents: showCents)
        return amount < 0 ? "-\(formatted)" : "\(sign)\(formatted)"
    }

    // MARK: - Number Formatters

    /// Format decimal number with specified decimal places
    static func decimal(_ value: Decimal, decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Format percentage
    static func percentage(_ value: Decimal, decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        formatter.multiplier = 1  // Value is already in percentage form
        return formatter.string(from: (value / 100) as NSDecimalNumber) ?? "\(value)%"
    }

    /// Format large numbers with abbreviations (K, M, B)
    static func abbreviated(_ value: Decimal) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        let number = NSDecimalNumber(decimal: absValue).doubleValue

        switch number {
        case 1_000_000_000...:
            return "\(sign)\(String(format: "%.1fB", number / 1_000_000_000))"
        case 1_000_000...:
            return "\(sign)\(String(format: "%.1fM", number / 1_000_000))"
        case 1_000...:
            return "\(sign)\(String(format: "%.1fK", number / 1_000))"
        default:
            return "\(sign)\(String(format: "%.0f", number))"
        }
    }

    // MARK: - Date Formatters

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Format date relative to now (e.g., "2 hours ago")
    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format date as short string (e.g., "12/31/24")
    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// Format date as medium string (e.g., "Dec 31, 2024")
    static func mediumDate(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    /// Format date with time (e.g., "Dec 31, 2024 at 3:30 PM")
    static func dateTime(_ date: Date) -> String {
        fullDateTimeFormatter.string(from: date)
    }

    /// Format time only (e.g., "3:30 PM")
    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// Format as month and year (e.g., "December 2024")
    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    /// Smart date formatting based on how recent
    static func smartDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today, \(time(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(time(date))"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        } else {
            return shortDate(date)
        }
    }

    // MARK: - Crypto/Stock Formatters

    /// Format crypto quantity (up to 8 decimal places)
    static func cryptoQuantity(_ quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8

        // Remove trailing zeros
        if let str = formatter.string(from: quantity as NSDecimalNumber) {
            return str
        }
        return "\(quantity)"
    }

    /// Format stock quantity (typically whole shares)
    static func stockQuantity(_ quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: quantity as NSDecimalNumber) ?? "\(quantity)"
    }
}
