import Foundation

nonisolated public extension String {
    /// A Boolean value indicating whether the string is empty or can be parsed as a `Decimal`.
    var isEmptyOrDecimal: Bool {
        if isEmpty {
            return true
        }
        return Decimal(string: self) != nil
    }

    /// Parses the string as a `Decimal`, or returns `.zero` on failure.
    var decimalValue: Decimal {
        guard let value = Decimal(string: self) else {
            return .zero
        }
        return value
    }

    /// Parses the string to a `Date` using a fixed date format template.
    /// - Parameter template: A date format template defined by ``DateFormatter/Template``.
    /// - Returns: A `Date` when parsing succeeds; otherwise `nil`.
    func dateValueWithoutLocale(_ template: DateFormatter.Template) -> Date? {
        DateFormatter.fixed(template).date(from: self)
    }
}

public extension StringProtocol {
    /// Returns `true` when both strings match after width and kana normalization.
    ///
    /// The normalization converts full-width to half-width characters and
    /// Hiragana to Katakana before performing a localized, case-insensitive
    /// contains check.
    /// - Parameter other: A substring to search for.
    func normalizedContains<Other>(
        _ other: Other
    ) -> Bool where Other: StringProtocol {
        let normalizedSelf = self
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .applyingTransform(.hiraganaToKatakana, reverse: false) ?? .empty

        let normalizedOther = other
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .applyingTransform(.hiraganaToKatakana, reverse: false) ?? .empty

        return normalizedSelf.localizedStandardContains(normalizedOther)
    }
}
