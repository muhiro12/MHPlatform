import Foundation

/// One independently decoded feature, preserving missing and invalid data as failures.
///
/// Use this type for each field in a multi-feature payload. A section failure
/// does not discard sibling sections. Invalid JSON, envelope failures, and
/// cancellation still fail the complete request.
public enum MHRemoteConfigSection<Value: Decodable & Sendable>: Decodable, Sendable {
    /// The feature decoded successfully; its processor still owns policy validation.
    case value(Value)
    /// No value was supplied for this feature key.
    case missing
    /// The feature was present but could not be decoded or validated.
    case invalid(any Error)

    /// Decodes one feature without converting invalid content into an absent value.
    public init(from decoder: any Decoder) throws {
        try Task.checkCancellation()
        do {
            let value = try Value(from: decoder)
            try Task.checkCancellation()
            self = .value(value)
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            self = .invalid(error)
        }
    }

    /// Returns validated content or throws the original feature failure.
    public func get() throws -> Value {
        switch self {
        case let .value(value):
            return value
        case .missing:
            throw MHRemoteConfigSectionError.missing
        case let .invalid(error):
            throw error
        }
    }
}

extension MHRemoteConfigSection: Encodable where Value: Encodable {
    /// Only successfully decoded or constructed values may be published.
    public func encode(to encoder: any Encoder) throws {
        try get().encode(to: encoder)
    }
}

public extension KeyedDecodingContainer {
    /// Preserves an absent feature without synthesized decoding failing all siblings.
    func decode<Value>(
        _ type: MHRemoteConfigSection<Value>.Type, forKey key: Key
    ) throws -> MHRemoteConfigSection<Value> {
        try Task.checkCancellation()
        guard contains(key) else {
            return .missing
        }
        return try type.init(from: superDecoder(forKey: key))
    }
}
