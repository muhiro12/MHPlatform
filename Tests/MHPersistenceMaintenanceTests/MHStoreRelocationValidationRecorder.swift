import Foundation

final class MHStoreRelocationValidationRecorder: @unchecked Sendable {
    struct Snapshot {
        let storeURL: URL?
        let copiedFileNames: [String]
    }

    private let lock: NSLock = .init()

    private var storeURL: URL?
    private var copiedFileNames = [String]()

    func record(storeURL: URL, copiedFileNames: [String]) {
        lock.lock()
        defer {
            lock.unlock()
        }

        self.storeURL = storeURL
        self.copiedFileNames = copiedFileNames
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer {
            lock.unlock()
        }

        return .init(
            storeURL: storeURL,
            copiedFileNames: copiedFileNames
        )
    }
}
