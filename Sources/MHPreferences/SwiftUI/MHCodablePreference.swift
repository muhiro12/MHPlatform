#if canImport(SwiftUI)
import Foundation
import SwiftUI

/// A SwiftUI wrapper that uses `AppStorage` to bridge a `UserDefaults`-backed codable preference.
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
        let defaultValue = self.defaultValue
        let encoder = self.encoder
        let decoder = self.decoder
        let storedDataBinding = self.$storedData

        return .init(
            get: {
                guard let storedData = storedDataBinding.wrappedValue else {
                    return defaultValue
                }
                return (try? decoder.decode(Value.self, from: storedData)) ?? defaultValue
            },
            set: { newValue in
                guard let encodedData = try? encoder.encode(newValue) else {
                    return
                }
                storedDataBinding.wrappedValue = encodedData
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

    /// Creates a codable preference bridge using the descriptor namespace.
    public init(
        _ keyPath: KeyPath<MHPreferenceDescriptors, MHCodablePreferenceDescriptor<Value>>,
        default defaultValue: Value,
        store: UserDefaults? = nil,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.init(
            MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue,
            store: store,
            encoder: encoder,
            decoder: decoder
        )
    }
}
#endif
