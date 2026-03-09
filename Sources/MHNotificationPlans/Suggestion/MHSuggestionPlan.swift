import Foundation

/// Deterministic daily suggestion plan output.
public struct MHSuggestionPlan: Sendable {
    /// Unique plan identifier.
    public let identifier: String

    /// Suggestion display title.
    public let title: String

    /// Stable identifier of the chosen candidate.
    public let stableIdentifier: String

    /// Date and time when this suggestion should be shown.
    public let notifyDate: Date

    /// Route URL used to open the suggested content.
    public let routeURL: URL

    /// Creates a suggestion plan.
    public init(
        identifier: String,
        title: String,
        stableIdentifier: String,
        notifyDate: Date,
        routeURL: URL
    ) {
        self.identifier = identifier
        self.title = title
        self.stableIdentifier = stableIdentifier
        self.notifyDate = notifyDate
        self.routeURL = routeURL
    }
}
