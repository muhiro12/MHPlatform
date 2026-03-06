import Foundation

/// Source location metadata captured at the logging call site.
public struct MHLogSource: Codable, Equatable, Sendable {
    public let file: String
    public let function: String
    public let line: Int

    public init(
        file: String,
        function: String,
        line: Int
    ) {
        self.file = file
        self.function = function
        self.line = line
    }
}
