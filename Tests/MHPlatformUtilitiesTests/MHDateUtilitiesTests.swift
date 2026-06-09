import Foundation
import MHPlatformUtilities
import Testing

struct MHDateUtilitiesTests {
    private var utcCalendar: Calendar {
        .utc
    }

    @Test
    func calendarBoundaries() throws {
        let calendar = utcCalendar
        let date = try #require(
            calendar.date(
                from: .init(
                    year: 2_024,
                    month: 2,
                    day: 29,
                    hour: 15,
                    minute: 30,
                    second: 45
                )
            )
        )

        let endOfDay = calendar.endOfDay(for: date)
        let dayComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endOfDay
        )
        #expect(dayComponents.year == 2_024)
        #expect(dayComponents.month == 2)
        #expect(dayComponents.day == 29)
        #expect(dayComponents.hour == 23)
        #expect(dayComponents.minute == 59)
        #expect(dayComponents.second == 59)

        let startOfMonth = calendar.startOfMonth(for: date)
        let monthStartComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: startOfMonth
        )
        #expect(monthStartComponents.year == 2_024)
        #expect(monthStartComponents.month == 2)
        #expect(monthStartComponents.day == 1)
        #expect(monthStartComponents.hour == 0)
        #expect(monthStartComponents.minute == 0)
        #expect(monthStartComponents.second == 0)

        let endOfMonth = calendar.endOfMonth(for: date)
        let monthEndComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endOfMonth
        )
        #expect(monthEndComponents.year == 2_024)
        #expect(monthEndComponents.month == 2)
        #expect(monthEndComponents.day == 29)
        #expect(monthEndComponents.hour == 23)
        #expect(monthEndComponents.minute == 59)
        #expect(monthEndComponents.second == 59)
    }

    @Test
    func yearBoundaries() throws {
        let calendar = utcCalendar
        let date = try #require(
            calendar.date(
                from: .init(year: 2_024, month: 6, day: 15)
            )
        )

        let startOfYear = calendar.startOfYear(for: date)
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: startOfYear
        )
        #expect(startComponents.year == 2_024)
        #expect(startComponents.month == 1)
        #expect(startComponents.day == 1)
        #expect(startComponents.hour == 0)
        #expect(startComponents.minute == 0)
        #expect(startComponents.second == 0)

        let endOfYear = calendar.endOfYear(for: date)
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endOfYear
        )
        #expect(endComponents.year == 2_024)
        #expect(endComponents.month == 12)
        #expect(endComponents.day == 31)
        #expect(endComponents.hour == 23)
        #expect(endComponents.minute == 59)
        #expect(endComponents.second == 59)
    }

    @Test
    func shiftedDateCopiesComponentsAcrossCalendars() throws {
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = try #require(.init(secondsFromGMT: 9 * 3_600))
        let originalDate = try #require(
            tokyoCalendar.date(
                from: .init(
                    year: 2_024,
                    month: 1,
                    day: 2,
                    hour: 3,
                    minute: 4,
                    second: 5
                )
            )
        )

        let shiftedDate = utcCalendar.shiftedDate(
            componentsFrom: originalDate,
            in: tokyoCalendar
        )
        let components = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: shiftedDate
        )

        #expect(components.year == 2_024)
        #expect(components.month == 1)
        #expect(components.day == 2)
        #expect(components.hour == 3)
        #expect(components.minute == 4)
        #expect(components.second == 5)
    }

    @Test
    func dateFormatterFactoriesCreateIndependentInstances() {
        let firstFixedFormatter = DateFormatter.fixed(.yyyyMMdd)
        let secondFixedFormatter = DateFormatter.fixed(.yyyyMMdd)
        #expect(firstFixedFormatter !== secondFixedFormatter)

        let locale = Locale(identifier: "en_US")
        let firstDefaultFormatter = DateFormatter.default(.yyyyMMMd, locale: locale)
        let secondDefaultFormatter = DateFormatter.default(.yyyyMMMd, locale: locale)
        #expect(
            firstDefaultFormatter !== secondDefaultFormatter
        )
    }

    @Test
    func fixedFormatterUsesPOSIXLocaleAndUTCTimeZone() {
        let formatter = DateFormatter.fixed(.yyyyMMdd)

        #expect(formatter.locale.identifier == "en_US_POSIX")
        #expect(
            formatter.timeZone.secondsFromGMT(
                for: Date(timeIntervalSinceReferenceDate: 0)
            ) == 0
        )
    }

    @Test
    func dateStringBridging() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(.init(secondsFromGMT: 0))
        let date = try #require(
            calendar.date(from: .init(year: 2_023, month: 9, day: 26))
        )

        let locale = Locale(identifier: "en_US")
        #expect(date.stringValue(.yyyyMMMd, locale: locale) == "Sep 26, 2023")

        let fixedString = date.stringValueWithoutLocale(.yyyyMMdd)
        #expect(fixedString == "20230926")
        #expect(
            fixedString.dateValueWithoutLocale(.yyyyMMdd)?
                .stringValueWithoutLocale(.yyyyMMdd) == fixedString
        )
    }
}
