import Foundation

/// Input candidate used when building daily suggestion plans.
public struct MHSuggestionCandidate: Sendable {
    /// Display title for this suggestion.
    public let title: String

    /// Stable identifier for deterministic selection.
    public let stableIdentifier: String

    /// Route URL used to open the suggested content.
    public let routeURL: URL

    /// Creates a suggestion candidate.
    public init(
        title: String,
        stableIdentifier: String,
        routeURL: URL
    ) {
        self.title = title
        self.stableIdentifier = stableIdentifier
        self.routeURL = routeURL
    }
}
