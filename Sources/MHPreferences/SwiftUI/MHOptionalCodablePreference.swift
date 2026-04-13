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
        let encoder = self.encoder
        let decoder = self.decoder
        let storedDataBinding = self.$storedData

        return .init(
            get: {
                guard let storedData = storedDataBinding.wrappedValue else {
                    return nil
                }
                return try? decoder.decode(Value.self, from: storedData)
            },
            set: { newValue in
                guard let newValue else {
                    storedDataBinding.wrappedValue = nil
                    return
                }
                guard let encodedData = try? encoder.encode(newValue) else {
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
#endif
