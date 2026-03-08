import Combine
import Foundation
import MHPlatform

@MainActor
final class DeepLinkRoutePipelineDemoModel: ObservableObject {
    nonisolated enum AppRoute: String, CaseIterable, Identifiable, Sendable, Equatable, MHDeepLinkRoute {
        case home
        case search
        case settings

        var id: String {
            rawValue
        }

        var title: String {
            rawValue.capitalized
        }

        var deepLinkDescriptor: MHDeepLinkDescriptor {
            switch self {
            case .home:
                return .init(pathComponents: ["home"])
            case .search:
                return .init(
                    pathComponents: ["search"],
                    queryItems: [
                        .init(name: "q", value: "tea")
                    ]
                )
            case .settings:
                return .init(pathComponents: ["settings", "notifications"])
            }
        }

        init?(deepLinkDescriptor: MHDeepLinkDescriptor) {
            switch deepLinkDescriptor.pathComponents {
            case ["home"]:
                self = .home
            case ["search"]:
                self = .search
            case let components where components.first == "settings":
                self = .settings
            default:
                return nil
            }
        }
    }

    private enum Constants {
        static let maximumInMemoryEvents = 20
        static let maximumDiskBytes = 1_000
        static let applyDelayMilliseconds = 90
    }

    private static var loggerFactory: MHLoggerFactory {
        .init(
            policy: .init(
                minimumLevel: .debug,
                persistsToDisk: false,
                maximumInMemoryEvents: Constants.maximumInMemoryEvents,
                maximumDiskBytes: Constants.maximumDiskBytes
            ),
            subsystem: "MHPlatformExample"
        )
    }

    @Published private(set) var isReady = false
    @Published private(set) var hasPendingRoute = false
    @Published private(set) var logs = [String]()

    private let codec = MHDeepLinkCodec<AppRoute>(
        configuration: .init(
            customScheme: "mhplatform",
            preferredUniversalLinkHost: "example.com",
            allowedUniversalLinkHosts: [
                "example.com"
            ],
            universalLinkPathPrefix: "MHPlatform",
            preferredTransport: .customScheme
        )
    )
    private let inbox: MHObservableDeepLinkInbox
    private let routeLifecycle: MHRouteLifecycle<AppRoute>
    private var sequence = 0

    init(inbox: MHObservableDeepLinkInbox = .init()) {
        self.inbox = inbox
        routeLifecycle = .init(
            logger: Self.loggerFactory.logger(
                category: "DeepLinkRoutePipelineDemo",
                source: #fileID
            ),
            initialReadiness: false,
            isDuplicate: ==
        )
    }

    func setReadiness(_ isReady: Bool) {
        Task {
            await routeLifecycle.setReadiness(isReady)
            await refreshLifecycleState()
            append("readiness=\(isReady)")
        }
    }

    func ingestDeepLink(_ route: AppRoute) {
        Task {
            guard let url = await inbox.ingest(
                route,
                using: codec
            ) else {
                append("ingest: failed to build URL")
                return
            }

            append("ingest: \(url.absoluteString)")
        }
    }

    func drainInbox() {
        Task {
            let hadPendingURL = inbox.pendingURL != nil
            let codec = self.codec

            do {
                let outcome = try await routeLifecycle.submitLatest(
                    from: inbox,
                    using: codec
                ) { [self] route in
                    try await apply(route)
                }
                await refreshLifecycleState()
                guard let outcome else {
                    let message = hadPendingURL
                        ? "drainInbox: ignored invalid URL"
                        : "drainInbox: no pending URL"
                    append(message)
                    return
                }

                append("drainInbox: \(description(for: outcome))")
            } catch {
                await refreshLifecycleState()
                append("drainInbox: error \(describe(error: error))")
            }
        }
    }

    func applyPendingIfReady() {
        Task {
            do {
                guard let outcome = try await routeLifecycle.applyPendingIfReady(
                    applyOnMainActor: { [self] route in
                        try await apply(route)
                    }
                ) else {
                    await refreshLifecycleState()
                    append("applyPendingIfReady: no pending route")
                    return
                }

                await refreshLifecycleState()
                append("applyPendingIfReady: \(description(for: outcome))")
            } catch {
                await refreshLifecycleState()
                append("applyPendingIfReady: error \(describe(error: error))")
            }
        }
    }

    private func apply(_ route: AppRoute) async throws {
        try await Task.sleep(
            for: .milliseconds(Constants.applyDelayMilliseconds)
        )

        append("apply: \(destination(for: route))")
    }

    private func refreshLifecycleState() async {
        isReady = await routeLifecycle.isReady
        hasPendingRoute = await routeLifecycle.hasPendingRoute
    }

    private func description(
        for outcome: MHRouteExecutionOutcome<AppRoute>
    ) -> String {
        switch outcome {
        case .queued:
            return "queued"
        case .applied(let route):
            return "applied(\(destination(for: route)))"
        case .deduplicated:
            return "deduplicated"
        }
    }

    private func destination(
        for route: AppRoute
    ) -> String {
        switch route {
        case .home:
            return "home"
        case .search:
            return "search?q=tea"
        case .settings:
            return "settings/notifications"
        }
    }

    private func describe(error: any Error) -> String {
        if let localizedError = error as? LocalizedError,
           let errorDescription = localizedError.errorDescription {
            return errorDescription
        }

        return String(describing: error)
    }

    private func append(_ message: String) {
        sequence += 1
        logs.insert("\(sequence). \(message)", at: 0)
    }
}
