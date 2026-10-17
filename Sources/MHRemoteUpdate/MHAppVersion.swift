/// A numeric app version with one to three ASCII integer components.
///
/// Missing components are zero: `1`, `1.0`, and `1.0.0` are equal.
/// Components must fit in `Int`; whitespace, signs, and suffixes are invalid.
public struct MHAppVersion: Comparable, Hashable, Sendable {
    private enum Format {
        static let componentCount = 1...3
        static let normalizedCount = 3
        static let asciiDigits: ClosedRange<UInt8> = 48...57
    }

    private let components: [Int]

    /// Returns `nil` for malformed or overflowing versions.
    public init?(_ value: String) {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard Format.componentCount.contains(parts.count) else {
            return nil
        }
        var parsedComponents: [Int] = []
        for part in parts {
            guard part.isEmpty == false,
                  part.utf8.allSatisfy({ Format.asciiDigits.contains($0) }),
                  let component = Int(part) else {
                return nil
            }
            parsedComponents.append(component)
        }
        components = parsedComponents + Array(repeating: 0, count: Format.normalizedCount - parsedComponents.count)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}
