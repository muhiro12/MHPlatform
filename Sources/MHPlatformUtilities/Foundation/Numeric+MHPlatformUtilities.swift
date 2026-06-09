import Foundation

public extension Numeric {
    /// A Boolean value indicating whether the numeric value equals zero.
    var isZero: Bool {
        self == .zero
    }

    /// A Boolean value indicating whether the numeric value is not zero.
    var isNotZero: Bool {
        !isZero
    }
}

nonisolated public extension Decimal {
    /// A Boolean value indicating whether the number is greater than zero.
    var isPlus: Bool {
        self > .zero
    }

    /// A Boolean value indicating whether the number is less than zero.
    var isMinus: Bool {
        self < .zero
    }
}
