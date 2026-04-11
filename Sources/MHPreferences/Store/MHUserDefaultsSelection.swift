import Foundation

/// Declares which `UserDefaults` domain should back app-owned preferences.
public enum MHUserDefaultsSelection: Hashable, Sendable {
    /// Uses the process-wide standard defaults domain.
    case standard

    /// Uses an explicitly named suite-backed defaults domain.
    case suite(String)

    /// Resolves the configured `UserDefaults` instance.
    public func resolveUserDefaults() -> UserDefaults {
        switch self {
        case .standard:
            return .standard
        case let .suite(rawSuiteName):
            let normalizedSuiteName = rawSuiteName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            precondition(normalizedSuiteName.isEmpty == false)

            guard let userDefaults = UserDefaults(
                suiteName: normalizedSuiteName
            ) else {
                preconditionFailure()
            }

            return userDefaults
        }
    }
}
