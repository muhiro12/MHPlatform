import MHPlatform
import SwiftUI

struct DeepLinkRoutePipelineDemoView: View {
    @State private var routeInbox: MHObservableDeepLinkInbox
    @State private var notificationInbox: MHObservableDeepLinkInbox
    @StateObject private var model: DeepLinkRoutePipelineDemoModel

    var body: some View {
        NavigationStack {
            List {
                readinessSection
                ingestSection
                executionSection
                logSection
            }
            .navigationTitle("DeepLink + RouteLifecycle")
        }
    }

    private var readinessSection: some View {
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
            LabeledContent("Pending inbox URL") {
                Text(routeInbox.pendingURL?.absoluteString ?? "None")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("Pending notification URL") {
                Text(notificationInbox.pendingURL?.absoluteString ?? "None")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("Has queued route") {
                Text(model.hasPendingRoute ? "Yes" : "No")
                    .font(.caption.monospaced())
            }
        }
    }

    private var ingestSection: some View {
        Section("DeepLink Sources") {
            ForEach(DeepLinkRoutePipelineDemoModel.AppRoute.allCases) { route in
                Button("Ingest \(route.title)") {
                    model.ingestDeepLink(route)
                }
                Button("Notification Handoff \(route.title)") {
                    model.ingestNotificationRoute(route)
                }
            }
        }
    }

    private var executionSection: some View {
        Section("Inboxes -> MHRouteLifecycle") {
            Button("Submit Latest Pending URL") {
                model.drainInbox()
            }
            Button("Apply Pending Route") {
                model.applyPendingIfReady()
            }
        }
    }

    private var logSection: some View {
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

    init() {
        let routeInbox = MHObservableDeepLinkInbox()
        let notificationInbox = MHObservableDeepLinkInbox()
        _routeInbox = .init(initialValue: routeInbox)
        _notificationInbox = .init(initialValue: notificationInbox)
        _model = .init(
            wrappedValue: DeepLinkRoutePipelineDemoModel(
                routeInbox: routeInbox,
                notificationInbox: notificationInbox
            )
        )
    }
}
