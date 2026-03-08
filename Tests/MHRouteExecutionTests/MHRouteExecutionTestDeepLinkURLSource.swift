import Foundation
@testable import MHDeepLinking

actor MHRouteExecutionTestDeepLinkURLSource: MHDeepLinkURLSource {
    private var url: URL?
    private(set) var consumeCount = 0

    init(url: URL?) {
        self.url = url
    }

    func consumeLatestURL() -> URL? {
        consumeCount += 1
        defer {
            url = nil
        }
        return url
    }
}
