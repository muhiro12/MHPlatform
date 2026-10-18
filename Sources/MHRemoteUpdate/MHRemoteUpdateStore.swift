import Foundation

/// A small, atomically replaced evidence file at an app-selected location.
///
/// Use a separate URL for each app, environment, and storefront. One controller
/// owns each file; coordinating writers in multiple processes is app-owned.
public struct MHRemoteUpdateStore: Sendable {
    private let fileURL: URL

    /// Uses an existing parent directory chosen by the app, usually Application Support.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Returns nil only when the file is absent; corruption and I/O errors remain observable.
    public func load() throws -> MHRemoteUpdateSnapshot? {
        do {
            return try JSONDecoder().decode(MHRemoteUpdateSnapshot.self, from: Data(contentsOf: fileURL))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
    }

    /// Writes before replacing the old file; never removes evidence on fetch failure.
    public func save(_ snapshot: MHRemoteUpdateSnapshot) throws {
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
