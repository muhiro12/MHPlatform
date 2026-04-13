#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A SwiftUI bridge for required codable preferences backed by `AppStorage`.
@propertyWrapper
public struct MHCodablePreference<Value: Codable & Sendable>: DynamicProperty {
    @AppStorage private var storedData: Data?

    private let defaultValue: Value
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public var wrappedValue: Value {
        get {
            guard let storedData else {
                return defaultValue
            }
            return (try? decoder.decode(Value.self, from: storedData)) ?? defaultValue
        }
        nonmutating set {
            guard let encodedData = try? encoder.encode(newValue) else {
                return
            }
            storedData = encodedData
        }
    }

    public var projectedValue: Binding<Value> {
        .init(
            get: {
                wrappedValue
            },
            set: { newValue in
                wrappedValue = newValue
            }
        )
    }

    /// Creates a codable preference bridge using a typed descriptor.
    public init(
        _ descriptor: MHCodablePreferenceDescriptor<Value>,
        default defaultValue: Value,
        store: UserDefaults? = nil,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.defaultValue = defaultValue
        self.encoder = encoder
        self.decoder = decoder
        _storedData = AppStorage(
            descriptor.storageKey,
            store: store ?? descriptor.defaultSelection.resolveUserDefaults()
        )
    }

    /// Creates a codable preference bridge using the key namespace.
    public init(
        _ keyPath: KeyPath<MHPreferenceKeys, MHCodablePreferenceDescriptor<Value>>,
        default defaultValue: Value,
        store: UserDefaults? = nil,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.init(
            MHPreferenceKeys()[keyPath: keyPath],
            default: defaultValue,
            store: store,
            encoder: encoder,
            decoder: decoder
        )
    }
}
#endif
