#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A SwiftUI bridge for optional codable preferences backed by `AppStorage`.
@propertyWrapper
public struct MHOptionalCodablePreference<Value: Codable & Sendable>: DynamicProperty {
    @AppStorage private var storedData: Data?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public var wrappedValue: Value? {
        get {
            guard let storedData else {
                return nil
            }
            return try? decoder.decode(Value.self, from: storedData)
        }
        nonmutating set {
            guard let newValue else {
                storedData = nil
                return
            }
            guard let encodedData = try? encoder.encode(newValue) else {
                return
            }
            storedData = encodedData
        }
    }

    public var projectedValue: Binding<Value?> {
        .init(
            get: {
                wrappedValue
            },
            set: { newValue in
                wrappedValue = newValue
            }
        )
    }

    /// Creates an optional codable preference bridge using a typed descriptor.
    public init(
        _ descriptor: MHCodablePreferenceDescriptor<Value>,
        store: UserDefaults? = nil,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.encoder = encoder
        self.decoder = decoder
        _storedData = AppStorage(
            descriptor.storageKey,
            store: store ?? descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates an optional codable preference bridge using the key namespace.
    public init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHCodablePreferenceDescriptor<Value>>,
        store: UserDefaults? = nil,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            store: store,
            encoder: encoder,
            decoder: decoder
        )
    }
}
#endif
