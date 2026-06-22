#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A SwiftUI wrapper that uses `AppStorage` to bridge an optional `UserDefaults`-backed codable preference.
@propertyWrapper
public struct MHOptionalCodablePreference<Value: Codable & Sendable>: DynamicProperty {
    @AppStorage private var storedData: Data?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public var wrappedValue: Value? {
        get {
            Self.decode(
                storedData,
                decoder: decoder
            )
        }
        nonmutating set {
            guard let newValue else {
                storedData = nil
                return
            }
            guard let encodedData = Self.encode(
                newValue,
                encoder: encoder
            ) else {
                return
            }
            storedData = encodedData
        }
    }

    public var projectedValue: Binding<Value?> {
        let preferenceEncoder = self.encoder
        let preferenceDecoder = self.decoder
        let storedDataBinding = self.$storedData

        return .init(
            get: {
                Self.decode(
                    storedDataBinding.wrappedValue,
                    decoder: preferenceDecoder
                )
            },
            set: { newValue in
                guard let newValue else {
                    storedDataBinding.wrappedValue = nil
                    return
                }
                guard let encodedData = Self.encode(
                    newValue,
                    encoder: preferenceEncoder
                ) else {
                    return
                }
                storedDataBinding.wrappedValue = encodedData
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

    /// Creates an optional codable preference bridge using the descriptor namespace.
    public init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHCodablePreferenceDescriptor<Value>>,
        store: UserDefaults? = nil,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            store: store,
            encoder: encoder,
            decoder: decoder
        )
    }
}

private extension MHOptionalCodablePreference {
    static func decode(
        _ storedData: Data?,
        decoder: JSONDecoder
    ) -> Value? {
        guard let storedData else {
            return nil
        }

        return try? decoder.decode(Value.self, from: storedData)
    }

    static func encode(
        _ value: Value,
        encoder: JSONEncoder
    ) -> Data? {
        try? encoder.encode(value)
    }
}
#endif
