import Foundation

/// A typed `UserDefaults` adapter for primitive and `Codable` preferences.
public struct MHPreferenceStore: @unchecked Sendable {
    private let userDefaults: UserDefaults?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates an unbound preference store that resolves defaults from each descriptor.
    public init(
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.userDefaults = nil
        self.encoder = encoder
        self.decoder = decoder
    }

    /// Creates a preference store backed by the provided `UserDefaults`.
    public init(
        userDefaults: UserDefaults,
        encoder: JSONEncoder = .init(),
        decoder: JSONDecoder = .init()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    /// Returns a boolean preference value or the descriptor default when unset.
    public func bool(for descriptor: MHBoolPreferenceDescriptor) -> Bool {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        guard userDefaults.object(forKey: descriptor.storageKey) != nil else {
            return descriptor.defaultValue
        }
        return userDefaults.bool(forKey: descriptor.storageKey)
    }

    /// Stores a boolean preference value.
    public func set(_ value: Bool, for descriptor: MHBoolPreferenceDescriptor) {
        resolvedUserDefaults(for: descriptor).set(
            value,
            forKey: descriptor.storageKey
        )
    }

    /// Returns an integer preference value or the descriptor default when unset.
    public func int(for descriptor: MHIntPreferenceDescriptor) -> Int {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        guard userDefaults.object(forKey: descriptor.storageKey) != nil else {
            return descriptor.defaultValue
        }
        return userDefaults.integer(forKey: descriptor.storageKey)
    }

    /// Stores an integer preference value.
    public func set(_ value: Int, for descriptor: MHIntPreferenceDescriptor) {
        resolvedUserDefaults(for: descriptor).set(
            value,
            forKey: descriptor.storageKey
        )
    }

    /// Returns an optional string preference value.
    public func string(for descriptor: MHStringPreferenceDescriptor) -> String? {
        resolvedUserDefaults(for: descriptor).string(
            forKey: descriptor.storageKey
        )
    }

    /// Stores or removes an optional string preference value.
    public func set(
        _ value: String?,
        for descriptor: MHStringPreferenceDescriptor
    ) {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        if let value {
            userDefaults.set(value, forKey: descriptor.storageKey)
        } else {
            userDefaults.removeObject(forKey: descriptor.storageKey)
        }
    }

    /// Returns an optional date preference value.
    public func date(for descriptor: MHDatePreferenceDescriptor) -> Date? {
        resolvedUserDefaults(for: descriptor).object(
            forKey: descriptor.storageKey
        ) as? Date
    }

    /// Stores or removes an optional date preference value.
    public func set(
        _ value: Date?,
        for descriptor: MHDatePreferenceDescriptor
    ) {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        if let value {
            userDefaults.set(value, forKey: descriptor.storageKey)
        } else {
            userDefaults.removeObject(forKey: descriptor.storageKey)
        }
    }

    /// Decodes a `Codable` preference value stored as `Data`.
    public func codable<Value: Codable & Sendable>(
        for descriptor: MHCodablePreferenceDescriptor<Value>
    ) -> Value? {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        guard let object = userDefaults.object(
            forKey: descriptor.storageKey
        ) else {
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
        for descriptor: MHCodablePreferenceDescriptor<Value>
    ) {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        guard let value else {
            userDefaults.removeObject(forKey: descriptor.storageKey)
            return
        }

        guard let encodedData = try? encoder.encode(value) else {
            return
        }

        userDefaults.set(encodedData, forKey: descriptor.storageKey)
    }

    /// Returns a boolean preference value from a key namespace.
    public func bool(
        for keyPath: KeyPath<MHPreferenceKeys, MHBoolPreferenceDescriptor>
    ) -> Bool {
        bool(for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Stores a boolean preference value into a key namespace.
    public func set(
        _ value: Bool,
        for keyPath: KeyPath<MHPreferenceKeys, MHBoolPreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Returns an integer preference value from a key namespace.
    public func int(
        for keyPath: KeyPath<MHPreferenceKeys, MHIntPreferenceDescriptor>
    ) -> Int {
        int(for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Stores an integer preference value into a key namespace.
    public func set(
        _ value: Int,
        for keyPath: KeyPath<MHPreferenceKeys, MHIntPreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Returns an optional string preference value from a key namespace.
    public func string(
        for keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>
    ) -> String? {
        string(for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Stores or removes an optional string preference value into a key namespace.
    public func set(
        _ value: String?,
        for keyPath: KeyPath<MHPreferenceKeys, MHStringPreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Returns an optional date preference value from a key namespace.
    public func date(
        for keyPath: KeyPath<MHPreferenceKeys, MHDatePreferenceDescriptor>
    ) -> Date? {
        date(for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Stores or removes an optional date preference value into a key namespace.
    public func set(
        _ value: Date?,
        for keyPath: KeyPath<MHPreferenceKeys, MHDatePreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Decodes a `Codable` preference value from a key namespace.
    public func codable<Value: Codable & Sendable>(
        for keyPath: KeyPath<MHPreferenceKeys, MHCodablePreferenceDescriptor<Value>>
    ) -> Value? {
        codable(for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Encodes and stores a `Codable` preference value into a key namespace.
    public func setCodable<Value: Codable & Sendable>(
        _ value: Value?,
        for keyPath: KeyPath<MHPreferenceKeys, MHCodablePreferenceDescriptor<Value>>
    ) {
        setCodable(value, for: MHPreferenceKeys()[keyPath: keyPath])
    }

    /// Returns whether the supplied storage descriptor currently has a stored value.
    public func contains<Descriptor: MHStorageDescriptorProtocol>(
        _ descriptor: Descriptor
    ) -> Bool {
        resolvedUserDefaults(for: descriptor).object(
            forKey: descriptor.storageKey
        ) != nil
    }

    /// Removes a value for the supplied storage descriptor.
    public func remove<Descriptor: MHStorageDescriptorProtocol>(
        _ descriptor: Descriptor
    ) {
        resolvedUserDefaults(for: descriptor).removeObject(
            forKey: descriptor.storageKey
        )
    }
}

private extension MHPreferenceStore {
    func resolvedUserDefaults<Descriptor: MHStorageDescriptorProtocol>(
        for descriptor: Descriptor
    ) -> UserDefaults {
        userDefaults ?? descriptor.defaultSelection.resolveUserDefaults()
    }
}
