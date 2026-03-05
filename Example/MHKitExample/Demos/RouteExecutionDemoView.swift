import SwiftUI

struct RouteExecutionDemoView: View {
    @StateObject private var model = RouteExecutionDemoModel()

    private var readinessBinding: Binding<Bool> {
        .init(
            get: {
                model.isReady
            },
            set: { isReady in
                model.setReadiness(isReady)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                readinessSection
                sendRouteSection
                pendingRouteSection
                eventLogSection
            }
            .navigationTitle("MHRouteExecution")
        }
        .task {
            await model.refreshPendingRouteStatus()
        }
    }

    private var readinessSection: some View {
        Section("Readiness") {
            Toggle(
                "Ready to execute routes",
                isOn: readinessBinding
            )
        }
    }

    private var sendRouteSection: some View {
        Section("Send Route") {
            ForEach(RouteExecutionDemoRoute.allCases) { route in
                Button(route.buttonTitle) {
                    model.submit(route)
                }
            }
        }
    }

    private var pendingRouteSection: some View {
        Section("Pending Route") {
            LabeledContent("Has pending route") {
                Text(model.hasPendingRoute ? "Yes" : "No")
                    .font(.caption.monospaced())
            }

            Button("Apply Pending Route") {
                model.applyPendingIfReady()
            }

            Button("Clear Pending Route") {
                model.clearPendingRoute()
            }
            .disabled(model.hasPendingRoute == false)
        }
    }

    private var eventLogSection: some View {
        Section("Execution Log") {
            if model.logs.isEmpty {
                Text("No events yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    model.logs.indices,
                    id: \.self
                ) { index in
                    Text(model.logs[index])
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }
}
