import Foundation

public extension MHRemoteUpdateController {
    /// Creates a bounded-v1 controller with explicit identity, lifetimes, and providers.
    ///
    /// The public-version provider must validate app ID, bundle ID, and storefront.
    /// Restoring or re-fetching a bounded document never extends its authored expiry.
    @preconcurrency
    init(
        bundleIdentifier: String,
        storefront: String,
        maximumValidity: TimeInterval,
        publicationLifetime: TimeInterval,
        store: MHRemoteUpdateStore?,
        currentVersion: @escaping @Sendable () -> String?,
        now: @escaping @Sendable () -> Date = Date.init,
        fetchSchedule: @escaping @Sendable () async throws -> MHRemoteUpdateSchedule,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion?
    ) throws {
        try self.init(
            bundleIdentifier: bundleIdentifier,
            storefront: storefront,
            maximumValidity: maximumValidity,
            policyLifetime: Defaults.policyLifetime,
            publicationLifetime: publicationLifetime,
            store: store,
            currentVersion: currentVersion,
            now: now,
            fetchDocument: { .bounded(try await fetchSchedule()) },
            publicVersion: publicVersion
        )
    }

    /// Creates a static-v2 controller with bounded retained evidence and injected providers.
    ///
    /// The policy provider must perform a validated fetch, bypassing the local HTTP cache.
    /// Only accepted responses renew policy evidence. Publication has a separate lifetime.
    @preconcurrency
    init(
        bundleIdentifier: String,
        storefront: String,
        policyLifetime: TimeInterval,
        publicationLifetime: TimeInterval,
        store: MHRemoteUpdateStore?,
        currentVersion: @escaping @Sendable () -> String?,
        now: @escaping @Sendable () -> Date = Date.init,
        fetchPolicy: @escaping @Sendable () async throws -> MHRemoteUpdateStaticPolicy,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion?
    ) throws {
        try self.init(
            bundleIdentifier: bundleIdentifier,
            storefront: storefront,
            maximumValidity: Defaults.maximumValidity,
            policyLifetime: policyLifetime,
            publicationLifetime: publicationLifetime,
            store: store,
            currentVersion: currentVersion,
            now: now,
            fetchDocument: { .static(try await fetchPolicy()) },
            publicVersion: publicVersion
        )
    }
}
