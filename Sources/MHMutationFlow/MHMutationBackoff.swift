import Foundation

/// Retry backoff strategy used by mutation execution.
public enum MHMutationBackoff: Sendable {
    /// Immediately retries without delay.
    case immediate

    /// Uses a fixed delay before retrying.
    case fixed(Duration)

    /// Uses exponential delay with optional maximum cap.
    case exponential(
            base: Duration,
            factor: Double = 2,
            maximumDelay: Duration? = nil
         )
}

extension MHMutationBackoff {
    func delay(forRetry retryIndex: Int) -> Duration {
        switch self {
        case .immediate:
            return .zero
        case .fixed(let delay):
            return delay
        case .exponential(let base, let factor, let maximumDelay):
            let normalizedRetryIndex = max(retryIndex, 1)
            let baseSeconds = base.secondsValue
            let multiplier = pow(
                factor,
                Double(normalizedRetryIndex - 1)
            )
            let rawDelay = Duration.seconds(baseSeconds * multiplier)

            guard let maximumDelay else {
                return rawDelay
            }

            return min(rawDelay, maximumDelay)
        }
    }
}

private extension Duration {
    var secondsValue: Double {
        let components = self.components
        let attosecondsPerSecond = 1_000_000_000_000_000_000.0
        return Double(components.seconds)
            + Double(components.attoseconds) / attosecondsPerSecond
    }
}
