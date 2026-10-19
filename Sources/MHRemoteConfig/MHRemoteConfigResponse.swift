import Foundation

/// A fetched value and the original time its network response completed.
///
/// Preserve this timestamp when distributing one response to multiple features.
/// Decoding, restoring, or selecting a feature must not establish new freshness.
public struct MHRemoteConfigResponse<Value: Sendable>: Sendable {
    /// The decoded configuration or a feature selected from it.
    public let value: Value
    /// The original network observation, independent of feature evaluation time.
    public let fetchedAt: Date

    /// Records a provider's observation; consumers still validate their own freshness.
    public init(value: Value, fetchedAt: Date) {
        self.value = value
        self.fetchedAt = fetchedAt
    }

    /// Selects a feature without renewing the original network observation.
    public func map<Feature: Sendable>(
        _ transform: (Value) throws -> Feature
    ) rethrows -> MHRemoteConfigResponse<Feature> {
        try .init(value: transform(value), fetchedAt: fetchedAt)
    }
}
