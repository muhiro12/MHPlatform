import Foundation

/// Declares which `UserDefaults` domain should back app-owned preferences.
public enum MHUserDefaultsSelection: Hashable, Sendable {
    /// Uses the process-wide standard defaults domain.
    case standard

    /// Uses an explicitly named suite-backed defaults domain.
    case suite(String)

    /// Resolves the selected `UserDefaults` instance.
    public func resolveUserDefaults() -> UserDefaults {
        switch self {
        case .standard:
            return .standard
        case let .suite(rawSuiteName):
            guard let userDefaults = UserDefaults(
                suiteName: normalizedSuiteName(rawSuiteName)
            ) else {
                preconditionFailure()
            }

            return userDefaults
        }
    }
}

extension MHUserDefaultsSelection {
    var normalizedStepIDComponent: String {
        switch self {
        case .standard:
            "standard"
        case let .suite(rawSuiteName):
            "suite.\(normalizedSuiteName(rawSuiteName))"
        }
    }

    func persistentDomainName(
        standardDomainName: String?
    ) -> String {
        switch self {
        case .standard:
            normalizedDomainName(
                standardDomainName ?? .init()
            )
        case let .suite(rawSuiteName):
            normalizedSuiteName(rawSuiteName)
        }
    }

    func normalizedComparisonKey(
        standardDomainName: String?
    ) -> String {
        switch self {
        case .standard:
            "standard:\(persistentDomainName(standardDomainName: standardDomainName))"
        case .suite:
            "suite:\(persistentDomainName(standardDomainName: standardDomainName))"
        }
    }
}

private extension MHUserDefaultsSelection {
    func normalizedSuiteName(
        _ rawSuiteName: String
    ) -> String {
        normalizedDomainName(rawSuiteName)
    }

    func normalizedDomainName(
        _ rawDomainName: String
    ) -> String {
        let normalizedDomainName = rawDomainName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        precondition(normalizedDomainName.isEmpty == false)
        return normalizedDomainName
    }
}
