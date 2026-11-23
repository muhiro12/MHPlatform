/// A visible announcement with its publisher's stable ID and selected plain text.
public struct MHAnnouncement: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
}
