import Foundation

nonisolated public extension Date {
    /// Formats the date using a locale-aware formatter derived from the given template.
    /// - Parameters:
    ///   - template: The date format template to use.
    ///   - locale: The locale for formatting. Defaults to `.current`.
    /// - Returns: A formatted string.
    func stringValue(
        _ template: DateFormatter.Template,
        locale: Locale = .current
    ) -> String {
        DateFormatter.default(template, locale: locale).string(from: self)
    }

    /// Formats the date using a fixed, locale-independent formatter.
    /// - Parameter template: The fixed format template to use.
    /// - Returns: A formatted string using the POSIX locale.
    func stringValueWithoutLocale(_ template: DateFormatter.Template) -> String {
        DateFormatter.fixed(template).string(from: self)
    }
}
