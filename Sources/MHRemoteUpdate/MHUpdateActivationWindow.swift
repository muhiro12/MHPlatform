import Foundation

/// An inclusive activation interval bounded by an app-supplied maximum duration.
public struct MHUpdateActivationWindow: Hashable, Sendable {
    /// The first instant at which the policy is active.
    public let activatedAt: Date
    /// The last instant at which the policy is active.
    public let expiresAt: Date

    /// Rejects nonfinite dates, nonpositive durations, and windows exceeding the maximum.
    public init?(activatedAt: Date, expiresAt: Date, maximumDuration: TimeInterval) {
        let duration = expiresAt.timeIntervalSince(activatedAt)
        guard activatedAt.timeIntervalSinceReferenceDate.isFinite,
              expiresAt.timeIntervalSinceReferenceDate.isFinite,
              maximumDuration.isFinite,
              maximumDuration > 0,
              duration.isFinite,
              duration > 0,
              duration <= maximumDuration else {
            return nil
        }
        self.activatedAt = activatedAt
        self.expiresAt = expiresAt
    }

    /// Returns whether a finite instant falls within the inclusive interval.
    public func contains(_ date: Date) -> Bool {
        date >= activatedAt && date <= expiresAt
    }
}
