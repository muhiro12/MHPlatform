/// Cleanup result for one caller-owned `UserDefaults` domain.
public struct MHPreferenceDomainCleanupReport: Equatable, Sendable {
    /// The logical defaults selection that was cleaned.
    public let selection: MHUserDefaultsSelection

    /// The persistent-domain name passed to `UserDefaults`.
    public let domainName: String

    /// The cleanup result for the domain.
    public let report: MHUserDefaultsCleanupReport

    /// Creates a per-domain cleanup report.
    public init(
        selection: MHUserDefaultsSelection,
        domainName: String,
        report: MHUserDefaultsCleanupReport
    ) {
        self.selection = selection
        self.domainName = domainName
        self.report = report
    }
}
