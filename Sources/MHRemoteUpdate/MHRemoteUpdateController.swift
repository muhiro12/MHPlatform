import Foundation

/// Retains scheduled policy and checks app-selected operations without owning UI or endpoints.
///
/// Create one controller per app/environment/storefront and storage file. Refresh
/// errors are observable and never erase retained evidence. Re-evaluate at each
/// operation and foreground transition; this actor does not run a background timer.
public actor MHRemoteUpdateController {
    /// Invalid configuration, obsolete responses, and incompatible retained evidence.
    public enum Failure: Error, Equatable, Sendable {
        /// App identity, storefront, or evidence lifetime is invalid.
        case invalidConfiguration
        /// A fetched document is not currently valid or exceeds the app's maximum lifetime.
        case invalidSchedule
        /// A response belongs to an earlier refresh invocation.
        case superseded
        /// A revision moved backwards or an immutable revision changed content.
        case revisionConflict
        /// Retained evidence belongs to another app or storefront.
        case identityMismatch
    }

    /// Startup/foreground evidence and diagnostics without app-owned recovery sequencing.
    public struct Preparation: Sendable {
        /// Re-evaluated evidence after restoration and the refresh attempt.
        public let decision: MHRemoteUpdateDecision
        /// A corrupt, incompatible, or unreadable cache; refresh is still attempted.
        public let restorationError: (any Error)?
        /// A fetch or save failure; still-valid retained evidence remains usable.
        public let refreshError: (any Error)?
    }

    private enum Format {
        static let countryLength = 2
        static let uppercaseASCII: ClosedRange<UInt8> = 65...90
        static let lowercaseASCII: ClosedRange<UInt8> = 97...122
    }

    private let bundleIdentifier: String
    private let storefront: String
    private let maximumValidity: TimeInterval
    private let publicationLifetime: TimeInterval
    private let store: MHRemoteUpdateStore?
    private let currentVersion: @Sendable () -> String?
    private let now: @Sendable () -> Date
    private let fetchSchedule: @Sendable () async throws -> MHRemoteUpdateSchedule
    private let publicVersion: @Sendable () async throws -> MHAppVersion?
    private var snapshot: MHRemoteUpdateSnapshot?
    private var refreshIdentifier: UUID?
    private var hasAttemptedRestoration = false

    /// Creates a controller with explicit app-owned identity, lifetimes, storage, and providers.
    ///
    /// The public-version provider must validate app ID, bundle ID, and this storefront,
    /// for example with `MHAppStoreVersionLookup`. Pass nil storage only for ephemeral use.
    @preconcurrency
    public init(
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
        guard bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier,
              storefront.utf8.count == Format.countryLength,
              storefront.utf8.allSatisfy({ byte in
                Format.uppercaseASCII.contains(byte) || Format.lowercaseASCII.contains(byte)
              }),
              maximumValidity.isFinite, maximumValidity > 0,
              publicationLifetime.isFinite, publicationLifetime > 0 else {
            throw Failure.invalidConfiguration
        }
        self.bundleIdentifier = bundleIdentifier
        self.storefront = storefront.lowercased()
        self.maximumValidity = maximumValidity
        self.publicationLifetime = publicationLifetime
        self.store = store
        self.currentVersion = currentVersion
        self.now = now
        self.fetchSchedule = fetchSchedule
        self.publicVersion = publicVersion
    }

    /// Restores without network access; expired evidence remains unavailable on evaluation.
    ///
    /// Corrupt or mismatched files throw without clearing in-memory evidence. Restore
    /// before initial refresh; revision checks also prevent a late restore rolling it back.
    public func restore() throws {
        try Task.checkCancellation()
        hasAttemptedRestoration = true
        guard let restored = try store?.load() else {
            return
        }
        guard restored.schedule.bundleIdentifier == bundleIdentifier, restored.storefront == storefront else {
            throw Failure.identityMismatch
        }
        try validateRevision(restored.schedule)
        guard snapshot == nil || restored.schedule.revision > (snapshot?.schedule.revision ?? 0) else {
            return
        }
        refreshIdentifier = nil
        snapshot = restored
    }

    /// Restores once, then refreshes; use at startup and each foreground transition.
    ///
    /// Cache errors do not prevent a network refresh or low-impact offline use.
    /// Ordinary failures remain observable in the result; cancellation throws and
    /// never becomes a preparation result. No background observer or timer is installed.
    @discardableResult
    public func prepare() async throws -> Preparation {
        try Task.checkCancellation()
        var restorationError: (any Error)?
        if hasAttemptedRestoration == false {
            do {
                try restore()
            } catch {
                try Task.checkCancellation()
                if error is CancellationError {
                    throw error
                }
                restorationError = error
            }
        }
        var refreshError: (any Error)?
        do {
            try await refresh()
        } catch {
            try Task.checkCancellation()
            if error is CancellationError {
                throw error
            }
            refreshError = error
        }
        try Task.checkCancellation()
        return .init(decision: decision(), restorationError: restorationError, refreshError: refreshError)
    }

    /// Uses confirmation with one refresh by default; opt low-impact operations into offline use.
    public func checkOperationAllowed(
        for policy: MHRemoteUpdateOperationPolicy = .requireConfirmation
    ) async throws {
        try await checkOperationAllowed(
            whenUnavailable: policy == .allowWhenUnavailable ? .allow : .block,
            refreshIfUnavailable: policy == .requireConfirmation
        )
    }

    /// Evaluates retained evidence against the current version and clock without networking.
    public func decision() -> MHRemoteUpdateDecision {
        guard let snapshot, let version = currentVersion().flatMap(MHAppVersion.init) else {
            return .unavailable
        }
        return snapshot.evaluate(
            currentVersion: version,
            now: now(),
            maximumValidity: maximumValidity,
            maximumPublicationAge: publicationLifetime
        )
    }

    /// Fetches and retains a schedule, then confirms publication when relevant, even before activation.
    ///
    /// A valid schedule is saved before publication lookup so offline failures cannot
    /// lose an announced plan. A save failure leaves new evidence in memory and throws.
    /// Concurrent refreshes use the latest invocation; obsolete completions cannot
    /// overwrite cancellation or postponement. Cancellation never becomes permission.
    @discardableResult
    public func refresh() async throws -> MHRemoteUpdateDecision {
        try Task.checkCancellation()
        let identifier = UUID()
        refreshIdentifier = identifier
        do {
            let schedule = try await fetchSchedule()
            try checkRefresh(identifier)
            guard schedule.bundleIdentifier == bundleIdentifier else {
                throw Failure.identityMismatch
            }
            guard schedule.isValid(at: now(), maximumValidity: maximumValidity) else {
                throw Failure.invalidSchedule
            }
            try validateRevision(schedule)
            try retain(.init(schedule: schedule, storefront: storefront, publication: snapshot?.publication))
            if let requirement = schedule.requirement,
               currentVersion().flatMap(MHAppVersion.init).map({ $0 < requirement.minimumVersion }) == true,
               requirement.endsAt.map({ now() <= $0 }) != false {
                let version = try await publicVersion()
                try checkRefresh(identifier)
                let checkedAt = now()
                let validUntil = checkedAt.addingTimeInterval(publicationLifetime)
                guard checkedAt.timeIntervalSinceReferenceDate.isFinite,
                      validUntil.timeIntervalSinceReferenceDate.isFinite else {
                    throw Failure.invalidConfiguration
                }
                // A failed lookup keeps valid prior evidence; a successful observation replaces it.
                let publication = version.map { version in
                    MHRemoteUpdateSnapshot.Publication(version: version, checkedAt: checkedAt, validUntil: validUntil)
                }
                try retain(.init(schedule: schedule, storefront: storefront, publication: publication))
            }
            return decision()
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    /// Checks immediately before an app-owned operation and its success effects.
    ///
    /// With refresh enabled, unavailable evidence triggers one refresh. Fetch, save,
    /// and cancellation errors propagate; a still-unavailable result follows the
    /// explicit allow/block choice. Known required updates always block. This is a
    /// snapshot check, not a transaction across a later suspended operation.
    public func checkOperationAllowed(
        whenUnavailable behavior: MHRemoteUpdateUnavailableBehavior,
        refreshIfUnavailable: Bool
    ) async throws {
        try Task.checkCancellation()
        if decision() == .unavailable, refreshIfUnavailable {
            try await refresh()
        }
        try Task.checkCancellation()
        try decision().checkOperationAllowed(whenUnavailable: behavior)
    }

    private func validateRevision(_ schedule: MHRemoteUpdateSchedule) throws {
        guard let existing = snapshot?.schedule else {
            return
        }
        guard schedule.revision >= existing.revision,
              schedule.revision != existing.revision || schedule == existing else {
            throw Failure.revisionConflict
        }
    }

    private func checkRefresh(_ identifier: UUID) throws {
        try Task.checkCancellation()
        guard refreshIdentifier == identifier else {
            throw Failure.superseded
        }
    }

    private func retain(_ value: MHRemoteUpdateSnapshot) throws {
        snapshot = value
        try store?.save(value)
    }
}
