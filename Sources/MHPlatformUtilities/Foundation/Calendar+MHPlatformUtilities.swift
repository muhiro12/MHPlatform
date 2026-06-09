import Foundation

nonisolated public extension Calendar {
    /// A Gregorian calendar fixed to the UTC time zone.
    static var utc: Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(secondsFromGMT: .zero) ?? .current
        return calendar
    }

    /// Returns the last moment of the day that contains the given date.
    /// - Parameter date: A date in this calendar.
    /// - Returns: A date representing the end of the day.
    func endOfDay(for date: Date) -> Date {
        guard let nextDay = self.date(
            byAdding: .day,
            value: 1,
            to: date
        ) else {
            assertionFailure()
            return date
        }
        return startOfDay(for: nextDay) - 1
    }

    /// Returns the first moment of the month that contains the given date.
    /// - Parameter date: A date in this calendar.
    /// - Returns: A date representing the start of the month.
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        guard let start = self.date(from: components) else {
            assertionFailure()
            return date
        }
        return start
    }

    /// Returns the last moment of the month that contains the given date.
    /// - Parameter date: A date in this calendar.
    /// - Returns: A date representing the end of the month.
    func endOfMonth(for date: Date) -> Date {
        guard let nextMonth = self.date(
            byAdding: .month,
            value: 1,
            to: date
        ) else {
            assertionFailure()
            return date
        }
        return startOfMonth(for: nextMonth) - 1
    }

    /// Returns the first moment of the year that contains the given date.
    /// - Parameter date: A date in this calendar.
    /// - Returns: A date representing the start of the year.
    func startOfYear(for date: Date) -> Date {
        let components = dateComponents([.year], from: date)
        guard let start = self.date(from: components) else {
            assertionFailure()
            return date
        }
        return start
    }

    /// Returns the last moment of the year that contains the given date.
    /// - Parameter date: A date in this calendar.
    /// - Returns: A date representing the end of the year.
    func endOfYear(for date: Date) -> Date {
        guard let nextYear = self.date(
            byAdding: .year,
            value: 1,
            to: date
        ) else {
            assertionFailure()
            return date
        }
        return startOfYear(for: nextYear) - 1
    }

    /// Creates a date in this calendar by copying components from another calendar.
    /// - Parameters:
    ///   - date: The source date whose components will be copied.
    ///   - calendar: The calendar from which to read components.
    /// - Returns: A new date in this calendar built from the copied components.
    func shiftedDate(
        componentsFrom date: Date,
        in calendar: Calendar
    ) -> Date {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        guard let shiftedDate = self.date(from: components) else {
            assertionFailure(
                "Failed to shift date components from \(calendar) to \(self) for date: \(date)"
            )
            return date
        }
        return shiftedDate
    }
}
