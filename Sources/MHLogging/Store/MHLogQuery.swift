import Foundation

/// In-memory query used by `MHLogStore` to filter events for analysis.
public struct MHLogQuery: Equatable, Sendable {
    public let minimumLevel: MHLogLevel?
    public let category: String?
    public let searchText: String?
    public let limit: Int?

    public init(
        minimumLevel: MHLogLevel? = nil,
        category: String? = nil,
        searchText: String? = nil,
        limit: Int? = nil
    ) {
        self.minimumLevel = minimumLevel
        self.category = Self.trimmedOrNil(category)
        self.searchText = Self.trimmedOrNil(searchText)
        self.limit = limit
    }
}

private extension MHLogQuery {
    static func trimmedOrNil(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard trimmedValue.isEmpty == false else {
            return nil
        }
        return trimmedValue
    }
}
