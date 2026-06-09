import Foundation

public extension Collection where Self: RangeReplaceableCollection {
    /// An empty instance of the conforming collection.
    static var empty: Self {
        .init()
    }

    /// A Boolean value indicating whether the collection contains at least one element.
    var isNotEmpty: Bool {
        !isEmpty
    }
}

public extension Optional where Wrapped: RangeReplaceableCollection {
    /// Returns the wrapped collection or an empty instance when the value is `nil`.
    var orEmpty: Wrapped {
        self ?? .init()
    }

    /// A Boolean value indicating whether the optional collection is non-empty.
    ///
    /// When the value is `nil`, this returns `false`.
    var isNotEmpty: Bool {
        orEmpty.isNotEmpty
    }
}
