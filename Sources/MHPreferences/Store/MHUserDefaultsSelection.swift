import Foundation

/// Declares which `UserDefaults` domain should back app-owned preferences.
public enum MHUserDefaultsSelection: Hashable, Sendable {
    /// Uses the process-wide standard defaults domain.
    case standard

    /// Uses an explicitly named suite-backed defaults domain.
    case suite(String)

    /// Resolves the selected `UserDefaults` instance when the selection is valid.
    public func makeUserDefaults() -> UserDefaults? {
        switch self {
        case .standard:
            return .standard
        case let .suite(rawSuiteName):
            guard let suiteName = optionalNormalizedSuiteName(rawSuiteName) else {
                return nil
            }

            return UserDefaults(suiteName: suiteName)
        }
    }

    /// Resolves the selected `UserDefaults` instance.
    public func resolveUserDefaults() -> UserDefaults {
        guard let userDefaults = makeUserDefaults() else {
            preconditionFailure("Invalid UserDefaults selection: \(self)")
        }

        return userDefaults
    }
}

extension MHUserDefaultsSelection {
    var normalizedStepIDComponent: String {
        switch self {
        case .standard:
            "standard"
        case let .suite(rawSuiteName):
            "suite.\(requiredNormalizedSuiteName(rawSuiteName))"
        }
    }

    func persistentDomainName(
        standardDomainName: String?
    ) -> String {
        switch self {
        case .standard:
            requiredNormalizedDomainName(standardDomainName ?? .init())
        case let .suite(rawSuiteName):
            requiredNormalizedSuiteName(rawSuiteName)
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
    func optionalNormalizedSuiteName(
        _ rawSuiteName: String
    ) -> String? {
        optionalNormalizedDomainName(rawSuiteName)
    }

    func requiredNormalizedSuiteName(
        _ rawSuiteName: String
    ) -> String {
        requiredNormalizedDomainName(rawSuiteName)
    }

    func optionalNormalizedDomainName(
        _ rawDomainName: String
    ) -> String? {
        let normalizedDomainName = rawDomainName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard normalizedDomainName.isEmpty == false else {
            return nil
        }

        return normalizedDomainName
    }

    func requiredNormalizedDomainName(
        _ rawDomainName: String
    ) -> String {
        guard let normalizedDomainName = optionalNormalizedDomainName(rawDomainName) else {
            preconditionFailure("UserDefaults domain name must not be empty")
        }

        return normalizedDomainName
    }
}
