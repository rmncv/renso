import Foundation

extension Date {
    /// Start of the day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Start of the month
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// End of the month
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }

    /// Start of the year
    var startOfYear: Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    /// Check if date is in the current month
    var isInCurrentMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Check if date is in the current year
    var isInCurrentYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }

    /// Days ago from now
    var daysAgo: Int {
        Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
    }

    /// Create date from Unix timestamp
    static func fromUnixTimestamp(_ timestamp: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// Unix timestamp
    var unixTimestamp: Int64 {
        Int64(timeIntervalSince1970)
    }

    /// Add days to date
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    /// Add months to date
    func addingMonths(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }

    /// Format using Formatters
    func formatted(style: DateFormattingStyle) -> String {
        switch style {
        case .short:
            return Formatters.shortDate(self)
        case .medium:
            return Formatters.mediumDate(self)
        case .full:
            return Formatters.dateTime(self)
        case .relative:
            return Formatters.relativeDate(self)
        case .smart:
            return Formatters.smartDate(self)
        case .monthYear:
            return Formatters.monthYear(self)
        case .time:
            return Formatters.time(self)
        }
    }
}

enum DateFormattingStyle {
    case short
    case medium
    case full
    case relative
    case smart
    case monthYear
    case time
}
