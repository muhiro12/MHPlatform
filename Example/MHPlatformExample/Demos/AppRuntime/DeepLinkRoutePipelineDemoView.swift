import MHPlatform
import SwiftUI

struct DeepLinkRoutePipelineDemoView: View {
    @State private var model = DeepLinkRoutePipelineDemoModel()

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                readinessSection(model: model)
                ingestSection(model: model)
                executionSection(model: model)
                logSection(model: model)
            }
            .navigationTitle("DeepLink + RouteLifecycle")
        }
    }

    private func readinessSection(
        model: DeepLinkRoutePipelineDemoModel
    ) -> some View {
        @Bindable var model = model

        return Section("Readiness") {
            Toggle(
                "Ready to execute",
                isOn: $model.isReady
            )
            LabeledContent("Pending inbox URL") {
                Text(model.routeInbox.pendingURL?.absoluteString ?? "None")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("Pending notification URL") {
                Text(model.notificationInbox.pendingURL?.absoluteString ?? "None")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            LabeledContent("Has queued route") {
                Text(model.hasPendingRoute ? "Yes" : "No")
                    .font(.caption.monospaced())
            }
        }
    }

    private func ingestSection(
        model: DeepLinkRoutePipelineDemoModel
    ) -> some View {
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

    private func executionSection(
        model: DeepLinkRoutePipelineDemoModel
    ) -> some View {
        Section("Inboxes -> MHRouteLifecycle") {
            Button("Submit Latest Pending URL") {
                model.drainInbox()
            }
            Button("Apply Pending Route") {
                model.applyPendingIfReady()
            }
        }
    }

    private func logSection(
        model: DeepLinkRoutePipelineDemoModel
    ) -> some View {
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
}
