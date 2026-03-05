import Combine
import MHDeepLinking
import MHRouteExecution
import SwiftUI

@MainActor
private final class DeepLinkRoutePipelineDemoModel: ObservableObject {
    enum AppRoute: String, CaseIterable, Identifiable, Sendable, Equatable, MHDeepLinkRoute {
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

    @Published private(set) var isReady = false
    @Published private(set) var hasPendingRoute = false
    @Published private(set) var logs = [String]()

    private let codec = MHDeepLinkCodec<AppRoute>(
        configuration: .init(
            customScheme: "mhkit",
            preferredUniversalLinkHost: "example.com",
            allowedUniversalLinkHosts: [
                "example.com"
            ],
            universalLinkPathPrefix: "MHKit",
            preferredTransport: .customScheme
        )
    )
    private let inbox = MHDeepLinkInbox()
    private let coordinator: MHRouteCoordinator<AppRoute, String>
    private var sequence = 0

    init() {
        let executor = MHRouteExecutor<AppRoute, String>(
            resolve: { route in
                "resolved:\(route.rawValue)"
            },
            apply: { _ in
                // Intentionally empty.
            }
        )
        coordinator = .init(
            initialReadiness: false,
            executor: executor
        )            { lhs, rhs in
                lhs == rhs
            }
    }

    func setReadiness(_ isReady: Bool) {
        self.isReady = isReady

        Task {
            await coordinator.setReadiness(isReady)
            append("readiness=\(isReady)")
            await refreshPendingStatus()
        }
    }

    func ingestDeepLink(_ route: AppRoute) {
        guard let url = codec.preferredURL(for: route) else {
            append("ingest: failed to build URL")
            return
        }

        Task {
            await inbox.ingest(url)
            append("ingest: \(url.absoluteString)")
        }
    }

    func processInbox() {
        Task {
            guard let url = await inbox.consumeLatest() else {
                append("processInbox: no URL")
                return
            }

            guard let route = codec.parse(url) else {
                append("processInbox: rejected URL")
                return
            }

            do {
                let outcome = try await coordinator.submit(route)
                append("processInbox: \(description(for: outcome))")
            } catch {
                append("processInbox: error \(error)")
            }

            await refreshPendingStatus()
        }
    }

    func applyPendingIfReady() {
        Task {
            do {
                let outcome = try await coordinator.applyPendingIfReady()
                if let outcome {
                    append("applyPendingIfReady: \(description(for: outcome))")
                } else {
                    append("applyPendingIfReady: no pending route")
                }
            } catch {
                append("applyPendingIfReady: error \(error)")
            }

            await refreshPendingStatus()
        }
    }

    private func refreshPendingStatus() async {
        hasPendingRoute = await coordinator.hasPendingRoute
    }

    private func description(for outcome: MHRouteExecutionOutcome<String>) -> String {
        switch outcome {
        case .queued:
            return "queued"
        case .applied(let value):
            return "applied(\(value))"
        case .deduplicated:
            return "deduplicated"
        }
    }

    private func append(_ message: String) {
        sequence += 1
        logs.insert("\(sequence). \(message)", at: 0)
    }
}

struct DeepLinkRoutePipelineDemoView: View {
    @StateObject private var model = DeepLinkRoutePipelineDemoModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Readiness") {
                    Toggle(
                        "Ready to execute",
                        isOn: .init(
                            get: {
                                model.isReady
                            },
                            set: { isReady in
                                model.setReadiness(isReady)
                            }
                        )
                    )
                    LabeledContent("Has pending route") {
                        Text(model.hasPendingRoute ? "Yes" : "No")
                            .font(.caption.monospaced())
                    }
                }

                Section("DeepLink -> Inbox") {
                    ForEach(DeepLinkRoutePipelineDemoModel.AppRoute.allCases) { route in
                        Button("Ingest \(route.title)") {
                            model.ingestDeepLink(route)
                        }
                    }
                }

                Section("Inbox -> RouteExecutor") {
                    Button("Process Inbox") {
                        model.processInbox()
                    }
                    Button("Apply Pending") {
                        model.applyPendingIfReady()
                    }
                }

                Section("Log") {
                    if model.logs.isEmpty {
                        Text("No events yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.logs, id: \.self) { log in
                            Text(log)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("DeepLink + Route")
        }
    }
}
