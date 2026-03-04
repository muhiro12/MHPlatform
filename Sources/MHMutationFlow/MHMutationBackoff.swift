import Foundation

/// Retry backoff strategy used by mutation execution.
public enum MHMutationBackoff: Sendable {
    /// Immediately retries without delay.
    case immediate

    /// Uses a fixed delay before retrying.
    case fixed(Duration)
}
