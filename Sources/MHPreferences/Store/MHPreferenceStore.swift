import Foundation

/// The canonical non-SwiftUI access path for `UserDefaults`-backed preferences.
public struct MHPreferenceStore: @unchecked Sendable {
    private let userDefaults: UserDefaults?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let codingLock = NSLock()

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
        let resolvedDefaults = resolvedUserDefaults(for: descriptor)

        guard resolvedDefaults.object(forKey: descriptor.storageKey) != nil else {
            return descriptor.defaultValue
        }
        return resolvedDefaults.bool(forKey: descriptor.storageKey)
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
        let resolvedDefaults = resolvedUserDefaults(for: descriptor)

        guard resolvedDefaults.object(forKey: descriptor.storageKey) != nil else {
            return descriptor.defaultValue
        }
        return resolvedDefaults.integer(forKey: descriptor.storageKey)
    }

    /// Returns an integer preference value or the supplied default when unset.
    public func int(
        for descriptor: MHIntPreferenceDescriptor,
        default defaultValue: Int
    ) -> Int {
        let resolvedDefaults = resolvedUserDefaults(for: descriptor)

        guard resolvedDefaults.object(forKey: descriptor.storageKey) != nil else {
            return defaultValue
        }
        return resolvedDefaults.integer(forKey: descriptor.storageKey)
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

    /// Returns a string preference value or the supplied default when unset.
    public func string(
        for descriptor: MHStringPreferenceDescriptor,
        default defaultValue: String
    ) -> String {
        string(for: descriptor) ?? defaultValue
    }

    /// Stores or removes an optional string preference value.
    public func set(
        _ value: String?,
        for descriptor: MHStringPreferenceDescriptor
    ) {
        let resolvedDefaults = resolvedUserDefaults(for: descriptor)

        if let value {
            resolvedDefaults.set(value, forKey: descriptor.storageKey)
        } else {
            resolvedDefaults.removeObject(forKey: descriptor.storageKey)
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
        let resolvedDefaults = resolvedUserDefaults(for: descriptor)

        if let value {
            resolvedDefaults.set(value, forKey: descriptor.storageKey)
        } else {
            resolvedDefaults.removeObject(forKey: descriptor.storageKey)
        }
    }

    /// Decodes a `Codable` preference value stored as `Data`.
    public func codable<Value: Codable & Sendable>(
        for descriptor: MHCodablePreferenceDescriptor<Value>
    ) -> Value? {
        switch codableResult(for: descriptor) {
        case let .success(value):
            return value
        case .failure:
            return nil
        }
    }

    /// Encodes and stores a `Codable` preference value as `Data`.
    public func setCodable<Value: Codable & Sendable>(
        _ value: Value?,
        for descriptor: MHCodablePreferenceDescriptor<Value>
    ) {
        _ = setCodableResult(value, for: descriptor)
    }

    /// Returns a boolean preference value from a descriptor namespace.
    public func bool(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHBoolPreferenceDescriptor>
    ) -> Bool {
        bool(for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Stores a boolean preference value into a descriptor namespace.
    public func set(
        _ value: Bool,
        for keyPath: KeyPath<MHPreferenceDescriptors, MHBoolPreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Returns an integer preference value from a descriptor namespace.
    public func int(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHIntPreferenceDescriptor>
    ) -> Int {
        int(for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Returns an integer preference value from a descriptor namespace, or the
    /// supplied default when unset.
    public func int(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHIntPreferenceDescriptor>,
        default defaultValue: Int
    ) -> Int {
        int(
            for: MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Stores an integer preference value into a descriptor namespace.
    public func set(
        _ value: Int,
        for keyPath: KeyPath<MHPreferenceDescriptors, MHIntPreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Returns an optional string preference value from a descriptor namespace.
    public func string(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>
    ) -> String? {
        string(for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Returns a string preference value from a descriptor namespace, or the
    /// supplied default when unset.
    public func string(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>,
        default defaultValue: String
    ) -> String {
        string(
            for: MHPreferenceDescriptors()[keyPath: keyPath],
            default: defaultValue
        )
    }

    /// Stores or removes an optional string preference value into a descriptor namespace.
    public func set(
        _ value: String?,
        for keyPath: KeyPath<MHPreferenceDescriptors, MHStringPreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Returns an optional date preference value from a descriptor namespace.
    public func date(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHDatePreferenceDescriptor>
    ) -> Date? {
        date(for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Stores or removes an optional date preference value into a descriptor namespace.
    public func set(
        _ value: Date?,
        for keyPath: KeyPath<MHPreferenceDescriptors, MHDatePreferenceDescriptor>
    ) {
        set(value, for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Decodes a `Codable` preference value from a descriptor namespace.
    public func codable<Value: Codable & Sendable>(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHCodablePreferenceDescriptor<Value>>
    ) -> Value? {
        codable(for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Encodes and stores a `Codable` preference value into a descriptor namespace.
    public func setCodable<Value: Codable & Sendable>(
        _ value: Value?,
        for keyPath: KeyPath<MHPreferenceDescriptors, MHCodablePreferenceDescriptor<Value>>
    ) {
        setCodable(value, for: MHPreferenceDescriptors()[keyPath: keyPath])
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

public extension MHPreferenceStore {
    /// Decodes a `Codable` preference value and preserves decode failures.
    func codableResult<Value: Codable & Sendable>(
        for descriptor: MHCodablePreferenceDescriptor<Value>
    ) -> Result<Value?, MHPreferenceStoreCodableError> {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        guard let object = userDefaults.object(
            forKey: descriptor.storageKey
        ) else {
            return .success(nil)
        }
        guard let data = object as? Data else {
            return .failure(
                .storedValueIsNotData(storageKey: descriptor.storageKey)
            )
        }

        return codingLock.withLock {
            do {
                return .success(try decoder.decode(Value.self, from: data))
            } catch {
                return .failure(
                    .decodingFailed(
                        storageKey: descriptor.storageKey,
                        description: error.localizedDescription
                    )
                )
            }
        }
    }

    /// Decodes a namespaced `Codable` preference and preserves decode failures.
    func codableResult<Value: Codable & Sendable>(
        for keyPath: KeyPath<MHPreferenceDescriptors, MHCodablePreferenceDescriptor<Value>>
    ) -> Result<Value?, MHPreferenceStoreCodableError> {
        codableResult(for: MHPreferenceDescriptors()[keyPath: keyPath])
    }

    /// Encodes and stores a `Codable` preference value and preserves failures.
    @discardableResult
    func setCodableResult<Value: Codable & Sendable>(
        _ value: Value?,
        for descriptor: MHCodablePreferenceDescriptor<Value>
    ) -> Result<Void, MHPreferenceStoreCodableError> {
        let userDefaults = resolvedUserDefaults(for: descriptor)

        guard let value else {
            userDefaults.removeObject(forKey: descriptor.storageKey)
            return .success(())
        }

        return codingLock.withLock {
            do {
                let encodedData = try encoder.encode(value)
                userDefaults.set(encodedData, forKey: descriptor.storageKey)
                return .success(())
            } catch {
                return .failure(
                    .encodingFailed(
                        storageKey: descriptor.storageKey,
                        description: error.localizedDescription
                    )
                )
            }
        }
    }

    /// Encodes and stores a namespaced `Codable` preference and preserves failures.
    @discardableResult
    func setCodableResult<Value: Codable & Sendable>(
        _ value: Value?,
        for keyPath: KeyPath<MHPreferenceDescriptors, MHCodablePreferenceDescriptor<Value>>
    ) -> Result<Void, MHPreferenceStoreCodableError> {
        setCodableResult(value, for: MHPreferenceDescriptors()[keyPath: keyPath])
    }
}

private extension MHPreferenceStore {
    func resolvedUserDefaults<Descriptor: MHStorageDescriptorProtocol>(
        for descriptor: Descriptor
    ) -> UserDefaults {
        userDefaults ?? descriptor.defaultSelection.resolveUserDefaults()
    }
}

private extension NSLock {
    func withLock<Value>(
        _ body: () -> Value
    ) -> Value {
        lock()
        defer {
            unlock()
        }

        return body()
    }
}
