import Foundation
import MHRemoteConfig

/// Retains scheduled policy and checks app-selected operations without owning UI or endpoints.
///
/// Create one controller per app/environment/storefront and storage file. Refresh
/// errors are observable and never erase retained evidence. Re-evaluate at each
/// operation and foreground transition; this actor does not run a background timer.
public actor MHRemoteUpdateController {
    private enum Format {
        static let countryLength = 2
        static let uppercaseASCII: ClosedRange<UInt8> = 65...90
        static let lowercaseASCII: ClosedRange<UInt8> = 97...122
    }

    private let bundleIdentifier: String
    private let storefront: String?
    private let policyLifetime: TimeInterval
    private let publicationLifetime: TimeInterval
    private let store: MHRemoteUpdateStore?
    private let currentVersion: @Sendable () -> String?
    private let now: @Sendable () -> Date
    private let fetchSchedule: @Sendable () async throws -> MHRemoteConfigResponse<MHRemoteUpdateSchedule>
    private let publicVersion: @Sendable () async throws -> MHAppVersion?
    private var evidence: MHRemoteUpdateSnapshot?
    private var refreshIdentifier: UUID?
    private var refreshTask: Task<Void, Never>?
    private(set) var refreshWaiters: [UUID: CheckedContinuation<MHRemoteUpdateDecision, any Error>] = [:]
    private var hasInitializedEvidence = false
    private var lastRestorationError: (any Error)?
    private var lastRefreshError: (any Error)?

    /// Creates a controller with explicit identity, evidence lifetimes, and validated providers.
    ///
    /// `fetchSchedule` supplies validated policy with its original network observation;
    /// shared responses and disk reads cannot establish new freshness. `publicVersion` must validate
    /// app ID, bundle ID, and storefront. Pass nil storage only for ephemeral use.
    @preconcurrency
    public init(
        bundleIdentifier: String,
        storefront: String?,
        policyLifetime: TimeInterval,
        publicationLifetime: TimeInterval,
        store: MHRemoteUpdateStore?,
        currentVersion: @escaping @Sendable () -> String?,
        now: @escaping @Sendable () -> Date = Date.init,
        fetchSchedule: @escaping @Sendable () async throws -> MHRemoteConfigResponse<MHRemoteUpdateSchedule>,
        publicVersion: @escaping @Sendable () async throws -> MHAppVersion?
    ) throws {
        guard bundleIdentifier.isEmpty == false,
              bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) == bundleIdentifier,
              policyLifetime.isFinite, policyLifetime > 0,
              publicationLifetime.isFinite, publicationLifetime > 0 else {
            throw Failure.invalidConfiguration
        }
        if let storefront {
            guard storefront.utf8.count == Format.countryLength,
                  storefront.utf8.allSatisfy({ byte in
                    Format.uppercaseASCII.contains(byte) || Format.lowercaseASCII.contains(byte)
                  }) else {
                throw Failure.invalidConfiguration
            }
        }
        self.bundleIdentifier = bundleIdentifier
        self.storefront = storefront?.lowercased()
        self.policyLifetime = policyLifetime
        self.publicationLifetime = publicationLifetime
        self.store = store
        self.currentVersion = currentVersion
        self.now = now
        self.fetchSchedule = fetchSchedule
        self.publicVersion = publicVersion
    }

    /// Restores without network access; expired evidence remains unavailable on evaluation.
    ///
    /// Corrupt or mismatched files throw without clearing in-memory evidence;
    /// revision checks prevent a late restore from rolling policy back.
    public func restore() throws {
        try Task.checkCancellation()
        do {
            try restoreEvidence()
            lastRestorationError = nil
        } catch {
            lastRestorationError = error
            throw error
        }
    }

    /// Restores until evidence initializes, then refreshes on each startup/foreground call.
    ///
    /// Each call merges shared evidence before refreshing. Cache errors do not prevent
    /// refresh or low-impact offline use. Ordinary failures remain observable;
    /// cancellation throws. No observer or timer is installed.
    @discardableResult
    public func prepare() async throws -> Preparation {
        try Task.checkCancellation()
        let restorationError = try initializeEvidence()
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
        return .init(evaluation: evaluation(), restorationError: restorationError, refreshError: refreshError)
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
        evaluation().decision
    }

    /// Reads one diagnostic instant without restoring, fetching, saving, or renewing evidence.
    ///
    /// Error metadata describes the most recent attempts; a valid retained decision
    /// can coexist with a failed refresh. Use operation checks before mutation.
    public func evaluation() -> MHRemoteUpdateEvaluation {
        .init(
            snapshot: evidence,
            installedVersion: currentVersion().flatMap(MHAppVersion.init),
            now: now(),
            maximumPolicyAge: policyLifetime,
            maximumPublicationAge: publicationLifetime,
            restorationError: lastRestorationError,
            refreshError: lastRefreshError
        )
    }

    /// Fetches and retains a schedule, then confirms publication when relevant, even before activation.
    ///
    /// A valid schedule is saved before publication lookup so offline failures cannot
    /// lose an announced plan. A save failure leaves new evidence in memory and throws.
    /// Overlapping callers share one request. Cancelling a caller releases only its
    /// wait; the last cancelled waiter cancels the request and invalidates late responses.
    /// Cancellation never becomes permission.
    @discardableResult
    public func refresh() async throws -> MHRemoteUpdateDecision {
        try Task.checkCancellation()
        let waiter = UUID()
        let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueueRefresh(waiter: waiter, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancelRefresh(waiter: waiter) }
        }
        try Task.checkCancellation()
        return result
    }

    /// Checks immediately before an app-owned operation and its success effects.
    ///
    /// First restores retained evidence if it has not initialized. Ordinary cache
    /// failures remain observable through `evaluation()` and do not prevent refresh.
    /// With refresh enabled, unavailable evidence triggers one refresh. Fetch, save,
    /// and cancellation errors propagate; a still-unavailable result follows the
    /// explicit allow/block choice. Known required updates always block. This is a
    /// snapshot check, not a transaction across a later suspended operation.
    public func checkOperationAllowed(
        whenUnavailable behavior: MHRemoteUpdateUnavailableBehavior,
        refreshIfUnavailable: Bool
    ) async throws {
        try Task.checkCancellation()
        _ = try initializeEvidence()
        if decision() == .unavailable, refreshIfUnavailable {
            try await refresh()
        }
        try Task.checkCancellation()
        try decision().checkOperationAllowed(whenUnavailable: behavior)
    }
}

private extension MHRemoteUpdateController {
    func enqueueRefresh(
        waiter: UUID,
        continuation: CheckedContinuation<MHRemoteUpdateDecision, any Error>
    ) {
        refreshWaiters[waiter] = continuation
        guard refreshIdentifier == nil else {
            return
        }
        let identifier = UUID()
        refreshIdentifier = identifier
        refreshTask = Task {
            let result: Result<MHRemoteUpdateDecision, any Error>
            do {
                result = .success(try await performRefresh(identifier))
            } catch {
                result = .failure(error)
            }
            completeRefresh(identifier, result: result)
        }
    }

    func cancelRefresh(waiter: UUID) {
        refreshWaiters.removeValue(forKey: waiter)?.resume(throwing: CancellationError())
        guard refreshWaiters.isEmpty else {
            return
        }
        refreshTask?.cancel()
        refreshTask = nil
        refreshIdentifier = nil
    }

    func completeRefresh(_ identifier: UUID, result: Result<MHRemoteUpdateDecision, any Error>) {
        guard refreshIdentifier == identifier else {
            return
        }
        refreshIdentifier = nil
        refreshTask = nil
        let waiters = refreshWaiters.values
        refreshWaiters.removeAll()
        switch result {
        case .success:
            lastRefreshError = nil
        case .failure(let error):
            if error is CancellationError == false {
                lastRefreshError = error
            }
        }
        for waiter in waiters {
            waiter.resume(with: result)
        }
    }

    func performRefresh(_ identifier: UUID) async throws -> MHRemoteUpdateDecision {
        do {
            let response = try await fetchSchedule()
            let document = response.value
            try checkRefresh(identifier)
            guard document.bundleIdentifier == bundleIdentifier else {
                throw Failure.identityMismatch
            }
            try validateRevision(document)
            var accepted = MHRemoteUpdateSnapshot(
                schedule: document,
                storefront: storefront,
                observation: try observation(fetchedAt: response.fetchedAt),
                publication: evidence?.publication
            )
            accepted.publicationCheckedAt = evidence?.publicationCheckedAt
            try retain(accepted)
            if let installedVersion = currentVersion().flatMap(MHAppVersion.init),
               document.needsPublication(currentVersion: installedVersion, at: now()) {
                let version = try await publicVersion()
                try checkRefresh(identifier)
                try retainPublication(version, schedule: document, observation: accepted.observation)
            }
            return decision()
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    func retainPublication(
        _ version: MHAppVersion?,
        schedule: MHRemoteUpdateSchedule,
        observation: MHRemoteUpdateSnapshot.Observation
    ) throws {
        let checkedAt = now()
        let validUntil = checkedAt.addingTimeInterval(publicationLifetime)
        guard checkedAt.timeIntervalSinceReferenceDate.isFinite,
              validUntil.timeIntervalSinceReferenceDate.isFinite else {
            throw Failure.invalidConfiguration
        }
        // An empty successful observation also replaces prior publication evidence.
        let publication = version.map { version in
            MHRemoteUpdateSnapshot.Publication(version: version, checkedAt: checkedAt, validUntil: validUntil)
        }
        var confirmed = MHRemoteUpdateSnapshot(
            schedule: schedule, storefront: storefront, observation: observation, publication: publication
        )
        confirmed.publicationCheckedAt = checkedAt
        try retain(confirmed)
    }

    func observation(fetchedAt: Date) throws -> MHRemoteUpdateSnapshot.Observation {
        let validUntil = fetchedAt.addingTimeInterval(policyLifetime)
        guard fetchedAt.timeIntervalSinceReferenceDate.isFinite,
              validUntil.timeIntervalSinceReferenceDate.isFinite,
              validUntil > fetchedAt else {
            throw Failure.invalidConfiguration
        }
        return .init(fetchedAt: fetchedAt, validUntil: validUntil)
    }

    func restoreEvidence() throws {
        guard let restored = try store?.load() else {
            hasInitializedEvidence = true
            return
        }
        guard restored.schedule.bundleIdentifier == bundleIdentifier, restored.storefront == storefront else {
            throw Failure.identityMismatch
        }
        try validateRevision(restored.schedule)
        hasInitializedEvidence = true
        evidence = try evidence?.merging(restored) ?? restored
    }

    func initializeEvidence() throws -> (any Error)? {
        try Task.checkCancellation()
        guard hasInitializedEvidence == false else {
            do {
                if let restored = try store?.load(), restored.schedule.revision >= (evidence?.schedule.revision ?? 0) {
                    evidence = try evidence?.merging(restored) ?? restored
                }
                lastRestorationError = nil
            } catch {
                lastRestorationError = error
                return error
            }
            return nil
        }
        do {
            try restore()
            return nil
        } catch {
            try Task.checkCancellation()
            if error is CancellationError {
                throw error
            }
            return error
        }
    }

    func validateRevision(_ document: MHRemoteUpdateSchedule) throws {
        guard let existing = evidence?.schedule else {
            return
        }
        do {
            try document.validateReplacement(of: existing)
        } catch {
            throw Failure.revisionConflict
        }
    }

    func checkRefresh(_ identifier: UUID) throws {
        try Task.checkCancellation()
        guard refreshIdentifier == identifier else {
            throw Failure.superseded
        }
    }

    func retain(_ value: MHRemoteUpdateSnapshot) throws {
        let accepted = try evidence?.merging(value) ?? value
        do {
            evidence = try store?.retain(accepted) ?? accepted
            hasInitializedEvidence = true
        } catch {
            if error is Failure, let restored = try? store?.load() {
                evidence = try evidence?.merging(restored) ?? restored
            } else {
                evidence = accepted
                hasInitializedEvidence = true
            }
            throw error
        }
    }
}
