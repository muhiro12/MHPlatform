import SwiftUI

struct DeepLinkRoutePipelineDemoView: View {
    @StateObject private var model = DeepLinkRoutePipelineDemoModel()

    var body: some View {
        NavigationStack {
            List {
                readinessSection
                ingestSection
                executionSection
                logSection
            }
            .navigationTitle("DeepLink + Route")
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
            LabeledContent("Has pending route") {
                Text(model.hasPendingRoute ? "Yes" : "No")
                    .font(.caption.monospaced())
            }
        }
    }

    private var ingestSection: some View {
        Section("DeepLink -> Inbox") {
            ForEach(DeepLinkRoutePipelineDemoModel.AppRoute.allCases) { route in
                Button("Ingest \(route.title)") {
                    model.ingestDeepLink(route)
                }
            }
        }
    }

    private var executionSection: some View {
        Section("Inbox -> RouteExecutor") {
            Button("Process Inbox") {
                model.processInbox()
            }
            Button("Apply Pending") {
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
}
