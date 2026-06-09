import Foundation

nonisolated public extension DateFormatter {
    /// A small set of date format templates used across MHPlatform adopters.
    enum Template: String, Sendable {
        case yyyy
        case yyyyMM
        case yyyyMMM
        case MMMd
        case yyyyMMdd
        case yyyyMMMd
    }

    /// Returns a date formatter configured with the given template and locale.
    ///
    /// A new instance is created for every call to avoid shared mutable state
    /// across threads.
    /// - Parameters:
    ///   - template: A template used to derive a locale-appropriate date format.
    ///   - locale: The locale to use when formatting.
    /// - Returns: A new `DateFormatter` instance configured for the inputs.
    static func `default`(
        _ template: Template,
        locale: Locale
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat(
            fromTemplate: template.rawValue,
            options: .zero,
            locale: locale
        )
        formatter.locale = locale
        return formatter
    }

    /// Returns a date formatter configured with a fixed, locale-independent format.
    ///
    /// Locale and time zone are pinned to stable values for deterministic
    /// formatting and parsing.
    /// - Parameter template: A template used directly as the `dateFormat`.
    /// - Returns: A new `DateFormatter` instance using the POSIX locale.
    static func fixed(_ template: Template) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = template.rawValue
        formatter.locale = .init(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        return formatter
    }
}
