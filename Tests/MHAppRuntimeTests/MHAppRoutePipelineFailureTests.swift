import Foundation
import MHAppRuntime
import MHLogging
import MHRouteExecution
import Testing

struct MHAppRoutePipelineFailureTests {
    @MainActor
    @Test
    func activateIfNeeded_logs_default_failure_handler_error() async throws {
        let failureLogStore = makeLogStore()
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: false,
            isDuplicate: ==
        )
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            applyOnMainActor: { _ in
                throw TestError.expectedFailure
            },
            failureLogger: makeLogger(store: failureLogStore)
        )

        let queuedOutcome = try await routeLifecycle.submit(7) { _ in
            Issue.record("Queued route should not execute before activation.")
        }

        switch queuedOutcome {
        case .queued:
            break
        case .applied(let route):
            Issue.record("Expected queued outcome, got applied(\(route)).")
        case .deduplicated:
            Issue.record("Expected queued outcome, got deduplicated.")
        }

        let activationOutcome = await pipeline.activateIfNeeded()

        #expect(activationOutcome == nil)
        let failureEvent = try #require(
            await findEvent(
                in: failureLogStore,
                level: .error,
                message: "route pipeline failure"
            )
        )
        #expect(
            failureEvent.metadata["error"] == String(describing: TestError.expectedFailure)
        )
        #expect(failureEvent.metadata["operation"] == "activateIfNeeded")
    }

    @MainActor
    @Test
    func drainPendingRoutesIfNeeded_logs_failure_and_runs_custom_failure_handler() async throws {
        let failureLogStore = makeLogStore()
        let routeURL = try #require(URL(string: "test://route/9"))
        let routeLifecycle = MHRouteLifecycle<Int>(
            logger: makeLogger(),
            initialReadiness: true,
            isDuplicate: ==
        )
        let failureDescriptionBox = FailureDescriptionBox()
        let onFailure: MHAppRoutePipeline<Int>.FailureHandler = { error in
            failureDescriptionBox.value = String(describing: error)
        }
        let pipeline = MHAppRoutePipeline(
            routeLifecycle: routeLifecycle,
            parse: Self.parseRoute(from:),
            applyOnMainActor: { _ in
                throw TestError.expectedFailure
            },
            failureLogger: makeLogger(store: failureLogStore),
            onFailure: onFailure
        )

        await pipeline.ingest(routeURL)
        let drainOutcome = await pipeline.drainPendingRoutesIfNeeded()

        #expect(drainOutcome == nil)
        #expect(
            failureDescriptionBox.value == String(describing: TestError.expectedFailure)
        )
        let failureEvent = try #require(
            await findEvent(
                in: failureLogStore,
                level: .error,
                message: "route pipeline failure"
            )
        )
        #expect(
            failureEvent.metadata["error"] == String(describing: TestError.expectedFailure)
        )
        #expect(failureEvent.metadata["operation"] == "drainPendingRoutesIfNeeded")
    }
}

private extension MHAppRoutePipelineFailureTests {
    final class FailureDescriptionBox: @unchecked Sendable {
        var value: String?
    }

    enum TestConstants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
    }

    enum TestError: Error {
        case expectedFailure
    }

    static func parseRoute(from url: URL) -> Int? {
        Int(url.lastPathComponent)
    }

    func makeLogStore() -> MHLogStore {
        .init(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: TestConstants.maximumInMemoryEvents,
                maximumDiskBytes: TestConstants.maximumDiskBytes
            )
        )
    }

    func makeLogger(store: MHLogStore? = nil) -> MHLogger {
        let resolvedStore = store ?? makeLogStore()
        return .init(
            #fileID,
            store: resolvedStore,
            subsystem: "tests.runtime"
        )
    }

    func findEvent(
        in store: MHLogStore,
        level: MHLogLevel,
        message: String
    ) async -> MHLogEvent? {
        let maximumAttempts = 20

        for _ in 0..<maximumAttempts {
            let values = await store.events()
            if let event = values.first(where: { event in
                event.level == level && event.message == message
            }) {
                return event
            }

            await Task.yield()
        }

        return nil
    }
}
