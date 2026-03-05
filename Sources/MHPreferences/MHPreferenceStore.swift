import Foundation

/// A typed `UserDefaults` adapter for primitive and `Codable` preferences.
public struct MHPreferenceStore {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a preference store backed by the provided `UserDefaults`.
    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    /// Returns a boolean preference value or the key default when unset.
    public func bool(for key: MHBoolPreferenceKey) -> Bool {
        guard userDefaults.object(forKey: key.storageKey) != nil else {
            return key.defaultValue
        }
        return userDefaults.bool(forKey: key.storageKey)
    }

    /// Stores a boolean preference value.
    public func set(_ value: Bool, for key: MHBoolPreferenceKey) {
        userDefaults.set(value, forKey: key.storageKey)
    }

    /// Returns an integer preference value or the key default when unset.
    public func int(for key: MHIntPreferenceKey) -> Int {
        guard userDefaults.object(forKey: key.storageKey) != nil else {
            return key.defaultValue
        }
        return userDefaults.integer(forKey: key.storageKey)
    }

    /// Stores an integer preference value.
    public func set(_ value: Int, for key: MHIntPreferenceKey) {
        userDefaults.set(value, forKey: key.storageKey)
    }

    /// Returns an optional string preference value.
    public func string(for key: MHStringPreferenceKey) -> String? {
        userDefaults.string(forKey: key.storageKey)
    }

    /// Stores or removes an optional string preference value.
    public func set(_ value: String?, for key: MHStringPreferenceKey) {
        if let value {
            userDefaults.set(value, forKey: key.storageKey)
        } else {
            userDefaults.removeObject(forKey: key.storageKey)
        }
    }

    /// Decodes a `Codable` preference value stored as `Data`.
    public func codable<Value: Codable & Sendable>(
        for key: MHCodablePreferenceKey<Value>
    ) -> Value? {
        guard let object = userDefaults.object(forKey: key.storageKey) else {
            return nil
        }
        guard let data = object as? Data else {
            return nil
        }
        return try? decoder.decode(Value.self, from: data)
    }

    /// Encodes and stores a `Codable` preference value as `Data`.
    public func setCodable<Value: Codable & Sendable>(
        _ value: Value?,
        for key: MHCodablePreferenceKey<Value>
    ) {
        guard let value else {
            userDefaults.removeObject(forKey: key.storageKey)
            return
        }

        guard let encodedData = try? encoder.encode(value) else {
            return
        }

        userDefaults.set(encodedData, forKey: key.storageKey)
    }

    /// Removes a value for the supplied preference key.
    public func remove<Key: MHPreferenceKeyProtocol>(_ key: Key) {
        userDefaults.removeObject(forKey: key.storageKey)
    }
}
